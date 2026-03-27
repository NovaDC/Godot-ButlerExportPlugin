@tool
@icon("./icon.svg")
extends EditorPlugin

## The plugin's name, as used internally by godot
## (corelate to its parent folder's name)
const PLUGIN_NAME_INTERNAL := "butler_export_plugin"

# The plugin's name.
const PLUGIN_NAME := "Butler Export Plugin"

## The plugin's icon.
const PLUGIN_ICON := preload("./icon.svg")

const _ENSURE_SCRIPT_DOCS:Array[Script] = [
    preload("./butler_export_plugin.gd")
]

const _BUTLER_TOOLS_SUBMENU_NAME := "itch.io Butler"

# Intended to be used as a constant.
# It just happens to be impossible to use static class methods
# in a constant's definition.
var _but_tools := {
	"Login..." : ButlerExportPlugin.butler_login,
	"Logout..." : ButlerExportPlugin.butler_logout,
	"Upgrade" : ButlerExportPlugin.butler_upgrade,
	"Version" : ButlerExportPlugin.butler_version
}

var _current_inst:ButlerExportPlugin = null
var _tool_menu:PopupMenu = null

# Every once ands a while the script docs simply refuse to update properly.
# This nudges the docs into a ensuring that the important scripts added by
# this addon are actually loaded.
func _ensure_script_docs() -> void:
	var edit := EditorInterface.get_script_editor()
	for scr in _ENSURE_SCRIPT_DOCS:
		edit.update_docs_from_script(scr)

func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _enter_tree() -> void:
	_ensure_script_docs()
	_try_init_plugin()

func _enable_plugin() -> void:
	_ensure_script_docs()
	_try_init_plugin()

func _disable_plugin() -> void:
	_try_deinit_plugin()

func _exit_tree() -> void:
	_try_deinit_plugin()

func _try_init_plugin() -> void:
	if not EditorInterface.is_plugin_enabled(PLUGIN_NAME_INTERNAL):
		return
	ButlerExportPlugin.try_init_butler_prefix_editor_setting()
	if _tool_menu == null:
		_tool_menu = PopupMenu.new()
		for tool_name in _but_tools:
			_tool_menu.add_item(tool_name)
		var on_index_pressed := func (index:int):
			var tool_name := _tool_menu.get_item_text(index)
			if tool_name in _but_tools:
				_but_tools[tool_name].call()
		_tool_menu.index_pressed.connect(on_index_pressed)
		add_tool_submenu_item(_BUTLER_TOOLS_SUBMENU_NAME, _tool_menu)
	if _current_inst == null:
		_current_inst = ButlerExportPlugin.new()
		add_export_plugin(_current_inst)

func _try_deinit_plugin() -> void:
	ButlerExportPlugin.try_deinit_butler_prefix_editor_setting()
	if _tool_menu != null:
		remove_tool_menu_item(_BUTLER_TOOLS_SUBMENU_NAME)
		_tool_menu = null
	if _current_inst != null:
		remove_export_plugin(_current_inst)
		_current_inst = null
