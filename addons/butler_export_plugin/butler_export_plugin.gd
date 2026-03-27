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

const _CHANNEL_NAME_SUGGESTIONS := [
	"win",
	"mac",
	"linux",
	"android",
	"html",
	"webapp"
]

const _COMMON_VERSION_SUGGESTIONS := ["latest", "beta", "demo", "testing"]

## Get the default butler channel name for the given [EditorExportPlatform] [param export_platform].
static func get_default_channel_name(export_platform:EditorExportPlatform) -> String:
	if export_platform.has_method(BUTLER_CHANNEL_DEFAULT_VIRTUAL_METHOD_NAME):
		return export_platform.call(BUTLER_CHANNEL_DEFAULT_VIRTUAL_METHOD_NAME)
	if OS_NAME_TO_BUTLER_CHANNEL_NAME.keys().has(export_platform.get_os_name()):
		return OS_NAME_TO_BUTLER_CHANNEL_NAME[export_platform.get_os_name()]
	return ""

## Determines the path of the butler executable,
## based off of the [EditorSettings] for it.[br]
## Returns an absolute filesystem path.
static func get_butler_path() -> String:
	var exe_path := NovaTools.get_editor_setting_default(BUTLER_PATH_EDITOR_SETTING_PATH, "")
	return NovaTools.normalize_path_absolute(exe_path, false)

## Validates the provided [param exe_path] as a
## likely candidate for a butler executable.[br]
## Returns an error code if an error was encountered when validating,
## or [constant OK] if no error was encountered.[br]
## This is only a rough sanity check for the provided executable,
## and may return false positives for other valid executable paths
## that aren't specifically a butler executable.
## It checks the existence of [param exe_path]
## and attempts to launch it with the [code]version[/code] argument,
## expecting any non empty output.[br]
## NOTE: while highly unlikely to ever happen, if this is run multiple times during
## the exact same reported value from [method Time.get_unix_time_from_system],
## subsequent checks will product the [ERR_FILE_ALREADY_IN_USE] error.[br]
## [b]NOTE:[/b] Technically, this method is possibly not thread safe if run simultaneously
## and multiple times.
## Though, frankly, I'd have no clue why you would ever want to in the first place.
static func validate_butler_path(exe_path:String) -> int:
	exe_path = NovaTools.normalize_path_absolute(exe_path, false)
	if exe_path.is_empty():
		return ERR_FILE_NOT_FOUND

	var ver_name := "butver_%s.txt" % [Time.get_unix_time_from_system()]
	var ver_output_path := EditorInterface.get_editor_paths().get_cache_dir()
	ver_output_path = ver_output_path.path_join(ver_name)

	var err:int = OK
	if FileAccess.file_exists(ver_output_path):
		return ERR_FILE_ALREADY_IN_USE

	await NovaTools.launch_external_command_async(exe_path,
													["version", ">", ver_output_path],
													false
													)

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

## Executes butler with the provided [param args] in an independent terminal window.
## The butler executable path is determined by [method get_butler_path].[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.[br]
## If [param validated] is set (as it it by default),
## The butler executable path will also be checked using [param validate_butler_path]
## before launching. If validation fails, the resulting error will be returned.[br]
## Otherwise, [constant OK] will be returned.[br]
## [b]NOTE:[/b] This method is not aware of error output nor return codes produced
## by butler.
## [b]NOTE:[/b] See [param validate_butler_path] for notes on thread safety.
static func butler_run(args := [], stay_open := false, validated := true) -> int:
	var exe_path := get_butler_path()
	if validated:
		var err := await validate_butler_path(exe_path)
		if err != OK:
			return err
	await NovaTools.launch_external_command_async(exe_path, args, stay_open)
	return OK

## Executes butler with the [code]version[/code] argument in
## an independent terminal window.[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.[br]
## [b]NOTE:[/b] See [param butler_version] for notes on error output and thread safety.
static func butler_version(stay_open := true) -> int:
	return await butler_run(["version"], stay_open, false)

