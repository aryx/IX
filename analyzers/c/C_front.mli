(* C files through mini-cc's front end into Facts (mini-cc -facts's
 * path, CLI's compile with the facts back end): the facts of a whole
 * program, each file's #includes' history, each function's file *)

(* a file read; its facts added to Facts's; the -D's, the -I's *)
val file : < Cap.open_in; .. > -> string list * Fpath.t list -> Fpath.t -> (unit, string) result

(* the file a function was read from (the last of that name) *)
val owner : (string, string) Hashtbl.t

(* each file's history of #includes (Pre.history's), the oldest first *)
val histories : (string, (string option * int) list) Hashtbl.t
