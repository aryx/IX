(* This module holds the variables and the functions, and the
 * environment that carries both to children.
 *
 * A variable is a list of strings, and unset is the same as (). A
 * local assignment, x=v cmd, and a for loop's variable are dynamic:
 * they are set for the command, and put back after it, whatever it did
 * (principia's Xlocal, Xunlocal), so a function called inside sees
 * them.
 *
 * {b The environment.} Every variable is exported, as its list joined
 * by \001 so that a child rc splits it back. An empty list is not
 * exported. On Plan 9 it is an empty /env file, which reads back as
 * (), but a Unix program given X= sees one empty string; mini-mk met
 * that bug when building xix. Functions are exported too, as
 * fn#name={body} and a newline, and read back when rc starts. (This
 * was checked on 9base's rc, which writes fn#g={echo g} and a newline,
 * and needs the newline to read one back.) $path is a list kept in
 * step with $PATH, whose elements are joined by :.
 *
 * plan9-is-cleaner:
 * On Unix the environment is an array of "NAME=value" strings that
 * exec copies into the new program's memory. A child gets a copy, and
 * nothing it does to it is seen by anyone. On Plan 9 each variable is
 * a file in /env (the kernel's env device), which holds its
 * "components terminated by zero bytes", and a function is the file
 * /env/fn#name. Reading a variable is reading a file, ls /env lists
 * them, and whether a child shares its parent's or gets a copy is one
 * bit of rfork. There is no getenv in the kernel's interface, and no
 * third argument to main. The zero byte is what a Unix environment
 * string cannot hold, hence \001 here, as in plan9port.
 *
 * cs-history:
 * The environment came to Unix with the seventh edition (1979),
 * together with Bourne's shell, which needed it to hand its
 * variables down. bash exports its functions through it as rc does,
 * and its way of reading them back at startup was the Shellshock
 * hole of 2014: it gave text from the environment to the parser,
 * which ran what followed the function's body.
 *
 * References: principia's var.c, env.c; plan9port's rc (unix.c); Tom
 * Duff, "Rc -- The Plan 9 Shell" (1990), "Environment"; env(3) of
 * Plan 9's manual. *)

type t

val create : unit -> t

val get : t -> string -> string list
val set : t -> string -> string list -> unit

(* [local t name value f]: [f] with [name] set to [value], then put back *)
val local : t -> string -> string list -> (unit -> 'a) -> 'a

val status : t -> string
val set_status : t -> string -> unit

(* is $status true, that is, is every character a 0 or a | (status.c)? *)
val ok : t -> bool

val fn : t -> string -> Ast.cmd option
val set_fn : t -> string -> Ast.cmd option -> unit
val vars : t -> (string * string list) list   (* sorted, for whatis *)

(* the flags rc was given, and those set by the flag builtin *)
val flag : t -> char -> bool
val set_flag : t -> char -> bool -> unit

(* the environment, as a program's name=value strings, read in and
 * written out *)
val import : t -> string array -> unit
val export : t -> string array
