(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Csc_compile.mli *)

module A = Csc_ast
module W = Writer
module M = Metadata
open Csc_types

let has (mods : A.modifier list) (x : A.modifier) : bool = List.mem x mods

(* ECMA's II.23.1.10: a method's flags (public and hidebysig always) *)
let flags (k : cls) (mt : meth) (getter : bool) : int =
  let base = 0x0006 lor 0x0080 in
  if mt.mname = ".ctor" then 0x1886
  else if mt.mname = ".cctor" then 0x1891
  else if k.kind = K_interface then 0x05C6
  else
    base
    lor (if mt.mstatic then 0x0010 else 0)
    lor (if mt.mabstract then 0x0400 lor 0x0040 lor 0x0100 else 0)
    lor (if mt.moverride then 0x0040 else if mt.mvirtual then 0x0040 lor 0x0100 else 0)
    lor (if mt.implements && not mt.mvirtual then 0x0040 lor 0x0020 lor 0x0100 else 0)
    lor (if getter then 0x0800 else 0)

let program (name : string) (p : A.program) : string =
  Hashtbl.reset classes;
  usings := "System" :: List.map (String.concat ".") p.usings;
  let w = W.create name in
  let c = { Csc_emit.w; memo = Hashtbl.create 64 } in
  (* the classes, their TypeDefs' rows known before they are made (row
   * 1 is <Module>), so a class may name one declared after it *)
  let user = List.mapi (fun i (d : A.class_decl) ->
      if Hashtbl.mem classes d.cname then error d.cpos ("the class " ^ d.cname ^ " declared twice");
      let k = { name = d.cname; short = d.cname; kind = (if d.interface then K_interface else K_class);
                user = Some d; spec = None; parent = None; ifaces = []; fields = []; methods = [];
                token = M.token M.t_type_def (i + 2) } in
      Hashtbl.replace classes d.cname k;
      (k, d)) p.classes in
  (* their parents and interfaces *)
  List.iter (fun ((k : cls), (d : A.class_decl)) ->
      let bases = List.map (resolve d.cpos) d.bases in
      let is_iface t = match t with Class (x, _) -> x.kind = K_interface | _ -> false in
      if d.interface then k.ifaces <- bases
      else begin
        (match List.filter (fun t -> not (is_iface t)) bases with
         | [] -> k.parent <- Some Object
         | [ t ] -> k.parent <- Some t
         | _ -> error d.cpos (d.cname ^ ": two classes to derive from"));
        k.ifaces <- List.filter is_iface bases
      end) user;
  List.iter (fun ((k : cls), (d : A.class_decl)) ->
      let tflags = if d.interface then 0x00A1 else 0x00100001 lor (if has d.cmods A.Abstract then 0x80 else 0) in
      let ext = match k.parent with Some t -> Csc_emit.type_token c t | None -> 0 in
      let tok = W.type_def w "" k.name tflags ext in
      assert (tok = k.token);
      List.iter (fun i -> W.implements w k.token (Csc_emit.type_token c i)) k.ifaces) user;
  (* their members *)
  List.iter (fun ((k : cls), (d : A.class_decl)) ->
      let meth name mods ps ret body init =
        { mname = name; mowner = k; mstatic = has mods A.Static;
          mvirtual = d.interface || has mods A.Virtual || has mods A.Abstract || has mods A.Override;
          mabstract = d.interface || has mods A.Abstract; moverride = has mods A.Override;
          mparams = List.map (fun (t, _) -> resolve d.cpos t) ps; pnames = List.map snd ps;
          mret = ret; mgeneric = 0; body; init; mtoken = 0; implements = false } in
      List.iter (fun (mb : A.member) -> match mb with
          | A.Field (mods, t, vars, pos) ->
              let t = resolve pos t in
              List.iter (fun (n, init) ->
                  k.fields <- k.fields @ [ { fname = n; ftype = t; fstatic = has mods A.Static; fowner = k;
                                             finit = init; ftoken = 0 } ]) vars
          | A.Method (mods, t, n, ps, body, pos) ->
              k.methods <- k.methods @ [ meth n mods ps (resolve pos t) body None ]
          | A.Ctor (mods, _, ps, init, body, _) ->
              k.methods <- k.methods @ [ { (meth ".ctor" mods ps Void (Some body) init) with mvirtual = false } ]
          | A.Property (mods, t, n, body, pos) ->
              k.methods <- k.methods @ [ meth ("get_" ^ n) mods [] (resolve pos t) body None ]) d.members;
      if not d.interface && not (List.exists (fun m -> m.mname = ".ctor") k.methods) then
        k.methods <- k.methods @ [ meth ".ctor" [] [] Void None None ];
      if List.exists (fun f -> f.fstatic && f.finit <> None) k.fields then
        k.methods <- k.methods @ [ meth ".cctor" [ A.Static ] [] Void None None ]) user;
  (* a class's method that an interface of it asks: virtual, as .NET's
   * dispatch through an interface wants (C#'s "virtual final") *)
  List.iter (fun ((k : cls), _) ->
      let rec all_ifaces (k : cls) =
        k.ifaces @ List.concat_map (fun i -> match i with Class (x, _) -> all_ifaces x | _ -> []) k.ifaces
        @ (match k.parent with Some (Class (p, _)) when p.user <> None -> all_ifaces p | _ -> []) in
      List.iter (fun i -> match i with
          | Class (x, _) ->
              List.iter (fun (im : meth) ->
                  List.iter (fun (mt : meth) ->
                      if mt.mname = im.mname && not mt.mstatic && List.length mt.mparams = List.length im.mparams
                         && List.for_all2 same mt.mparams im.mparams then mt.implements <- true) k.methods)
                x.methods
          | _ -> ()) (all_ifaces k)) user;
  (* the rows *)
  List.iter (fun ((k : cls), _) ->
      List.iter (fun f ->
          f.ftoken <- W.field_def w k.token f.fname (0x0006 lor (if f.fstatic then 0x0010 else 0))
              (Csc_emit.sig_of c f.ftype)) k.fields;
      List.iter (fun mt ->
          let getter = String.length mt.mname > 4 && String.sub mt.mname 0 4 = "get_" in
          mt.mtoken <- W.method_def w k.token mt.mname (flags k mt getter) (Csc_emit.meth_sig c mt))
        k.methods) user;
  (* the bodies *)
  List.iter (fun ((k : cls), _) ->
      List.iter (fun mt ->
          if not mt.mabstract && (mt.body <> None || mt.mname = ".ctor" || mt.mname = ".cctor") then
            Csc_emit.body c k mt) k.methods) user;
  (* the entry point: a static Main *)
  (match List.concat_map (fun ((k : cls), _) ->
       List.filter (fun mt -> mt.mname = "Main" && mt.mstatic) k.methods) user with
   | [ mt ] -> W.set_entry_point w mt.mtoken
   | [] -> error 0 "no static Main"
   | _ -> error 0 "several static Main");
  W.write w
