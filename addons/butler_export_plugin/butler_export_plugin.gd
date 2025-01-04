@tool
@icon("res://addons/butler_export_plugin/icon.svg")
class_name ButlerExportPlugin
extends ToolEditorExportPlugin

## ButlerExportPlugin
## 
## An export plugin used to run Itch.io 's [code]butler[/code] utility,
## allowing for a automatic publishing to itch.io after export right form the Godot engine.
## Requires a local copy of [code]butler[/code] dowloaded to the system,
## as well as a known path to it, in order to operate.
## All options in this plugin are modifiable in the export, project, and editor settings,
## with the [code]export settings[/code] overriding the [ProjectSettings],
## which overide the [EditorSettings], if availible.
## Most option provided by this plugin corlate to their counterpart in the butler cli,
## excluding the [code]publish[/code] and [code]exe path[/code] options.
## The [code]publish[/code] option simply enables or disables publishing at all.
## The [code]exe path[/code] option is the path to the butler exe.
## Otherwise all option corlate to [code]butler[/code].[br]
## Requires the NovaTools plugin as a dependency.

## The settings path for the local path to the butler executable on this system.
const BUTLER_PATH_EDITOR_SETTING_PATH := "filesystem/tools/butler/butler_path"

## A mapping of godot's os names to butler's default channel names for that respective platform.
const OS_NAME_TO_BUTLER_CHANNEL_NAME := {
	"Windows": "win",
	"macOS": "mac",
	"Linux": "linux",
	"FreeBSD": "linux",
	"NetBSD": "linux",
	"OpenBSD": "linux",
	"BSD": "linux",
	"Android": "android",
	"Web": "html"
}

## The name oF the virtual method that could be included in a [EditorExportPlatformExtension]
## that if defined returns the default butler channel name.
const BUTLER_CHANNEL_DEFAULT_VIRTUAL_METHOD_NAME:StringName = "_get_butler_channel"

## A list of class names that inherit form [EditorExportPlatformExtension]
## but should be supported by this plugin.
const EXTRA_SUPPORTED_CLASSES_NAMES := ["SourceEditorExportPlatform"]

## Gets the default butler channel name for the given [EditorExportPlatform].
static func get_default_channel_name(export_platform:EditorExportPlatform) -> String:
	if export_platform.has_method(BUTLER_CHANNEL_DEFAULT_VIRTUAL_METHOD_NAME):
		return export_platform.call(BUTLER_CHANNEL_DEFAULT_VIRTUAL_METHOD_NAME)
	if OS_NAME_TO_BUTLER_CHANNEL_NAME.keys().has(export_platform.get_os_name()):
		return OS_NAME_TO_BUTLER_CHANNEL_NAME[export_platform.get_os_name()]
	return ""

## Launches butler in a external command window.
## [param exe_path] must be the system path to the butler executable file.
## [param path] must be the path to the file / folder to upload
## [param user], [param game] and [param channel] all directly corlate to the
## [code]user/game:channel[/code] section of the normal butler command.
## all other params corelate to their counterparts in the butler cli.
## Returns butler's exit code.
static func butler_launch(path:String,
						  user:String,
						  game:String,
						  channel:String,
						  version := "",
						  ignore_patterns := [],
						  dereference := false,
						  only_if_changed := false,
						  stay_open := true
						 ) -> int:
	
	var exe_path:String = NovaTools.get_editor_setting_default(BUTLER_PATH_EDITOR_SETTING_PATH, "")
	
	assert (exe_path != "")
	assert (path != "")
	assert (user != "")
	assert (game != "")
	assert (channel != "")
	
	var args := ["push"]
	if only_if_changed:
		args.append("--if-changed")
	if dereference:
		args.append("--dereference")
	for pattern in ignore_patterns:
		args.append("--ignore")
		args.append(pattern)
	args.append(path)
	args.append("%s/%s:%s" % [user, game, channel])
	if version and not version.is_empty():
		args.append("--userversion")
		args.append(version)
	return await NovaTools.launch_external_command_async(exe_path, args, stay_open)

