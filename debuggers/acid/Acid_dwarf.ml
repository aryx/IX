(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Acid_dwarf.mli *)

open Dwarf_info

let sprintf = Printf.sprintf

(* acid's keywords: a name that is one written with a $ (mini-cc's Acid) *)
let kwd = [ "adt"; "aggr"; "append"; "builtin"; "complex"; "defn"; "delete"; "do"; "else"; "eval";
            "head"; "if"; "local"; "loop"; "return"; "tail"; "then"; "union"; "whatis"; "while" ]
let amap s = if List.mem s kwd then "$" ^ s else s

(* DW_TAG_s and DW_AT_s *)
let t_struct = 0x13 and t_union = 0x17 and t_member = 0x0d and t_typedef = 0x16 and t_pointer = 0x0f
let t_base = 0x24 and t_array = 0x01 and t_enum = 0x04 and t_variable = 0x34
let at_type = 0x49 and at_size = 0x0b and at_encoding = 0x3e and at_member_loc = 0x38 and at_location = 0x02
let at_declaration = 0x3c

let decls units =
  let idx = index units in
  let get r = Hashtbl.find_opt idx r in
  let typ d = match ref_ d at_type with Some r -> get r | None -> None in
  (* through the typedefs, const and volatile *)
  let rec strip d = if d.tag = t_typedef || d.tag = 0x26 || d.tag = 0x35 then (match typ d with Some t -> strip t | None -> d) else d in
  (* a structure's name: its own, or the typedef's of an unnamed one *)
  let names = Hashtbl.create 64 in
  let rec walk d =
    if (d.tag = t_struct || d.tag = t_union) && name d <> None then Hashtbl.replace names d.off (Option.get (name d));
    if d.tag = t_typedef then
      (match typ d, name d with
       | Some t, Some n when (let t = strip t in (t.tag = t_struct || t.tag = t_union) && not (Hashtbl.mem names t.off)) ->
           Hashtbl.replace names (strip t).off n
       | _ -> ());
    List.iter walk d.children in
  List.iter walk units;
  let sname d = Hashtbl.find_opt names d.off in
  (* a scalar's format, 5c's letters (acidchar) *)
  let format d =
    let d = strip d in
    let size = match int d at_size with Some n -> n | None -> 8 in
    if d.tag = t_pointer then Some (if size = 8 then 'Y' else 'X')
    else if d.tag = t_array then Some 'a'
    else if d.tag = t_enum then Some (if size = 8 then 'V' else 'D')
    else if d.tag = t_base then
      match int d at_encoding, size with
      | Some 0x04, 4 -> Some 'f' | Some 0x04, _ -> Some 'F'
      | Some (0x06 | 0x05), 1 -> Some 'C'
      | Some (0x08 | 0x07 | 0x02 | 0x10), 1 -> Some 'b'
      | Some 0x05, 2 -> Some 'd' | Some (0x07 | 0x10), 2 -> Some 'u'
      | Some 0x05, 4 -> Some 'D' | Some (0x07 | 0x10), 4 -> Some 'U'
      | Some 0x05, _ -> Some 'V' | Some (0x07 | 0x10), _ -> Some 'W'
      | _ -> None
    else None in
  let offset m =
    match attr m at_member_loc with
    | Some (Int n) -> Some n
    | Some (Block b) when String.length b >= 2 && b.[0] = '\x23' ->
        (* DW_OP_plus_uconst n *)
        let rec uleb o v sh = let c = Char.code b.[o] in let v = v lor ((c land 0x7f) lsl sh) in
          if c land 0x80 <> 0 then uleb (o + 1) v (sh + 7) else v in
        Some (uleb 1 0 0)
    | _ -> None in
  let member m =
    match name m, offset m, typ m with
    | Some n, Some off, Some t ->
        let t = strip t in
        let n = amap n in
        if (t.tag = t_struct || t.tag = t_union) then
          Option.map (fun s -> sprintf "\t%s %d %s;\n" (amap s) off n) (sname t)
        else if t.tag = t_pointer then
          (match Option.map strip (typ t) with
           | Some p when (p.tag = t_struct || p.tag = t_union) && sname p <> None ->
               Some (sprintf "\t'A' %s %d %s;\n" (amap (Option.get (sname p))) off n)
           | _ -> Option.map (fun c -> sprintf "\t'%c' %d %s;\n" c off n) (format t))
        else Option.map (fun c -> sprintf "\t'%c' %d %s;\n" c off n) (format t)
    | _ -> None in
  let out = Buffer.create 4096 and seen = Hashtbl.create 64 in
  let rec types d =
    (if (d.tag = t_struct || d.tag = t_union) && attr d at_declaration = None then
       match sname d, int d at_size with
       | Some s, Some size when not (Hashtbl.mem seen s) ->
           Hashtbl.replace seen s ();
           let s = amap s in
           Buffer.add_string out (sprintf "sizeof%s = %d;\naggr %s\n{\n" s size s);
           List.iter (fun m -> if m.tag = t_member then Option.iter (Buffer.add_string out) (member m)) d.children;
           Buffer.add_string out "};\n\n"
       | _ -> ());
    List.iter types d.children in
  List.iter types units;
  (* the globals of a complex type, a pointer to one too (5c's acidvar) *)
  let rec deref d = let d = strip d in if d.tag = t_pointer then (match typ d with Some t -> deref t | None -> d) else d in
  List.iter (fun u ->
    List.iter (fun v ->
      match name v, attr v at_location, typ v with
      | Some n, Some (Block b), Some t when v.tag = t_variable && String.length b > 0 && b.[0] = '\x03' ->
          let t = deref t in
          if t.tag = t_struct || t.tag = t_union then
            Option.iter (fun s -> Buffer.add_string out (sprintf "complex %s %s;\n" (amap s) (amap n))) (sname t)
      | _ -> ()) u.children) units;
  Buffer.contents out