## Executes butler with the [code]upgrade[/code] argument in
## an independent terminal window.[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.[br]
static func butler_upgrade(stay_open := true) -> int:
	return await butler_run(["upgrade"], stay_open)

## Executes butler with the [code]login[/code] argument in
## an independent terminal window.[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.[br]
static func butler_login(stay_open := true) -> int:
	return await butler_run(["login"], stay_open)

## Executes butler with the [code]logout[/code] argument in
## an independent terminal window.[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.[br]
static func butler_logout(stay_open := true) -> int:
	return await butler_run(["logout"], stay_open)

## Attempts to open the publicly viewable page specially for the provided itch.io
## [param game] thats published by the provided [param user] in the system's browser.[br]
## Both [param user] and [param game] are required.[br]
## Returns [constant OK] on success or an error code otherwise.
static func open_game_itch_io_page(user:String, game:String) -> int:
	if user.is_empty() or game.is_empty():
		return ERR_INVALID_PARAMETER

	user = user.uri_encode()
	game = game.uri_encode()

	return OS.shell_open("https://%s.itch.io/%s" % [user, game])

## Executes butler with the [code]push[/code] argument in
## an independent terminal window.[br]
## [param path] must be the path to the file / folder to upload.[br]
## [param user], [param game] and [param channel] all directly corelate to the
## [code]user/game:channel[/code] section of butler CLI parameter and are all required.[br]
## If [param version] is a not empty, an explicit version will be set for the upload.[br]
## For each path pattern in [param ignore_patterns],
## paths matching that pattern will be ignored.[br]
## If [param dereference] is set, exported symlinks won't be referenced.[br]
## If [param only_if_changed] is set, butler will only upload if it detects changes.[br]
## If [param identity_path] is not empty,
## then the butler credentials stored at that path will be used for authentication
## when uploading.
## If provided, then the file must exist on the system.[br]
## If [param stay_open] is set, the terminal window will remain open after execution
## of butler is complete.
static func butler_push(path:String,
							user:String,
							game:String,
							channel:String,
							version := "",
							ignore_patterns := [],
							dereference := false,
							only_if_changed := false,
							identity_path := "",
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

## Initialises the editor setting for the butler executable path if it's not already initialised
## safely returning if it is, avoiding overwriting the setting's set value, if any.
static func try_init_butler_prefix_editor_setting() -> void:
	NovaTools.try_init_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH,
											"",
											TYPE_STRING,
											PROPERTY_HINT_GLOBAL_FILE,
											"butler, butler.*, *.exe,"
											)

## Removes the editor setting for the butler path only if it already defined and
## is not changed from the default value.
static func try_deinit_butler_prefix_editor_setting() -> void:
	NovaTools.remove_unused_editor_setting_path(BUTLER_PATH_EDITOR_SETTING_PATH, "")

func _suggest_whole_directory(export_platform:EditorExportPlatform) -> bool:
	if export_platform is EditorExportPlatformAndroid:
		return false
	if (export_platform is EditorExportPlatformWindows or
		export_platform is EditorExportPlatformLinuxBSD
		):
		var preset := get_export_preset()
		if preset == null:
			return false
		return not get_export_preset().get_or_env("binary_format/embed_pck", "")
	if export_platform is EditorExportPlatformWeb:
		return true
	return false

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
		if (export_platform is EditorExportPlatformMacOS or
			export_platform is EditorExportPlatformIOS or
			export_platform.is_class("EditorExportPlatformVisionOS")
			):
			options.append_array([
				preset.get_version("application/version", false),
				preset.get_version("application/short_version", false)
			])

	options.append_array(_COMMON_VERSION_SUGGESTIONS)

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

