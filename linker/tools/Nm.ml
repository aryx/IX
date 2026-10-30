(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-nm: Plan 9's nm (principia's linkers/misc/nm.c): the names an
 * executable's symbol table has (mini-ld -g's: linker/Symtab), or an
 * object's and a library's, a line each: the value, the letter, the
 * name, sorted by name.
 *
 *     T text   D data   B bss   (t, d, b: static, a name<>)
 *     L a leaf function   U undefined (an object's)
 *     with -a: f a path's component, z a history's path, m a frame,
 *     a a local, p a parameter
 *
 * -n by value, -s in the table's order; -g the global ones only; -u
 * the undefined only; -h no file's name before each line (it is there
 * with several files, or a library); -T a signature's column (0s: ix's
 * objects have none). The names starting with . or $ are left out but
 * with -a.
 *
 * wib:
 * An object or a library is ix's (mini-asm's, mini-cc's, mini-ml's),
 * not Plan 9's format: its names are listed with no value, as nm does
 * an object's.
 *
 * References: nm(1) of Plan 9's manual. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

exception Usage

type options = { a : bool; g : bool; h : bool; n : bool; s : bool; u : bool; t : bool }

(* nm.c's psym: which entries are listed *)
let wanted o (s : Symbols.sym) =
  let dots = s.name <> "" && (s.name.[0] = '.' || s.name.[0] = '$') in
  match s.typ with
  | 'T' | 'L' | 'D' | 'B' -> not o.u && (o.a || not dots)
  | 'b' | 'd' | 'l' | 't' -> not o.u && not o.g && (o.a || not dots)
  | 'U' -> not o.g
  | 'Z' -> o.a
  | _ -> o.a && not o.u && not o.g

(* an object's names: what it defines and what it names without *)
let of_object (obj : Asm.obj) =
  let defined = Hashtbl.create 64 and named = Hashtbl.create 64 in
  let letter (n : Asm.name) c = if n.static then Char.lowercase_ascii c else c in
  let syms = ref [] in
  let def (n : Asm.name) c = if not (Hashtbl.mem defined n.sym) then (Hashtbl.replace defined n.sym (); syms := { Symbols.value = 0; typ = letter n c; name = n.sym } :: !syms) in
  Array.iter (fun (it, _) -> match (it : Asm.item) with
    | Text (n, _, _) -> def n 'T'
    | Data (n, _, _, _) -> def n 'D'
    | _ -> ()) obj.items;
  Array.iter (fun (it, _) -> match (it : Asm.item) with
    | Globl (n, _, _) -> def n 'B'
    | Ins i -> List.iter (function Asm.Mem { base = SB; name = Some n; _ } | Asm.Addr { base = SB; name = Some n; _ } -> Hashtbl.replace named n.sym n | _ -> ()) i.args
    | _ -> ()) obj.items;
  Hashtbl.iter (fun s (n : Asm.name) -> if not (Hashtbl.mem defined s) && not n.static then syms := { Symbols.value = 0; typ = 'U'; name = s } :: !syms) named;
  List.rev !syms

(* nm.c's printsyms *)
let print (caps : < caps; .. >) o ~prefix (t : Symbols.t option) (syms : Symbols.sym list) =
  let syms = List.filter (wanted o) syms in
  let syms = if o.s then syms else List.stable_sort (fun (x : Symbols.sym) (y : Symbols.sym) -> if o.n then compare x.value y.value else compare x.name y.name) syms in
  let wid = if List.exists (fun (s : Symbols.sym) -> s.value <> 0) syms then 8 else 0 in
  let b = Buffer.create 4096 in
  List.iter (fun (s : Symbols.sym) ->
    Option.iter (fun p -> Buffer.add_string b (p ^ ":")) prefix;
    if o.t then Buffer.add_string b (Printf.sprintf "%8x " 0);
    let v = Printf.sprintf "%x" s.value in
    Buffer.add_string b (if s.value <> 0 || s.typ = 'a' || s.typ = 'p' then String.make (max 0 (wid - String.length v)) ' ' ^ v ^ " " else String.make wid ' ' ^ " ");
    let name = match t with Some t when s.typ = 'z' -> Symbols.path t s | _ -> s.name in
    Buffer.add_string b (Printf.sprintf "%c %s\n" s.typ name)) syms;
  Console.print caps (Buffer.contents b)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let o = ref { a = false; g = false; h = false; n = false; s = false; u = false; t = false } in
    let rec options = function
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then o := (match c with
            | 'a' -> { !o with a = true } | 'g' -> { !o with g = true } | 'h' -> { !o with h = true }
            | 'n' -> { !o with n = true } | 's' -> { !o with s = true } | 'u' -> { !o with u = true }
            | 'T' -> { !o with t = true } | _ -> raise Usage)) a;
          options rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    if files = [] then raise Usage;
    let o = !o and multi = List.length files > 1 in
    let ok = List.fold_left (fun ok f ->
      let prefix p = if (multi || p <> f) && not o.h then Some p else None in
      match FS.read caps (Fpath.v f) with
      | exception Sys_error m -> Console.eprint caps (Printf.sprintf "nm: cannot open %s: %s\n" f m); false
      | bytes ->
          match Symbols.read bytes with
          | Some t -> print caps o ~prefix:(prefix f) (Some t) t.syms; ok
          | None when Fpath.has_ext ".a" (Fpath.v f) ->
              List.iter (fun ((name, member, _) : Link.member) -> print caps o ~prefix:(prefix name) None (of_object (Asm.of_bytes member)))
                (Link.read_library caps (Fpath.v f));
              ok
          | None ->
              (match Asm.load caps (Fpath.v f) with
               | obj -> print caps o ~prefix:(prefix f) None (of_object obj); ok
               | exception (Failure _ | Invalid_argument _) -> Console.eprint caps (Printf.sprintf "nm: %s: no symbol table\n" f); false))
      true files in
    if ok then Exit.OK else Exit.Err "errors"
  with Usage -> Console.eprint caps "usage: nm [-aghnsTu] file ...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
