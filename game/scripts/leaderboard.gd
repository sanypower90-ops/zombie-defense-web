extends Node

signal top10_ready(entries: Array, remote: bool, message: String)
signal submit_done(ok: bool, message: String)

const Config = preload("res://config/leaderboard_config.gd")
const LOCAL_PATH := "user://local_leaderboard.json"

var _get_request: HTTPRequest
var _post_request: HTTPRequest

func _ready() -> void:
	_get_request = HTTPRequest.new()
	_post_request = HTTPRequest.new()
	add_child(_get_request)
	add_child(_post_request)
	_get_request.request_completed.connect(_on_get_completed)
	_post_request.request_completed.connect(_on_post_completed)

func remote_enabled() -> bool:
	return not Config.SUPABASE_URL.is_empty() and not Config.SUPABASE_ANON_KEY.is_empty()

func fetch_top10() -> void:
	if not remote_enabled():
		top10_ready.emit(_load_local_top10(), false, "로컬 랭킹")
		return
	var base = Config.SUPABASE_URL.trim_suffix("/")
	var url = "%s/rest/v1/%s?select=nickname,score,max_round,kills,created_at&order=score.desc,max_round.desc,kills.desc,created_at.asc&limit=10" % [base, Config.TABLE_NAME]
	var headers = PackedStringArray([
		"apikey: %s" % Config.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % Config.SUPABASE_ANON_KEY
	])
	var err = _get_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		top10_ready.emit(_load_local_top10(), false, "온라인 랭킹 연결 실패")

func submit_score(nickname: String, score: int, max_round: int, kills: int) -> void:
	var row = {
		"nickname": nickname,
		"score": score,
		"max_round": max_round,
		"kills": kills
	}
	_save_local_score(row)
	if not remote_enabled():
		submit_done.emit(true, "로컬 랭킹에 저장되었습니다.")
		return
	var base = Config.SUPABASE_URL.trim_suffix("/")
	var url = "%s/rest/v1/%s" % [base, Config.TABLE_NAME]
	var headers = PackedStringArray([
		"apikey: %s" % Config.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % Config.SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	])
	var err = _post_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(row))
	if err != OK:
		submit_done.emit(false, "온라인 제출 실패. 로컬에는 저장되었습니다.")

func _on_get_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		top10_ready.emit(_load_local_top10(), false, "온라인 랭킹 응답 오류")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		top10_ready.emit(_load_local_top10(), false, "온라인 랭킹 형식 오류")
		return
	var entries: Array = parsed
	top10_ready.emit(entries, true, "글로벌 랭킹")

func _on_post_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code >= 200 and response_code < 300:
		submit_done.emit(true, "글로벌 랭킹 등록 완료")
	else:
		submit_done.emit(false, "온라인 제출 실패. 로컬에는 저장되었습니다.")

func _load_local_top10() -> Array:
	if not FileAccess.file_exists(LOCAL_PATH):
		return []
	var f = FileAccess.open(LOCAL_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var rows: Array = parsed
	rows.sort_custom(_score_before)
	if rows.size() > 10:
		rows.resize(10)
	return rows

func _save_local_score(row: Dictionary) -> void:
	var rows = _load_local_top10()
	rows.append(row)
	rows.sort_custom(_score_before)
	if rows.size() > 10:
		rows.resize(10)
	var f = FileAccess.open(LOCAL_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(rows))
		f.close()

func _score_before(a: Dictionary, b: Dictionary) -> bool:
	var sa = int(a.get("score", 0))
	var sb = int(b.get("score", 0))
	if sa != sb:
		return sa > sb
	var ra = int(a.get("max_round", 0))
	var rb = int(b.get("max_round", 0))
	if ra != rb:
		return ra > rb
	return int(a.get("kills", 0)) > int(b.get("kills", 0))
