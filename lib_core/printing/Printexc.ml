(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* ix: without Printf, which Unix's printer would make every program
 * link (old: open Printf, sprintf locfmt, eprintf) *)
let locfmt file line first last msg =
  "File \"" ^ file ^ "\", line " ^ string_of_int line ^ ", characters " ^ string_of_int first ^ "-"
  ^ string_of_int last ^ ": " ^ msg

(* ix: an exception's name and arguments, these by their types when the
 * program describes them (mini-ml -g, mini-ld -g: the runtime's
 * typed.c), else by their words (old: ocaml-light's field and fields,
 * an integer, a string or a float, else _) *)
external described : exn -> string = "ml_exn_string"

(* ix: OCaml's (4.14): printers of the exceptions they know, the last
 * registered asked first *)
let printers = ref []
let register_printer p = printers := p :: !printers
let printed x = List.find_map (fun p -> try p x with _ -> None) !printers

let to_string x =
  match printed x with
  | Some s -> s
  | None -> (
      match x with
      | Out_of_memory -> "Out of memory"
      | Stack_overflow -> "Stack overflow"
      | Match_failure (file, first_char, last_char) -> locfmt file 0 first_char last_char "Pattern matching failed"
      | Assert_failure (file, first_char, last_char) -> locfmt file 0 first_char last_char "Assertion failed"
      | x -> described x)

(* ix: what the runtime asks of an uncaught exception with arguments
 * (exceptions.c's ml_uncaught): its printers' words, "" if none knows
 * it (the runtime's then) *)
let uncaught x = match printed x with Some s -> s | None -> ""
let () = Callback.register "Printexc.uncaught" uncaught

let print fct arg =
  try
    fct arg
  with x ->
    prerr_string ("Uncaught exception: " ^ to_string x ^ "\n");
    flush stderr;
    raise x

let catch fct arg =
  try
    fct arg
  with x ->
    flush stdout;
    prerr_string ("Uncaught exception: " ^ to_string x ^ "\n");
    exit 2

type loc_info =
  | Known_location of bool   (* is_raise *)
                    * string (* module *)
                    * int    (* pos *)
  | Unknown_location of bool (*is_raise*)

external get_exception_backtrace: 
  unit -> loc_info array option = "caml_get_exception_backtrace"


let format_loc_info pos li =
  let is_raise =
    match li with
    | Known_location(is_raise, _, _) -> is_raise
    | Unknown_location(is_raise) -> is_raise in
  let info =
    if is_raise 
    then
      if pos = 0 then "Raised at" else "Re-raised at"
    else
      if pos = 0 then "Raised by primitive operation at" else "Called from"
  in
  match li with
  | Known_location(is_raise, modname, charpos) ->
      info ^ " module " ^ modname ^ ", character " ^ string_of_int charpos
  | Unknown_location(is_raise) ->
      info ^ " unknown location"

(* ix: mini-ml's runtime says where the last exception was raised: the
 * addresses its stack had of calls, the innermost first (the runtime's
 * exceptions.c says how, and scripts/where.sh which functions they
 * are); "" when it does not (ML_TRACE, off mini-9pi). To be called
 * first in a handler. old: get_backtrace_locations below, OCaml's *)
external raise_trace : unit -> string = "ml_raise_trace"
let get_backtrace () = raise_trace ()

let get_backtrace_locations () =
  match get_exception_backtrace() with
  | None ->
     "(Program not linked with -g, cannot print stack backtrace)\n"
  | Some a ->
      let b = ref "" in
      for i = 0 to Array.length a - 1 do
        if a.(i) <> Unknown_location true 
        then b := !b ^ format_loc_info i a.(i) ^ "\n"
      done;
      !b


(* original in 4.01 *)
(*
type raw_backtrace
external get_raw_backtrace:
  unit -> raw_backtrace = "caml_get_exception_raw_backtrace"
 *)

(* partial implem just so we can compile Exception.ml in xix with ocaml-light *)
type raw_backtrace = string
let get_raw_backtrace () = get_backtrace ()
let raw_backtrace_to_string x = x
let get_callstack _n = get_backtrace ()

let raise_with_backtrace exn _backtrace = raise exn
