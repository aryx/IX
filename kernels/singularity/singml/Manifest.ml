(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Manifest.mli *)

type resource =
  | Registers of int * int
  | Interrupt of int

exception Error of int * string

let read (tree : Ast.structure) : (string * resource) list =
  List.map (fun (item : Ast.item) ->
    let bad () = raise (Error (item.iloc, "a manifest's line is: let name = registers address bytes, or let name = interrupt number")) in
    match item.i with
    | Ivalue (Nonrec, [ ({ p = Pvar name; _ }, e) ], _) -> (
        match e.e with
        | Eapply ({ e = Eident [ "registers" ]; _ }, [ { e = Econst (Int at); _ }; { e = Econst (Int bytes); _ } ]) ->
            if at < 0 || bytes <= 0 || at land 3 <> 0 then raise (Error (item.iloc, name ^ ": registers are words, at an address that is one's"));
            (name, Registers (at, bytes))
        | Eapply ({ e = Eident [ "interrupt" ]; _ }, [ { e = Econst (Int n); _ } ]) -> (name, Interrupt n)
        | _ -> bad ())
    | _ -> bad ()) tree

let header (source : string) : string = Printf.sprintf "(* made by mini-singml from %s: not to be changed here *)\n" source

(* a resource is the handle of its place: the kernel gives them in the
 * manifest's order, before a parent gives its endpoints *)
let ml (source : string) (l : (string * resource) list) : string =
  header source
  ^ String.concat "" (List.mapi (fun (i : int) ((name, r) : string * resource) ->
      match r with
      | Registers _ -> Printf.sprintf "let %s : Sip.registers = Sip.granted_registers %d\n" name i
      | Interrupt _ -> Printf.sprintf "let %s : Sip.interrupt = Sip.granted_interrupt %d\n" name i) l)
  ^ Printf.sprintf "let endpoint (i : int) : Sip.endpoint = Sip.given (%d + i)\n" (List.length l)

let mli (source : string) (l : (string * resource) list) : string =
  header source
  ^ String.concat "" (List.map (fun ((name, r) : string * resource) ->
      match r with
      | Registers (at, bytes) -> Printf.sprintf "(* the %d bytes of registers at 0x%x of the peripherals' *)\nval %s : Sip.registers\n" bytes at name
      | Interrupt n -> Printf.sprintf "(* interrupt %d *)\nval %s : Sip.interrupt\n" n name) l)
  ^ "(* the endpoints this process's parent gave it, in order, from 0 *)\nval endpoint : int -> Sip.endpoint\n"

let grants (l : (string * resource) list) : string =
  "[" ^ String.concat "; " (List.map (fun ((_, r) : string * resource) ->
    match r with
    | Registers (at, bytes) -> Printf.sprintf "Registers (0x%x, 0x%x)" at bytes
    | Interrupt n -> Printf.sprintf "Interrupt %d" n) l) ^ "]"
