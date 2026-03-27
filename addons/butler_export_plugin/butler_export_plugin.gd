@tool
@icon("./icon.svg")
class_name ButlerExportPlugin
extends ToolEditorExportPlugin

## ButlerExportPlugin
##
## An export plugin used to run Itch.io 's [code]butler[/code] utility,
## allowing for a automatic publishing to itch.io after export right form the Godot engine.
## Requires a local copy of [code]butler[/code] downloaded to the system,
## as well as a known path to it, in order to operate.
## All options in this plugin are modifiable in the export, project, and editor settings,
## with the [code]export settings[/code] overriding the [ProjectSettings],
## which override the [EditorSettings], if available.
## Most option provided by this plugin corelate to their counterpart in the butler cli,
## excluding the [code]publish[/code] and [code]exe path[/code] options.
## The [code]publish[/code] option simply enables or disables publishing at all.
## The [code]exe path[/code] option is the path to the butler exe.
## Otherwise all option corelate to [code]butler[/code].[br]
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
## [param user], [param game] and [param channel] all directly corelate to the
## [code]user/game:channel[/code] section of the normal butler command.
## all other params corelate to their counterparts in the butler cli.
## Returns butler's exit code.
static func butler_push(path:String,
							user:String,
							game:String,
							channel:String,
							version := "",
							ignore_patterns := [],
							dereference := false,
							only_if_changed := false, identity_path := "",
							stay_open := true
							) -> int:

	user = user.strip_escapes().strip_edges()
	game = game.strip_escapes().strip_edges()
	channel = channel.strip_escapes().strip_edges()
	if user.is_empty() or game.is_empty() or channel.is_empty():
		return ERR_INVALID_PARAMETER

	path = NovaTools.normalize_path_absolute(path, false)
	if path.is_empty():
		return ERR_FILE_NOT_FOUND

	identity_path = identity_path.strip_escapes().strip_edges()
	if not identity_path.is_empty():
		identity_path = NovaTools.normalize_path_absolute(identity_path, false)
		if identity_path.is_empty():
			# we cant just continue on when the identity path couldn't be found...
			return ERR_FILE_NOT_FOUND

	var args := ["push"]
	identity_path = identity_path.strip_escapes().strip_edges()
	if not identity_path.is_empty():
		args.append("--identity")
		args.append(identity_path)
	if only_if_changed:
		args.append("--if-changed")
	if dereference:
		args.append("--dereference")
	for pattern in ignore_patterns:
		args.append("--ignore")
		args.append(pattern.strip_escapes().strip_edges())
	args.append(path)
	args.append("%s/%s:%s" % [user, game, channel])
	version = version.strip_escapes().strip_edges()
	if not version.is_empty():
		args.append("--userversion")
		args.append(version)
	return await butler_run(args, stay_open)

## Initialises the editor setting for the butler exe path if it's not already initialised
## safely returning if it is already initialised, without overwriting the setting's value.
static func try_init_butler_prefix_editor_setting():
	NovaTools.try_init_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH,
											"",
											TYPE_STRING,
											PROPERTY_HINT_GLOBAL_FILE,
											"butler, butler.*, *.exe,"
											)

