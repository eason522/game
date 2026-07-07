class_name RunSave
extends RefCounted

const DEFAULT_SAVE_PATH := "user://tymj_run_save.json"


static func save_state(run_state, path: String = DEFAULT_SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(JSON.stringify(run_state.to_dict()))
	file.close()
	return true


static func load_dict(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed


static func has_save(path: String = DEFAULT_SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete_save(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true

	var directory := path.get_base_dir()
	var file_name := path.get_file()
	var dir := DirAccess.open(directory)

	if dir == null:
		return false

	return dir.remove(file_name) == OK
