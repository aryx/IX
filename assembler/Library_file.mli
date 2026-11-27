(* A library (lib.a) is a list of objects, each with the names it
 * defines, from which mini-ld (Link.load) takes those that define what is
 * undefined.
 * Its file is ix's own, a marshalled value as an object is, and not
 * ar's; mini-ar makes it (Plan 9's ar; xix's Library_file). In the
 * file, an index first, each member's source and the names it defines,
 * then the members' bytes. mini-ld reads as values only the members
 * it takes, mini-ar none, and mini-ml -start the index alone (the
 * sources, in order: the units a program starts). Here, in the
 * assembler's library, so that mini-ml reads it without the linker's. *)
type def_kind = T | D
type member = string * string * (def_kind * string) list
(* (the object and its file's bytes, which the member keeps) *)
val member_of : string -> Asm.obj -> member
val member_file : member -> string
(* each member's bytes and the names indexed for it (a text name that
 * a later member defines again is not indexed for that member, as in
 * ar) *)
val index : member list -> (string * string list) list
val read_library : < Cap.open_in; .. > -> Fpath.t -> member list
(* the members' sources, in their order, read from the file's index
 * alone, its first value (mini-ar t, mini-ml -start) *)
val read_sources : < Cap.open_in; .. > -> Fpath.t -> string list

val write_library : < Cap.open_out; .. > -> Fpath.t -> member list -> unit
(* the names an object defines, for the index: its TEXTs, GLOBLs and
 * DATAs (ar's objsym, 'T' and 'D') *)
val defined_names : Asm.obj -> (def_kind * string) list
(* the members' bytes and their names, as read_library and index *)
val read_members : < Cap.open_in; .. > -> Fpath.t -> (string * string list) list
