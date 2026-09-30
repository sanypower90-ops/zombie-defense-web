extends Node

signal auth_done(ok: bool, message: String)
signal stash_loaded(ok: bool, stash: Dictionary, message: String)
signal stash_saved(ok: bool, message: String)

const Config = preload("res://config/leaderboard_config.gd")
const SESSION_PATH := "user://account_session.json"

var session: Dictionary = {}
var just_registered := false
var _request: HTTPRequest
var _operation := ""
var _auth_action := ""
var _queued_stash: Dictionary = {}
var _has_queued_stash := false

func _ready() -> void:
	_request = HTTPRequest.new()
	if OS.has_feature("web"):
		_request.accept_gzip = false
	add_child(_request)
	_request.request_completed.connect(_on_completed)
	_load_session()
	if not session.is_empty():
		_refresh_session()

func logged_in() -> bool:
	return not session.is_empty() and not str(session.get("access_token", "")).is_empty()

func username() -> String:
	return str(session.get("username", ""))

func user_id() -> String:
	return str(session.get("user_id", ""))

func busy() -> bool:
	return not _operation.is_empty()

func register_account(name: String, password: String) -> void:
	_auth("register", name, password)

func login_account(name: String, password: String) -> void:
	_auth("login", name, password)

func _auth(action: String, name: String, password: String) -> void:
	if busy():
		auth_done.emit(false, "계정 작업이 끝난 뒤 다시 시도해 주세요.")
		return
	var payload = {"action": action, "username": name, "password": password}
	var headers = PackedStringArray(["apikey: %s" % Config.SUPABASE_ANON_KEY, "Content-Type: application/json"])
	var err = _request.request("%s/functions/v1/username-auth" % Config.SUPABASE_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err == OK:
		_operation = "auth"
		_auth_action = action
	else:
		auth_done.emit(false, "계정 서버 연결에 실패했습니다.")

func logout() -> void:
	session.clear()
	just_registered = false
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	_queued_stash.clear()
	_has_queued_stash = false

func load_stash() -> void:
	if not logged_in():
		stash_loaded.emit(false, {}, "로그인이 필요합니다.")
		return
	if busy():
		return
	if _session_expiring():
		_refresh_session()
		return
	var headers = _data_headers()
	var url = "%s/rest/v1/player_saves?select=checkpoint&user_id=eq.%s" % [Config.SUPABASE_URL, str(session.get("user_id", ""))]
	var err = _request.request(url, headers, HTTPClient.METHOD_GET)
	if err == OK:
		_operation = "load"
	else:
		stash_loaded.emit(false, {}, "보관 아이템을 불러오지 못했습니다.")

func save_stash(stash: Dictionary) -> void:
	if not logged_in():
		return
	_queued_stash = stash.duplicate(true)
	_has_queued_stash = true
	_flush_stash()

func _flush_stash() -> void:
	if not _has_queued_stash or busy() or not logged_in():
		return
	if _session_expiring():
		_refresh_session()
		return
	var payload = {"user_id": session.get("user_id", ""), "checkpoint": _queued_stash}
	var headers = _data_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	var err = _request.request("%s/rest/v1/player_saves?on_conflict=user_id" % Config.SUPABASE_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err == OK:
		_operation = "save"
		_has_queued_stash = false
	else:
		stash_saved.emit(false, "온라인 저장 요청에 실패했습니다.")

func _data_headers() -> PackedStringArray:
	return PackedStringArray(["apikey: %s" % Config.SUPABASE_ANON_KEY, "Authorization: Bearer %s" % str(session.get("access_token", ""))])

func _session_expiring() -> bool:
	return Time.get_unix_time_from_system() + 60.0 >= float(session.get("expires_at", 0.0))

func _refresh_session() -> void:
	if busy():
		return
	var refresh = str(session.get("refresh_token", ""))
	if refresh.is_empty():
		logout()
		return
	var headers = PackedStringArray(["apikey: %s" % Config.SUPABASE_ANON_KEY, "Content-Type: application/json"])
	var err = _request.request("%s/auth/v1/token?grant_type=refresh_token" % Config.SUPABASE_URL, headers, HTTPClient.METHOD_POST, JSON.stringify({"refresh_token": refresh}))
	if err == OK:
		_operation = "refresh"
	else:
		auth_done.emit(false, "로그인 상태를 확인하지 못했습니다.")

func _on_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var op = _operation
	_operation = ""
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		var error_message = "서버 연결 오류 (%d)" % status
		if typeof(parsed) == TYPE_DICTIONARY:
			error_message = str(parsed.get("error", error_message))
		if op == "refresh":
			if status == 400 or status == 401:
				logout()
			auth_done.emit(false, "로그인 상태를 확인하지 못했습니다. 다시 로그인해 주세요.")
		elif op == "auth":
			auth_done.emit(false, error_message)
		elif op == "load":
			stash_loaded.emit(false, {}, error_message)
		elif op == "save":
			_has_queued_stash = true
			stash_saved.emit(false, error_message)
		return
	if op == "auth" or op == "refresh":
		if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("access_token", "")).is_empty() or str(parsed.get("refresh_token", "")).is_empty():
			auth_done.emit(false, "로그인 응답을 확인할 수 없습니다.")
			return
		if op == "auth" and str(parsed.get("user_id", "")).is_empty():
			auth_done.emit(false, "계정 번호를 확인할 수 없습니다.")
			return
		if op == "auth":
			session = parsed
			just_registered = _auth_action == "register"
		else:
			session["access_token"] = parsed.get("access_token", "")
			session["refresh_token"] = parsed.get("refresh_token", "")
		session["expires_at"] = Time.get_unix_time_from_system() + float(parsed.get("expires_in", 3600))
		_store_session()
		if op == "auth":
			auth_done.emit(true, "로그인되었습니다. 보관 아이템을 불러오는 중입니다.")
		load_stash()
		return
	if op == "load":
		if typeof(parsed) != TYPE_ARRAY:
			stash_loaded.emit(false, {}, "보관 아이템 응답을 확인할 수 없습니다.")
			return
		var stash: Dictionary = {}
		if not parsed.is_empty() and typeof(parsed[0]) == TYPE_DICTIONARY:
			stash = parsed[0].get("checkpoint", {})
		stash_loaded.emit(true, stash, "보관 아이템을 불러왔습니다.")
	elif op == "save":
		stash_saved.emit(true, "보관 아이템이 서버에 저장되었습니다.")
	_flush_stash()

func _store_session() -> void:
	var file = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session))
		file.close()

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file = FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(value) == TYPE_DICTIONARY and not str(value.get("refresh_token", "")).is_empty():
		session = value
