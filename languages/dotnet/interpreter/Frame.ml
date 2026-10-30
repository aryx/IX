(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Frame.mli *)

open Value

exception Error of string
exception Unhandled of string * string
exception Stack_overflow

let trace : (string -> unit) option ref = ref None
let steps = ref 0

let error (s : string) = raise (Error s)

type frame = {
  meth : meth;
  code : code;
  args : value array;
  locals : value array;
  stack : value array;
  mutable sp : int;
  mutable pc : int;              (* the next instruction *)
  mutable at : int;              (* the one running *)
  mutable caught : store option; (* the exception of the catch running: rethrow's *)
}

(* the frames running, the innermost first *)
let frames : frame list ref = ref []

(* the frames running, and their most *)
let depth = ref 0
let max_depth = 10_000

(* .NET does not let a program catch it: it stops the process *)

(* how a run of a method's instructions ends *)
type outcome = Returned of value | End_finally | Filtered of bool

let name_of (m : meth) : string = m.mcls.name ^ "::" ^ m.mname

(* ------------------------------------------------------------------ *)
(* Exceptions *)
(* ------------------------------------------------------------------ *)

(* pass 1's choice: the frame and the clause that will catch, a filter
 * having said yes *)
let chosen : (frame * int) option ref = ref None

(* a filter run: in its frame, as that frame stands, the exception its
 * argument; true if it takes it (an exception in it: false) *)
let filter_hook : (frame -> clause -> store -> bool) ref = ref (fun _ _ _ -> false)

(* pass 1: which frame's clause will catch it? Nothing is unwound; a
 * filter's code is run to say *)
let handled (exn : store) : bool =
  chosen := None;
  let rec frames_from l = match l with
    | [] -> false
    | f :: rest ->
        let rec clauses i =
          if i >= Array.length f.code.clauses then frames_from rest
          else
            let c = f.code.clauses.(i) in
            if f.at >= c.tstart && f.at < c.tend
               && (match c.ckind, c.catch with
                   | 0, Some k -> subclass exn.cls k
                   | 1, _ -> !filter_hook f c exn
                   | _ -> false)
            then (chosen := Some (f, i); true)
            else clauses (i + 1) in
        clauses 0 in
  frames_from !frames

let message (st : store) : string =
  let rec find (c : cls) = match List.find_opt (fun (f : field) -> f.fname = "_message") c.fields with
    | Some f -> (match st.r.(f.roff) with Str s -> s | _ -> "")
    | None -> (match c.parent with Some p -> find p | None -> "") in
  find st.cls

let throw (exn : store) : 'a =
  if handled exn then raise (Thrown exn)
  else raise (Unhandled (exn.cls.name, message exn))

(* an exception of the library's, made by the machine *)
let throw_new (name : string) (msg : string) : 'a =
  let c = Types.find_class name [||] in
  let st = make_store c 0 in
  let rec set (c : cls) = match List.find_opt (fun (f : field) -> f.fname = "_message") c.fields with
    | Some f -> st.r.(f.roff) <- Str msg
    | None -> (match c.parent with Some p -> set p | None -> ()) in
  set c;
  throw st

let null_ref () = throw_new "System.NullReferenceException" "Object reference not set to an instance of an object."
let out_of_range () = throw_new "System.IndexOutOfRangeException" "Index was outside the bounds of the array."
let overflow () = throw_new "System.OverflowException" "Arithmetic operation resulted in an overflow."
let invalid_cast (from : cls) (to_ : cls) =
  throw_new "System.InvalidCastException"
    ("Unable to cast object of type '" ^ from.name ^ "' to type '" ^ to_.name ^ "'.")
