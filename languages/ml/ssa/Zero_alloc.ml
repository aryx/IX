(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Zero_alloc.mli *)

open Ssa

(* the runtime's C functions that make nothing (strings.c, floats.c:
 * a bound error raises bound_exn, made at startup) *)
let c_without_alloc =
  [ "ml_string_length"; "ml_string_get"; "ml_string_set";
    "caml_string_equal"; "caml_string_notequal"; "ml_floatarray_length" ]

let call = function
  | Ir.Direct lab when Hashtbl.mem Lower.zero_allocs lab -> None
  | Ir.Direct lab ->
      (* a function of this unit's name, f12_name<> (Lower's fun_label) *)
      let name =
        match String.index_opt lab '_', String.ends_with ~suffix:"<>" lab with
        | Some i, true -> String.sub lab (i + 1) (String.length lab - i - 3)
        | _ -> lab
      in
      Some (Printf.sprintf "calls %s, not [@@zero_alloc] in this unit" name)
  | Ir.Code _ -> Some "calls a function it does not know (a closure)"

(* what an instruction allocates, if it does *)
let why = function
  (* 247: a closure's tag (OCaml's Closure_tag, Lower's) *)
  | Alloc (tag, _) when tag = 247 -> Some "makes a closure"
  | Alloc _ -> Some "makes a block (a tuple, a record, a constructor's)"
  | Box _ -> Some "boxes a float"
  | Prim ((Ir.Float2 _ | Float1 _ | FloatOfInt | FloatIndex _ | FloatRound _ | FloatCall _), _) ->
      Some "boxes a float"
  | Prim ((Ir.Int32 _ | Int32OfInt | BytesGet 4), _) -> Some "makes an int32's block"
  | Op (Ir.Poly _, _) -> Some "compares by compare, in C (give the type)"
  | CallC (g, _) when List.mem g c_without_alloc -> None
  | CallC (g, _) -> Some (Printf.sprintf "calls C's %s, which may allocate" g)
  | Call (t, _) -> call t
  | _ -> None

let check (fn : func) =
  match Hashtbl.find_opt Lower.zero_allocs fn.name with
  | None -> ()
  | Some name ->
      let refuse what = failwith (Printf.sprintf "line %d: %s [@@zero_alloc]: it %s" fn.line name what) in
      (* a block that ends in a raise is the error's way out: what it
       * makes (the exception's block, mini-ml's at each raise) not
       * counted *)
      Array.iter (fun (b : block) ->
        match b.term with
        | Raise _ -> ()
        | term ->
            List.iter (fun v -> Option.iter refuse (why (Hashtbl.find fn.defs v))) b.body;
            match term with Tail (t, _) -> Option.iter refuse (call t) | _ -> ()) fn.blocks
