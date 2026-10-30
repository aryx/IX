(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Acid.mli *)

open Tree

let level = ref 0
let decls : string list ref = ref []
let text () = String.concat "" (List.rev !decls)

(* a declaration: what f writes (pr) *)
let out = Buffer.create 1024
let pr fmt = Printf.bprintf out fmt
let decl f = Buffer.clear out; f (); if Buffer.length out > 0 then decls := Buffer.contents out :: !decls

(* acid's keywords, a name that is one written with a $ *)
let kwd = [ "adt"; "aggr"; "append"; "builtin"; "complex"; "defn"; "delete"; "do"; "else"; "eval";
            "head"; "if"; "local"; "loop"; "return"; "tail"; "then"; "union"; "whatis"; "while" ]

let amap s = if List.mem s kwd then "$" ^ s else s

(* -aa: nothing from an #include *)
let included () = !level > 1 && Pre.depth () > 1

(* the symbols, 5c's order: bucket by bucket, each the last made first *)
let find p = Array.fold_left (fun acc l -> match acc with Some _ -> acc | None -> List.find_opt p l) None Tree_helpers.hash

let same (a : typ option) (b : typ option) = match a, b with Some a, Some b -> a == b | _ -> false

(* the tag whose structure has these elements (acidsue) *)
let acidsue (t : typ option) = if t = None then None else find (fun s -> match s.suetag with Some st -> same st.link t | None -> false)

(* the function of this type (acidfun) *)
let acidfun (t : typ option) = find (fun s -> same s.typ t)

(* 5c's numbers of the kinds, for what has no format *)
let number = function
  | Txxx -> 0 | Tchar -> 1 | Tuchar -> 2 | Tshort -> 3 | Tushort -> 4 | Tint -> 5 | Tuint -> 6 | Tlong -> 7
  | Tulong -> 8 | Tvlong -> 9 | Tuvlong -> 10 | Tfloat -> 11 | Tdouble -> 12 | Tvoid -> 13 | Tind -> 14
  | Tarray -> 15 | Tfunc -> 16 | Tstruct -> 17 | Tunion -> 18 | Tenum -> 19 | Tdot -> 20 | Told -> 21

(* a member's format (acidchar): an int's a long's or a short's, by its
 * width; a pointer's a 64-bit one on arm64 *)
let rec acidchar et =
  let width et = (Tree_helpers.ty et).width in
  match et with
  | Tchar -> 'C' | Tuchar -> 'b' | Tshort -> 'd' | Tushort -> 'u' | Tlong -> 'D' | Tulong -> 'U'
  | Tvlong -> 'V' | Tuvlong -> 'W' | Tfloat -> 'f' | Tdouble -> 'F' | Tarray -> 'a'
  | Tind -> if width Tind = width Tuvlong then 'Y' else 'X'
  | Tint -> acidchar (if width Tint = width Tlong then Tlong else Tshort)
  | Tuint -> acidchar (if width Tint = width Tlong then Tulong else Tushort)
  | _ -> '\000'

let rec elements (t : typ option) = match t with None -> [] | Some e -> e :: elements e.down

(* a member: in the aggr (decl) or in the function printing it *)
let rec acidmember (t : typ) off decl =
  let name = Option.map (fun (s : sym) -> amap s.name) t.tsym in
  let scalar () =
    match name with
    | None -> ()
    | Some n ->
        if decl then pr "\t'%c' %d %s;\n" (acidchar t.etype) (t.offset + off) n
        else pr "\tprint(\"\t%s\t\", addr.%s, \"\\n\");\n" n n in
  match t.etype with
  | Tind ->
      (match name with
       | None -> ()
       | Some n when not decl -> pr "\tprint(\"\t%s\t\", addr.%s\\X, \"\\n\");\n" n n
       | Some n ->
           let rec deref (l : typ) = if l.etype = Tind then deref (Tree_helpers.link l) else l in
           let l = deref t in
           (* (a pointer to a complex type 'A' and its name, else 'X') *)
           match (if Tree_helpers.typesu l.etype then acidsue l.link else None) with
           | Some s1 -> pr "\t'A' %s %d %s;\n" (amap s1.name) (t.offset + off) n
           | None -> scalar ())
  | Tint | Tuint | Tchar | Tuchar | Tshort | Tushort | Tlong | Tulong | Tvlong | Tuvlong | Tfloat | Tdouble | Tarray ->
      scalar ()
  | Tstruct | Tunion ->
      (match acidsue t.link with
       | None -> ()
       | Some s1 ->
           let s1 = amap s1.name in
           match decl, name with
           | true, None ->
               (* (an unnamed one's members, at its offset) *)
               pr "\t{\n";
               List.iter (fun l -> acidmember l (t.offset + off) decl) (elements t.link);
               pr "\t};\n"
           | true, Some n -> pr "\t%s %d %s;\n" s1 (t.offset + off) n
           | false, Some n -> pr "\tprint(\"%s %s {\\n\");\n\t%s(addr.%s);\n\tprint(\"}\\n\");\n" s1 n s1 n
           | false, None -> pr "\tprint(\"%s {\\n\");\n\t\t%s(addr+%d);\n\tprint(\"}\\n\");\n" s1 s1 (t.offset + off))
  | et -> pr "\tT%d\n" (number et)

let acidtype (t : typ) =
  if !level > 0 && not (included ()) then decl @@ fun () ->
    match acidsue t.link with
    | None -> ()
    | Some s ->
        let an = amap s.name in
        pr "sizeof%s = %d;\n" an t.width;
        pr "aggr %s\n{\n" an;
        List.iter (fun l -> acidmember l 0 true) (elements t.link);
        pr "};\n\n";
        pr "defn\n%s(addr) {\n\tcomplex %s addr;\n" an an;
        List.iter (fun l -> acidmember l 0 false) (elements t.link);
        pr "};\n\n"

let acidvar ~fn (s : sym) =
  let rec deref (t : typ option) = match t with Some { etype = Tind; link; _ } -> deref link | t -> t in
  if !level > 0 && not (included ()) then decl @@ fun () ->
    match deref s.typ with
    | None -> ()
    | Some t when t.etype = Tenum -> pr "%s = %Ld;\n" (amap s.name) s.svconst
    | Some t when not (Tree_helpers.typesu t.etype) -> ()
    | Some t ->
        match acidsue t.link with
        | None -> ()
        | Some s1 ->
            match s.sclass with
            | Cauto | Cparam ->
                Option.iter (fun (f : sym) -> pr "complex %s %s:%s;\n" (amap s1.name) (amap f.name) (amap s.name)) (acidfun fn)
            | Cextern | Cglobl | Cstatic | Clocal -> pr "complex %s %s;\n" (amap s1.name) (amap s.name)
            | _ -> ()