func _get_export_options(platform) -> Array:
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
				"name" : "butler/identity_path",
				"type" : TYPE_STRING,
				"hint": PROPERTY_HINT_GLOBAL_FILE,
				"hint_string": "butler_creds, *",
			},
			"default_value" : "",
		},
		{
			"option" : {
				"name" : "butler/enforce_whole_directory",
				"type" : TYPE_BOOL,
			},
			"default_value" : _suggest_whole_directory(platform),
		},
		{
			"option" : {
				"name" : "butler/allow_debug_builds",
				"type" : TYPE_BOOL,
			},
			"default_value" : false,
		},
		{
			"option" : {
				"name" : "butler/open_after_upload",
				"type" : TYPE_BOOL,
			},
			"default_value" : true,
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
	if not get_option("butler/upload_to_itch.io"):
		return ""
	match (option):
		"butler/upload_to_itch.io":
			if get_butler_path().is_empty():
				return "Butler executable path not set!"
		"butler/identity_path":
			var p := get_option("butler/identity_path")
			if not p.is_empty():
				p = NovaTools.normalize_path_absolute(p, false)
				if p.is_empty():
					return "%s cant be found." % [p]
		"butler/user":
			if get_option("butler/user").is_empty():
				return "Itch.io user must be provided."
		"butler/game_name":
			if get_option("butler/game_name").is_empty():
				return "Game name must be provided."
		"butler/channel":
			if get_option("butler/channel").is_empty():
				return "Channel must be provided."
	return ""

func _get_export_option_visibility(_platform:EditorExportPlatform, option: String) -> bool:
	if not get_option("butler/upload_to_itch.io") and option != "butler/upload_to_itch.io":
		return not option.begins_with("butler/")
	match (option):
		"butler/identity_path", "butler/stay_open", "butler/dereference":
			return get_export_preset().are_advanced_options_enabled()
	return true

func _get_name() -> String:
	return "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
	# Name intentionally selected in order for this plugin to always be called last when exporting!
	# The engine calls export plugins based off of their names, sorted alphabetically,
	# and this plugin must always go last; lest it upload an incomplete export.

func _supports_platform(platform:EditorExportPlatform) -> bool:
	return ((not platform.is_class("EditorExportPlatformExtension")) or
			EXTRA_SUPPORTED_CLASSES_NAMES.any(func (n): return platform.is_class(n))
			)

func _get_export_features(platform:EditorExportPlatform, debug:bool) -> PackedStringArray:
	if not _supports_platform(platform):
		return PackedStringArray()
	if not get_option("butler/upload_to_itch.io"):
		return PackedStringArray()
	if not get_option("butler/allow_debug_builds") and debug:
		return PackedStringArray()

	return PackedStringArray(["butlerpush"])

func _export_end_tool(features:PackedStringArray,
						is_debug:bool,
						path:String,
						_flags:int
						) -> void:
	if not get_option("butler/upload_to_itch.io"):
		return

	if not get_option("butler/allow_debug_builds") and is_debug:
		print("Not using butler to upload, as it's a debug build...")
		return

	if "web" in features:
		push_warning("Please note, web publishing will not automatically set the uploaded " +
						"files as playable in browser. Make sure to do this manually!")

	path = "res://".path_join(path)
	if get_option("butler/enforce_whole_directory"):
		path = path.get_base_dir()

	var err := await butler_push(path,
						get_option("butler/user"),
						get_option("butler/game_name"),
						get_option("butler/channel"),
						get_option("butler/version"),
						get_option("butler/ignore_file_patterns"),
						get_option("butler/dereference"),
						get_option("butler/only_if_changed"),
						get_option("butler/identity_path"),
						get_option("butler/stay_open")
						)
	if err != OK:
		push_error("Butler push returned an error: %s (%d)" % [error_string(err), err])
		return

	if get_option("butler/open_after_upload"):
		err = open_game_itch_io_page(get_option("butler/user"), get_option("butler/game_name"))
		if err != OK:
			push_error("Error when trying to open game webpage: %s (%d)" % [error_string(err), err])

func _export_begin_tool(_features:PackedStringArray,
						_is_debug:bool,
						_path:String,
						_flags:int
						) -> void:
	return