## Initialises the editor setting for the butler exe path if it's not already initialised
## safely returning if ti is already initialised, without overwriting the setting's value.
static func try_init_bulter_prefix_editor_setting():
	NovaTools.try_init_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH,
									   "",
									   TYPE_STRING,
									   PROPERTY_HINT_GLOBAL_FILE
									  )

## Removes the editor setting for the butler path only if it already defined and
## is not changed from the default value.
static func try_deinit_bulter_prefix_editor_setting():
	NovaTools.try_init_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH, "")

func _get_export_options(platform):
	if not _supports_platform(platform):
		return []
	return [
		{
			"option" : {
				"name" : "butler/upload_to_itch.io",
				"type" : TYPE_BOOL,
			},
			"default_value" : false,
			"update_visibility" : true,
		},
		{
			"option" : {
				"name" : "butler/user",
				"type" : TYPE_STRING,
			},
			"default_value" : "",
		},
		{
			"option" : {
				"name" : "butler/game_name",
				"type" : TYPE_STRING,
			},
			"default_value" : ProjectSettings.get_setting("application/config/name"),
		},
		{
			"option" : {
				"name" : "butler/channel",
				"type" : TYPE_STRING,
			},
			"default_value" : get_default_channel_name(platform),
		},
		{
			"option" : {
				"name" : "butler/version",
				"type" : TYPE_STRING,
			},
			"default_value" : ProjectSettings.get_setting("application/config/version"),
		},
		{
			"option" : {
				"name" : "butler/ignore_file_patterns",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:"%[TYPE_STRING],
			},
			"default_value": [],
		},
		{
			"option" : {
				"name" : "butler/deference",
				"type" : TYPE_BOOL,
			},
			"default_value" : false,
		},
		{
			"option" : {
				"name" : "butler/only_if_changed",
				"type" : TYPE_BOOL,
			},
			"default_value" : false,
		},
		{
			"option" : {
				"name" : "butler/stay_open",
				"type" : TYPE_BOOL,
			},
			"default_value" : true,
		},
	]

func _get_export_option_warning(platform: EditorExportPlatform, option: String) -> String:
	if (get_option("butler/upload_to_itch.io") and
		option == "butler/upload_to_itch.io" and
		NovaTools.get_editor_setting_default(BUTLER_PATH_EDITOR_SETTING_PATH, "") == ""
	   ):
		return "Butler executable path not set!"
	return ""

func _get_export_option_visibility(platform: EditorExportPlatform, option: String) -> bool:
	if (not get_option("butler/upload_to_itch.io") and
		option.begins_with("butler/") and
		option != "butler/upload_to_itch.io"
	   ):
		return false
	return true

func _get_name():
	return "zzzzzzzzzzzzzzzzzzzzzzzzzz"
	#Name intentionally selected in order for this plugin to always be called last when exporting!
	# The engine calls export plugins based off of their names, sorted alphabetically.

func _supports_platform(platform:EditorExportPlatform):
	return ((not platform.is_class("EditorExportPlatformExtension")) or
			EXTRA_SUPPORTED_CLASSES_NAMES.any(func (n): return platform.is_class(n))
		   )

func _export_end_command(features:PackedStringArray, is_debug:bool, path:String, flags:int):
	push_warning("Please note, web publishing will not automatically set the uploaded files as \
	playbale in browser. Make sure to do this manually!")
	await butler_launch(ProjectSettings.globalize_path("res://" + path),
						get_option("butler/user"),
						get_option("butler/game_name"),
						get_option("butler/channel"),
						get_option("butler/version"),
						get_option("butler/ignore_file_patterns"),
						get_option("butler/deference"),
						get_option("butler/only_if_changed"),
						get_option("butler/stay_open")
					   )

func _get_export_features(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["butlerpush"])
