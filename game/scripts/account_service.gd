extends Node

const Config = preload("res://config/leaderboard_config.gd")
signal status_changed(message: String)
signal signed_in(email: String)
signal save_loaded(checkpoint: Dictionary)

var access_token := ""
var user_id := ""
var user_email := ""
var refresh_token := ""
var expires_at_msec := 0
var _upload_busy := false
var _latest_save: Dictionary = {}

func configured() -> bool:
	return not Config.SUPABASE_URL.is_empty() and not Config.SUPABASE_ANON_KEY.is_empty()

func sign_up(email: String, password: String) -> void:
	if not _valid_credentials(email, password): return
	_send(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": email, "password": password}, false, _on_signup)

func sign_in(email: String, password: String) -> void:
	if not _valid_credentials(email, password): return
	_send(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email, "password": password}, false, _on_signin)

func sign_out() -> void:
	access_token = ""
	user_id = ""
	user_email = ""
	refresh_token = ""
	expires_at_msec = 0
	status_changed.emit("로그아웃되었습니다.")

func load_save() -> void:
	if access_token.is_empty(): return
	_send(HTTPClient.METHOD_GET, "/rest/v1/player_saves?user_id=eq.%s&select=checkpoint" % user_id, {}, true, _on_load)

func upload_save(checkpoint: Dictionary) -> void:
	if access_token.is_empty(): return
	_latest_save = checkpoint.duplicate(true)
	_drain_upload()

func _drain_upload() -> void:
	if _upload_busy or _latest_save.is_empty() or access_token.is_empty(): return
	_upload_busy = true
	if Time.get_ticks_msec() >= expires_at_msec - 30000 and not refresh_token.is_empty():
		_send(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false, _on_refresh)
		return
	var checkpoint = _latest_save
	_latest_save = {}
	_send(HTTPClient.METHOD_POST, "/rest/v1/player_saves?on_conflict=user_id", {"user_id":user_id, "checkpoint":checkpoint}, true, _on_upload, true)

func _on_refresh(result: int, code: int, data: Variant) -> void:
	_upload_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not (data is Dictionary):
		status_changed.emit("로그인이 만료되었습니다. 다시 로그인해주세요.")
		return
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", refresh_token))
	expires_at_msec = Time.get_ticks_msec() + int(data.get("expires_in", 3600)) * 1000
	_drain_upload()

func _valid_credentials(email: String, password: String) -> bool:
	if not configured():
		status_changed.emit("온라인 서버 미연결: README의 Supabase 연결 순서를 따라 설정해주세요.")
		return false
	if email.strip_edges().find("@") <= 0 or password.length() < 6:
		status_changed.emit("이메일 주소와 6자 이상 비밀번호를 입력해주세요.")
		return false
	return true

func _send(method: HTTPClient.Method, path: String, body: Dictionary, authenticated: bool, callback: Callable, upsert := false) -> void:
	if not configured():
		status_changed.emit("온라인 서버가 연결되지 않았습니다.")
		return
	var request = HTTPRequest.new()
	add_child(request)
	var headers = PackedStringArray(["apikey: " + Config.SUPABASE_ANON_KEY, "Content-Type: application/json"])
	if authenticated:
		headers.append("Authorization: Bearer " + access_token)
	if upsert:
		headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	var error = request.request(Config.SUPABASE_URL.trim_suffix("/") + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		request.queue_free()
		status_changed.emit("서버 요청을 시작하지 못했습니다: %d" % error)
		return
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		callback.call(result, code, data)
		request.queue_free()
	)

func _message(data: Variant) -> String:
	if data is Dictionary:
		return str(data.get("msg", data.get("message", data.get("error_description", "서버 응답 오류"))))
	return "서버 응답 오류"

func _on_signup(result: int, code: int, data: Variant) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		status_changed.emit("가입 실패: " + _message(data))
		return
	status_changed.emit("가입 요청 완료. 이메일 확인이 필요하면 받은편지함을 확인하고 로그인해주세요.")

func _on_signin(result: int, code: int, data: Variant) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not (data is Dictionary):
		status_changed.emit("로그인 실패: " + _message(data))
		return
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	expires_at_msec = Time.get_ticks_msec() + int(data.get("expires_in", 3600)) * 1000
	var account = data.get("user", {})
	user_id = str(account.get("id", "")) if account is Dictionary else ""
	user_email = str(account.get("email", "")) if account is Dictionary else ""
	if access_token.is_empty() or user_id.is_empty():
		status_changed.emit("로그인 응답에 계정 정보가 없습니다.")
		return
	status_changed.emit("로그인됨: " + user_email)
	signed_in.emit(user_email)
	load_save()

func _on_load(result: int, code: int, data: Variant) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not (data is Array):
		status_changed.emit("클라우드 저장 불러오기 실패: " + _message(data))
		return
	if data.is_empty():
		status_changed.emit("로그인 완료. 아직 클라우드 저장이 없습니다.")
		return
	var checkpoint = data[0].get("checkpoint", {})
	if checkpoint is Dictionary and not checkpoint.is_empty():
		save_loaded.emit(checkpoint)
		status_changed.emit("클라우드 저장을 불러왔습니다. 이어하기를 눌러주세요.")

func _on_upload(result: int, code: int, data: Variant) -> void:
	_upload_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		status_changed.emit("클라우드 저장 실패: " + _message(data))
	_drain_upload()
