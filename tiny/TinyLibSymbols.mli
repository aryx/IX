(* A program's labels, as tiny-linker writes them: "address label" lines,
 * the address in hexadecimal, in a map beside the image (-map: what
 * tiny-prof reads) or after it in an a.out (-s: what debug reads, Plan
 * 9's a.out symbol table). tiny-prof names the function an instruction
 * was counted in, debug the one a stop is in and the one a breakpoint
 * is set at (b main); both by these functions, which were tiny-prof's.
 *
 * A label a compiler makes inside a function (tiny-ml's
 * TinyBrowser.L12, tiny-c's tm.L51) is not a function, and is left
 * out: an address in it is in the function before it. An assembly
 * loop's labels (row_copy2) are kept, as they say which loop. tiny-ml's
 * functions are named TinyBrowser.f151_browse: shown as browse. *)

(* [local name]: whether it is a label a compiler made inside a function *)
val local : string -> bool

(* [clean name]: a function's name as shown (browse for
 * TinyBrowser.f151_browse, but an anonymous one's whole) *)
val clean : string -> string

(* [labels text]: the labels of "address label" lines, but the local
 * ones, by address *)
val labels : string -> (string * int) array

(* [find funcs pc]: the function pc is in (the last label at or before
 * it), its name cleaned, and its address *)
val find : (string * int) array -> int -> (string * int) option

(* [address funcs name]: the address of the function of that name, or
 * cleaned name (main, browse) *)
val address : (string * int) array -> string -> int option
