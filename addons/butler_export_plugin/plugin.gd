@tool
@icon("./icon.svg")
extends EditorPlugin

const PLUGIN_NAME := "butler_export_plugin"
const PLUGIN_ICON := preload("./icon.svg")

const _ENSURE_SCRIPT_DOCS:Array[Script] = [
    preload("./butler_export_plugin.gd")
]

var _current_inst:ButlerExportPlugin = null

# Every once ands a while the script docs simply refuse to update properly.
# This nudges the docs into a ensuring that the important scripts added by
# this addon are actually loaded.
func _ensure_script_docs() -> void:
	var edit := EditorInterface.get_script_editor()
	for scr in _ENSURE_SCRIPT_DOCS:
		edit.update_docs_from_script(scr)

func _get_plugin_icon():
	return PLUGIN_ICON

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree():
	_ensure_script_docs()
	_try_init_plugin()

func _enable_plugin():
	_ensure_script_docs()
	_try_init_plugin()

func _disable_plugin():
	_try_deinit_plugin()

func _exit_tree():
	_try_deinit_plugin()

func _try_init_plugin():
	if not EditorInterface.is_plugin_enabled(PLUGIN_NAME):
		return
	ButlerExportPlugin.try_init_butler_prefix_editor_setting()
	if _current_inst == null:
		_current_inst = ButlerExportPlugin.new()
		add_export_plugin(_current_inst)

func _try_deinit_plugin():
	ButlerExportPlugin.try_deinit_butler_prefix_editor_setting()
	if _current_inst != null:
		remove_export_plugin(_current_inst)
		_current_inst = null
