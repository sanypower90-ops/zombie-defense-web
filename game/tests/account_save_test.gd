extends SceneTree

const SaveManager = preload("res://scripts/save_manager.gd")
const TEST_USER := "00000000-0000-0000-0000-000000000001"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves = SaveManager.new()
	root.add_child(saves)
	saves.save_path = "/tmp/account_test_guest.json"
	saves.account_save_dir = "/tmp"
	saves.clear_checkpoint()
	if not saves.save_checkpoint({"player": {"item_inventory": {"heal": 2}}}):
		push_error("Cannot prepare guest save")
		quit(1)
		return
	saves.set_active_account(TEST_USER)
	saves.clear_checkpoint()
	if not saves.save_checkpoint({"player": {"item_inventory": {"armor": 3}}}):
		push_error("Cannot prepare account save")
		quit(1)
		return
	if saves.load_checkpoint().get("player", {}).get("item_inventory", {}).get("armor", 0) != 3:
		push_error("Account inventory was not saved")
		quit(1)
		return
	saves.clear_checkpoint()
	saves.set_active_account("")
	if saves.load_checkpoint().get("player", {}).get("item_inventory", {}).get("heal", 0) != 2:
		push_error("Guest inventory was overwritten by an account")
		quit(1)
		return
	saves.clear_checkpoint()
	print("ACCOUNT_SAVE_TEST_PASS: guest and account inventories are separate")
	quit(0)
