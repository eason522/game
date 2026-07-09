extends SceneTree

const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const RunSaveScript := preload("res://scripts/roguelike/RunSave.gd")
const RunStateScript := preload("res://scripts/roguelike/RunState.gd")
const MapGeneratorScript := preload("res://scripts/roguelike/MapGenerator.gd")
const RUN_STATE_META := "tymj_run_state"

var failures: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	var scene = MainMenuScene.instantiate()
	root.add_child(scene)
	await process_frame

	if ProjectSettings.get_setting("application/run/main_scene", "") != "res://scenes/ui/MainMenu.tscn":
		failures.append("main menu: expected project main scene to point at the demo menu")

	if scene.title_label == null or scene.title_label.text != "天元迷局":
		failures.append("main menu: expected title label")

	if scene.subtitle_label == null or not scene.subtitle_label.text.contains("Demo"):
		failures.append("main menu: expected demo subtitle")

	if scene.start_button == null or scene.start_button.text != "新的 Run":
		failures.append("main menu: expected new run button")

	if scene.continue_button == null or not scene.continue_button.disabled:
		failures.append("main menu: expected continue button to be disabled without a save")

	if scene.battle_button == null or scene.battle_button.text != "单局战斗":
		failures.append("main menu: expected single-battle button")

	if scene.status_label == null or not scene.status_label.text.contains("暂无存档"):
		failures.append("main menu: expected no-save status text")

	var run_state := RunStateScript.new(MapGeneratorScript.new().generate_linear_route())
	RunSaveScript.save_state(run_state)
	scene._refresh_continue_state()

	if scene.continue_button.disabled:
		failures.append("main menu: expected continue button to enable when save exists")

	if scene.status_label == null or not scene.status_label.text.contains("可继续"):
		failures.append("main menu: expected continue status text")

	scene.queue_free()
	RunSaveScript.delete_save()

	if root.has_meta(RUN_STATE_META):
		root.remove_meta(RUN_STATE_META)

	await process_frame

	if failures.is_empty():
		print("Main menu smoke tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