## Removes the editor setting for the butler path only if it already defined and
## is not changed from the default value.
static func try_deinit_butler_prefix_editor_setting():
	NovaTools.remove_unused_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH, "")

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
				"hint" : PROPERTY_HINT_ENUM_SUGGESTION,
				"hint_string" : ",".join(_CHANNEL_NAME_SUGGESTIONS)
			},
			"default_value" : get_default_channel_name(platform),
		},
		{
			"option" : {
				"name" : "butler/version",
				"type" : TYPE_STRING,
				"hint" : PROPERTY_HINT_ENUM_SUGGESTION,
				"hint_string" : _get_version_suggestions(platform)
			},
			"default_value" : ProjectSettings.get_setting("application/config/version"),
			"update_visibility" : true,
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
				"name" : "butler/dereference",
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

func _get_export_option_warning(_platform:EditorExportPlatform, option: String) -> String:
	if (get_option("butler/upload_to_itch.io") and
		option == "butler/upload_to_itch.io" and
		NovaTools.get_editor_setting_default(BUTLER_PATH_EDITOR_SETTING_PATH, "") == ""
		):
		return "Butler executable path not set!"
	return ""

func _get_export_option_visibility(_platform:EditorExportPlatform, option: String) -> bool:
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

func _export_end_command(_features:PackedStringArray, _is_debug:bool, path:String, _flags:int):
	push_warning("Please note, web publishing will not automatically set the uploaded files as " +
					"playable in browser. Make sure to do this manually!" )
	await butler_launch(ProjectSettings.globalize_path("res://" + path),
						get_option("butler/user"),
						get_option("butler/game_name"),
						get_option("butler/channel"),
						get_option("butler/version"),
						get_option("butler/ignore_file_patterns"),
						get_option("butler/dereference"),
						get_option("butler/only_if_changed"),
						get_option("butler/stay_open")
						)

func _get_export_features(_platform:EditorExportPlatform, _debug:bool) -> PackedStringArray:
	return PackedStringArray(["butlerpush"])

func _get_version_suggestions(export_platform:EditorExportPlatform) -> String:
	var project_version := ProjectSettings.get_setting("application/config/version")
	var options := [project_version]

	var preset := get_export_preset()
	if preset != null:
		if export_platform is EditorExportPlatformWindows:
			options.append_array([
				preset.get_version("application/file_version", true),
				preset.get_version("application/product_version", true),
				preset.get_version("application/file_version", false),
				preset.get_version("application/product_version", false)
			])
		if export_platform is EditorExportPlatformAndroid:
			options.append_array([
				preset.get_version("version/name", false),
				preset.get_version("version/code", false)
			])
		if export_platform is EditorExportPlatformMacOS or export_platform is EditorExportPlatformIOS or export_platform.is_class("EditorExportPlatformVisionOS"):
			options.append_array([
				preset.get_version("application/version", false),
				preset.get_version("application/short_version", false)
			])

	options.append_array(_COMMON_VERISON_SUGGESTIONS)

	# join with commas, remove blanks, convert to strings, and deduplicate all in one go
	var ret := ""
	for o in options:
		if typeof(o) == TYPE_NIL:
			continue
		o = str(o)
		if o in ret or o.is_empty() or o == str(null):
			continue
		if not ret.is_empty():
			ret += ","
		ret += o

	return ret

static func get_butler_path() -> String:
	var exe_path := NovaTools.get_editor_setting_default(BUTLER_PATH_EDITOR_SETTING_PATH, "")
	return NovaTools.normalize_path_absolute(exe_path, false)

# Not thread safe, and it shouldnt have to be really
static func validate_butler_path(exe_path:String) -> int:
	exe_path = NovaTools.normalize_path_absolute(exe_path, false)
	if exe_path.is_empty():
		return ERR_FILE_NOT_FOUND

	var err:int = OK
	var ver_output_path := EditorInterface.get_editor_paths().get_cache_dir().path_join("butver.txt")
	if FileAccess.file_exists(ver_output_path):
		err = DirAccess.remove_absolute(ver_output_path)
		if err != OK:
			return err

	await NovaTools.launch_external_command_async(exe_path, ["version", ">", ver_output_path], false)

	var version_reported := FileAccess.get_file_as_string(ver_output_path)
	if version_reported.is_empty():
		err = FileAccess.get_open_error()
		if err != OK:
			return err

	if FileAccess.file_exists(ver_output_path):
		err = DirAccess.remove_absolute(ver_output_path)
		if err != OK:
			return err

	version_reported = version_reported.strip_escapes().strip_edges()
	if version_reported.is_empty():
		return ERR_FILE_UNRECOGNIZED

	return OK

static func butler_run(args := [], stay_open := false, validated := true):
	var exe_path := get_butler_path()
	if validated:
		var err := await validate_butler_path(exe_path)
		if err != OK:
			return err
	await NovaTools.launch_external_command_async(exe_path, args, stay_open)
	return OK

static func butler_version(stay_open := true) -> int:
	return await butler_run(["version"], stay_open, false)

static func butler_upgrade(stay_open := true) -> int:
	return await butler_run(["upgrade"], stay_open)

static func butler_login(stay_open := true) -> int:
	return await butler_run(["login"], stay_open)

static func butler_logout(stay_open := true) -> int:
	return await butler_run(["logout"], stay_open)

const _CHANNEL_NAME_SUGGESTIONS := [
	"win",
	"mac",
	"linux",
	"android",
	"html",
	"webapp"
]
const _COMMON_VERISON_SUGGESTIONS := ["latest","beta","demo","testing"]

