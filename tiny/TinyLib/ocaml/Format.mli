(* TinyLib: lib_core/printing/Format, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Pierre Weis, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Format]: pretty printing: text in boxes, the lines broken
   at break hints and indented by the boxes' structure. *)

(* ix: the part of ocaml-light's Format that ix uses, with OCaml 4.14's
   names: the formatters and the functions on one (pp_...) and fprintf.
   It is what Logs's messages are made of. *)

type formatter;;
        (* A pretty-printer and its machinery: its queue, its stack of
           boxes, its margin (78 columns), where it writes. *)

val std_formatter : formatter;;
val err_formatter : formatter;;
val make_formatter :
        (string -> int -> int -> unit) -> (unit -> unit) -> formatter;;
        (* [make_formatter out flush] *)

(*** Boxes *)

val pp_close_box : formatter -> unit -> unit;;
        (* The most recently opened one. *)

(*** Formatting functions *)

val pp_print_as : formatter -> int -> string -> unit;;
        (* [pp_print_as ff len str] prints [str] as if it were of
           length [len]. *)
val pp_print_string : formatter -> string -> unit;;
val pp_print_char : formatter -> char -> unit;;

(*** Break hints *)

val pp_print_break : formatter -> int -> int -> unit;;
        (* [pp_print_break ff nspaces offset]: the line may be split here. *)
val pp_print_space : formatter -> unit -> unit;;
        (* [pp_print_break ff 1 0]: a space, or a new line ("@ "). *)
val pp_print_cut : formatter -> unit -> unit;;
        (* [pp_print_break ff 0 0]: nothing, or a new line ("@,"). *)
val pp_force_newline : formatter -> unit -> unit;;
val pp_print_flush : formatter -> unit -> unit;;
        (* All opened boxes are closed, all pending text displayed. *)
val pp_print_newline : formatter -> unit -> unit;;
        (* [pp_print_flush], then a new line. *)

(*** [printf] like functions for pretty-printing. *)

val fprintf : formatter -> ('a, formatter, unit) format -> 'a;;


(* ix: OCaml's later functions, those ix's programs use *)

(* a list's elements, pp_sep between two; its label is not optional
 * here (mini-ml has no optional argument) *)
val pp_print_list : pp_sep:(formatter -> unit -> unit) -> (formatter -> 'a -> unit) -> formatter -> 'a list -> unit
