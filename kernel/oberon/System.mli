(* The system's commands (Oberon's System): those of every viewer's
 * menu (System.Close, Copy, Grow) and of System.Tool (Open,
 * Directory, the files', ShowModules, ShowCommands, Watch...); and,
 * when the module starts, the log and the two viewers of the system
 * track.
 *
 * A command's parameter is what follows its name where it was called
 * (Oberon.par); a ^ there means the latest selection.
 *
 * Not here: Free and FreeFonts (no module is unloaded), Date and the
 * clock, SetUser, Collect, SetColor and SetOffset. *)

val standard_menu : string
val log_menu : string
