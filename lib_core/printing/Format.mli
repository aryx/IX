(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Pierre Weis, projet Cristal, INRIA Rocquencourt          *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  Distributed only by permission.                   *)
(*                                                                     *)
(***********************************************************************)


(* Module [Format]: pretty printing *)

(* This module implements a pretty-printing facility to format text
   within ``pretty-printing boxes''. The pretty-printer breaks lines
   at specified break hints, and indents lines according to the box
   structure. *)

(* ix: the part of ocaml-light's Format that ix uses, with OCaml 4.14's
   names: the formatters and the functions on one (pp_...), fprintf and
   printf. It is what a derived printer is made of ([@@deriving show]:
   languages/ml/pp/Derive), and Logs's messages. The rest is listed at
   the end, to restore from ocaml-light's stdlib/format.ml if needed. *)

type formatter;;
        (* Abstract data type corresponding to a pretty-printer and
           all its machinery: its queue, its stack of boxes, its margin
           (78 columns), where it writes. *)

val std_formatter : formatter;;
        (* The standard formatter: it writes to [stdout]. *)
val err_formatter : formatter;;
        (* A formatter that writes to [stderr]. *)
val formatter_of_buffer : Buffer.t -> formatter
        (* A formatter that appends to the buffer; nothing is in the
           buffer before [pp_print_flush]. *)
val make_formatter :
        (string -> int -> int -> unit) -> (unit -> unit) -> formatter;;
        (* [make_formatter out flush] returns a new formatter that
           writes according to the output function [out], and flushing
           function [flush]. Hence, a formatter to out channel [oc]
           is returned by [make_formatter (output oc) (fun () -> flush oc)]. *)

(*** Boxes *)

val pp_open_box : formatter -> int -> unit;;
        (* [pp_open_box ff d] opens a new pretty-printing box with
           offset [d]: a break hint in it breaks the line only if there
           is no more room on it, or if it reduces the indentation.
           When a new line is printed in the box, [d] is added to the
           current indentation. A derived printer's "@[<2>". *)
val pp_close_box : formatter -> unit -> unit;;
        (* Close the most recently opened pretty-printing box. *)
val pp_open_hbox : formatter -> unit -> unit;;
        (* An ``horizontal'' box: its break hints never break the line. *)
val pp_open_vbox : formatter -> int -> unit;;
        (* A ``vertical'' box: every break hint breaks the line. *)
val pp_open_hvbox : formatter -> int -> unit;;
        (* ``Horizontal-vertical'': an horizontal box if it fits on a
           single line, a vertical one otherwise. *)
val pp_open_hovbox : formatter -> int -> unit;;
        (* ``Horizontal or vertical'': a break hint breaks the line only
           if there is no more room on it. *)

(*** Formatting functions *)

val pp_print_as : formatter -> int -> string -> unit;;
        (* [pp_print_as ff len str] prints [str] in the current box, as
           if it were of length [len]. *)
val pp_print_string : formatter -> string -> unit;;
val pp_print_int : formatter -> int -> unit;;
val pp_print_float : formatter -> float -> unit;;
val pp_print_char : formatter -> char -> unit;;
val pp_print_bool : formatter -> bool -> unit;;

(*** Break hints *)

val pp_print_break : formatter -> int -> int -> unit;;
        (* [pp_print_break ff nspaces offset]: the line may be split
           here. If it is not, [nspaces] spaces are printed; if it is,
           [offset] is added to the current indentation. *)
val pp_print_space : formatter -> unit -> unit;;
        (* [pp_print_break ff 1 0]: a space, or a new line ("@ "). *)
val pp_print_cut : formatter -> unit -> unit;;
        (* [pp_print_break ff 0 0]: nothing, or a new line ("@,"). *)
val pp_force_newline : formatter -> unit -> unit;;
        (* Force a newline in the current box. *)
val pp_print_if_newline : formatter -> unit -> unit;;
        (* Execute the next formatting command if the preceding line
           has just been split. Otherwise, ignore it. *)
val pp_print_flush : formatter -> unit -> unit;;
        (* Flush the pretty printer: all opened boxes are closed, and
           all pending text is displayed. *)
val pp_print_newline : formatter -> unit -> unit;;
        (* Equivalent to [pp_print_flush] followed by a new line. *)

(*** [printf] like functions for pretty-printing. *)

val fprintf : formatter -> ('a, formatter, unit) format -> 'a;;
        (* [fprintf ff format arg1 ... argN] formats the arguments
           [arg1] to [argN] according to the format string [format],
           and outputs the resulting string on the formatter [ff].
           The format is a character string which contains three types of
           objects: plain characters and conversion specifications as
           specified in the [printf] module, and pretty-printing
           indications.
           The pretty-printing indication characters are introduced by
           a [@] character, and their meanings are:
-          [\[]: open a pretty-printing box. The type and offset of the
           box may be optionally specified with the following syntax:
           the [<] character, followed by an optional box type indication,
           then an optional integer offset, and the closing [>] character. 
           Box type is one of [h], [v], [hv], or [hov],
           which stand respectively for an horizontal, vertical,
           ``horizontal-vertical'' and ``horizontal or vertical'' box.
-          [\]]: close the most recently opened pretty-printing box.
-          [,]: output a good break as with [print_cut ()].
-          [ ]: output a space, as with [print_space ()].
-          [\n]: force a newline, as with [force_newline ()].
-          [;]: output a good break as with [print_break]. The
           [nspaces] and [offset] parameters of the break may be
           optionally specified with the following syntax: 
           the [<] character, followed by an integer [nspaces] value,
           then an integer offset, and a closing [>] character. 
-          [.]: flush the pretty printer as with [print_newline ()].
-          [@]: a plain [@] character. *)

val printf : ('a, formatter, unit) format -> 'a;;
        (* Same as [fprintf], but output on [std_formatter]. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* a list's elements, pp_sep between two; its label is not optional
 * here (mini-ml has no optional argument) *)
val pp_print_list : pp_sep:(formatter -> unit -> unit) -> (formatter -> 'a -> unit) -> formatter -> 'a list -> unit

(* ix: what ocaml-light's Format has and this one dropped (2026-10-04;
 * nothing in ix called them), to restore from its stdlib/format.ml:
 * - the same functions on the standard formatter, without a formatter:
 *   open_box, open_hbox, open_vbox, open_hvbox, open_hovbox, close_box,
 *   print_string, print_as, print_int, print_float, print_char,
 *   print_bool, print_break, print_cut, print_space, force_newline,
 *   print_flush, print_newline, print_if_newline; eprintf;
 * - tabulation boxes: (pp_)open_tbox, close_tbox, print_tbreak,
 *   set_tab, print_tab;
 * - the margin and the limits, read and set: (pp_)set_margin,
 *   get_margin, set_max_indent, get_max_indent, set_max_boxes,
 *   get_max_boxes, over_max_boxes, set_ellipsis_text,
 *   get_ellipsis_text. The margin is 78 columns, the boxes' depth has
 *   no limit (it was 35 in ocaml-light, as in OCaml before 4.14's
 *   max_int: a tree any deeper was printed as the ellipsis, ".");
 * - where a formatter writes, changed after it is made:
 *   (pp_)set_formatter_out_channel, set_formatter_output_functions,
 *   get_formatter_output_functions. *)
