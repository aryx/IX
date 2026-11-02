(* C files through mini-cc's front end into Facts (what was mini-cc
 * -facts: CLI's compile with a facts back end): the facts of a whole
 * program, each file's #includes' history, each function's file *)

(* a file read; its facts added to Facts's; the -D's, the -I's *)
val file : < Cap.open_in; .. > -> string list * Fpath.t list -> Fpath.t -> (unit, string) result

(* a file read by mini-cc's front end, on arm64: init sets its hooks
 * (Check's, Declare.gextern), codgen is given each function; the
 * error, file and line (C_flow's way in too) *)
val read :
  < Cap.open_in; .. > -> string list * Fpath.t list -> init:(unit -> unit) ->
  codgen:(Tree.sym -> Tree.stmt -> unit) -> Fpath.t -> (unit, string) result

(* the file a function was read from (the last of that name) *)
val owner : (string, string) Hashtbl.t

(* each file's history of #includes (Pre.history's), the oldest first *)
val histories : (string, (string option * int) list) Hashtbl.t
