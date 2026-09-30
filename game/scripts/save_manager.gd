extends Node

const SAVE_PATH := "user://checkpoint.json"
const PLAYER_NAME_PATH := "user://player_name.txt"
const SAVE_VERSION := 1
var save_path := SAVE_PATH
var player_name_path := PLAYER_NAME_PATH

func has_checkpoint() -> bool:
	return FileAccess.file_exists(save_path)

func save_checkpoint(data: Dictionary) -> bool:
	var payload = data.duplicate(true)
	payload["save_version"] = SAVE_VERSION
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func load_checkpoint() -> Dictionary:
	if not has_checkpoint():
		return {}
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("save_version", -1)) != SAVE_VERSION:
		return {}
	return parsed

func clear_checkpoint() -> void:
	if has_checkpoint():
		DirAccess.remove_absolute(save_path)

func persistent_storage_available() -> bool:
	if OS.has_method("is_userfs_persistent"):
		return OS.is_userfs_persistent()
	return true

func get_player_name() -> String:
	if not FileAccess.file_exists(player_name_path):
		return ""
	var file = FileAccess.open(player_name_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges().left(20)

func save_player_name(value: String) -> bool:
	var name = value.strip_edges().left(20)
	if name.length() < 2:
		return false
	var file = FileAccess.open(player_name_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(name)
	file.close()
	return true
