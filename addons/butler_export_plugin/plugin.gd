@tool
@icon("res://addons/butler_export_plugin/icon.svg")
extends EditorPlugin

const PLUGIN_NAME := "butler_export_plugin"
const PLUGIN_ICON := preload("res://addons/butler_export_plugin/icon.svg")

var _current_inst:ButlerExportPlugin = null

func _get_plugin_icon():
	return PLUGIN_ICON

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree():
	_try_init_plugin()

func _enable_plugin():
	_try_init_plugin()

func _disable_plugin():
	_try_deinit_plugin()

func _exit_tree():
	_try_deinit_plugin()

func _try_init_plugin():
	if _current_inst == null:
		ButlerExportPlugin.try_init_bulter_prefix_editor_setting()
		_current_inst = ButlerExportPlugin.new()
		add_export_plugin(_current_inst)

func _try_deinit_plugin():
	if _current_inst != null:
		ButlerExportPlugin.try_deinit_bulter_prefix_editor_setting()
		remove_export_plugin(_current_inst)
		_current_inst = null
