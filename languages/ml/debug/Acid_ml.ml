(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Acid_ml.mli *)

open Scope

let sprintf = Printf.sprintf

(* the types the printer knows without a description *)
let predefined =
  [ "int"; "char"; "string"; "bytes"; "float"; "bool"; "unit"; "exn"; "array"; "list"; "format"; "format4";
    "< .. >"; "using"; "Int32.t"; "Int64.t" ]

let rec ty (t : Scope.ty) =
  match t with
  | Tvar v -> sprintf "{\"'%s\"}" v
  | Tarrow _ -> "{\"->\"}"
  | Ttuple ts -> sprintf "{\"*\", %s}" (String.concat ", " (List.map ty ts))
  | Tconstr (d, []) -> sprintf "{\"%s\"}" d.tpath
  | Tconstr (d, ts) -> sprintf "{\"%s\", %s}" d.tpath (String.concat ", " (List.map ty ts))

let params ps = "{" ^ String.concat ", " (List.map (sprintf "\"'%s\"") ps) ^ "}"

let record path ps (ls : (string * label) list) =
  let ls = List.sort (fun (_, (a : label)) (_, (b : label)) -> compare a.pos b.pos) ls in
  sprintf "mltypes = append mltypes, {\"%s\", %s, \"record\", %s};\n" path (params ps)
    (String.concat ", " (List.map (fun (l, (lb : label)) -> let _, t, _ = lb.ltype in sprintf "{\"%s\", %s}" l (ty t)) ls))

(* each type the values' types name, its description once, the types
 * its description names after it *)
let types (globals : Scope.ty list) =
  let seen = Hashtbl.create 16 and out = ref [] in
  let rec walk (t : Scope.ty) =
    match t with
    | Tvar _ -> ()
    | Tarrow (a, b) -> walk a; walk b
    | Ttuple ts -> List.iter walk ts
    | Tconstr (d, ts) ->
        List.iter walk ts;
        if not (List.mem d.tpath predefined || Hashtbl.mem seen d.tpath) then begin
          Hashtbl.replace seen d.tpath ();
          match d.tabbrev, Resolve.type_conses d, Resolve.type_fields d with
          | Some body, _, _ ->
              out := sprintf "mltypes = append mltypes, {\"%s\", %s, \"=\", %s};\n" d.tpath (params d.tparams) (ty body) :: !out;
              walk body
          | None, Some cs, _ ->
              let consts = List.filter_map (fun (c, (k : cons)) -> match k.kind with Const n -> Some (n, c) | _ -> None) cs in
              let blocks = List.filter_map (fun (c, (k : cons)) -> match k.kind with Block n -> Some (n, (c, k)) | _ -> None) cs in
              let consts = List.map snd (List.sort compare consts) in
              let blocks = List.map snd (List.sort (fun (a, _) (b, _) -> compare a b) blocks) in
              let block (c, (k : cons)) =
                let _, args, _ = k.ctype in
                String.concat ", " (sprintf "\"%s\"" c :: List.map ty args) in
              out := sprintf "mltypes = append mltypes, {%s};\n"
                       (String.concat ", " ([ sprintf "\"%s\"" d.tpath; params d.tparams; "\"variant\"";
                                              "{" ^ String.concat ", " (List.map (sprintf "\"%s\"") consts) ^ "}" ]
                                            @ List.map (fun b -> "{" ^ block b ^ "}") blocks)) :: !out;
              List.iter (fun (_, (k : cons)) ->
                let _, args, _ = k.ctype in
                (* C of { ... }: its record, t.C, described by C's labels *)
                (match k.cinline, args with
                 | (_ :: _ as ls), [ Tconstr (h, _) ] when not (Hashtbl.mem seen h.tpath) ->
                     Hashtbl.replace seen h.tpath ();
                     out := record h.tpath h.tparams ls :: !out;
                     List.iter (fun (_, (l : label)) -> let _, t, _ = l.ltype in walk t) ls
                 | _ -> List.iter walk args)) blocks
          | None, None, Some ls ->
              out := record d.tpath d.tparams ls :: !out;
              List.iter (fun (_, (l : label)) -> let _, t, _ = l.ltype in walk t) ls
          | None, None, None -> ()
        end
  in
  List.iter walk globals;
  List.rev !out

(* a symbol acid's lexer reads as one name, M.x *)
let plain sym =
  match String.index_opt sym '.' with
  | None -> false
  | Some i ->
      let ok c = c = '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') in
      String.for_all ok (String.sub sym 0 i) && i + 1 < String.length sym
      && (sym.[i + 1] = '_' || (sym.[i + 1] >= 'a' && sym.[i + 1] <= 'z'))
      && String.for_all ok (String.sub sym (i + 1) (String.length sym - i - 1))

(* the globals in the data: the assembly's GLOBLs (a constant folded
 * may have none) *)
let globls text =
  let h = Hashtbl.create 64 in
  List.iter (fun l ->
    let p = "\tGLOBL\t" in
    let n = String.length p in
    if String.length l > n && String.sub l 0 n = p then
      match String.index_from_opt l n '(' with Some j -> Hashtbl.replace h (String.sub l n (j - n)) () | None -> ())
    (String.split_on_char '\n' text);
  h

let decls ~text globals =
  let data = globls text in
  let globals = List.filter (fun (sym, _) -> plain sym && Hashtbl.mem data sym) globals in
  types (List.map snd globals)
  @ List.map (fun (sym, t) -> sprintf "mlglobals = append mlglobals, {\"%s\", %s};\n" sym (ty t)) globals
