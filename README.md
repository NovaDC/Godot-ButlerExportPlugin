# ButlerExportPlugin

> Automatically upload Godot projects to itch.io on export using butler.

An export plugin used to run Itch.io 's `butler` utility,
allowing for a automatic publishing to itch.io after export right form the Godot engine.
Requires a local copy of `butler` downloaded to the system,
as well as a known path to it, in order to operate.
All options in this plugin are modifiable in the export, project, and editor settings,
with the export settings overriding the `ProjectSettings`,
which override the `EditorSettings`, if available.
Most option provided by this plugin corelate to their counterpart in the butler cli,
excluding the `publish` and `exe path` options.
The `publish` option simply enables or disables publishing at all.
The `exe path` option is the path to the butler exe.
Otherwise all option corelate to `butler`.
