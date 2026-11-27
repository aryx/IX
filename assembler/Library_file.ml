(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Library_file.mli *)

(* a name defined: in text or in data *)
type def_kind = T | D

(* the names an object defines, for the library's index: its TEXTs,
 * its GLOBLs and DATAs (ar's objsym, 'T' and 'D') *)
let defined_names (o : Asm.obj) =
  Array.to_list o.items |> List.filter_map (fun (it, _) ->
    match (it : Asm.item) with
    | Text (n, _, _) when not n.static -> Some (T, n.sym)
    | Data (n, _, _, _) | Globl (n, _, _) when not n.static -> Some (D, n.sym)
    | _ -> None)
  |> List.sort_uniq compare

(* In its file, a member is its object's source, its bytes (Asm's, as
 * its .5 or .7 is), read as a value when it is taken, and the names it
 * defines. mini-ar lists a library and puts objects in it without
 * reading any as a value, and mini-ld reads only those it takes.
 * old (3): the bytes and the index's names only: mini-ar t and u read
 * every member as a value for its source, and u wrote them all again;
 * lib_core.a by mini-ar u 49 s on the card, 123 MB on Linux
 * (plan_self_hosting.md). And before (2): the objects themselves, all
 * read with the library: linking mini-rm, 50 MB of the stdlib's 69
 * units for the 30 it uses *)
type member = string * string * (def_kind * string) list
type members = (string * string list) list

(* 2: its objects Asm's version 4; 3: a member its bytes; 4: and its
 * source and names; 5: its bytes the object's file's, version and all;
 * 6: the index first, a value of its own, then the members' bytes *)
let lib_version = 6

(* In its file, the version and the index, each member's source, names,
 * and its bytes' place after the index, a value read alone (mini-ar t,
 * mini-ml -start: Marshal_.first), then the bytes one after the other,
 * as they are, no value: mini-ld cuts the ones it takes out of the file.
 * old (5): one value, (version, members), read whole for a member's
 * name; lib.a.units beside it said them, made for that (mklib). Still
 * read: a library made before (first) *)
type entry = string * (def_kind * string) list * int * int

(* (No_sharing: as Asm.save) *)
let member_of (bytes : string) (o : Asm.obj) : member =
  (Fpath.to_string o.file, bytes, defined_names o)
let member_file ((file, _, _) : member) = file

(* the index, as ar: a text name defined again by a later object is
 * not indexed for it *)
let index (l : member list) : members =
  let texts = Hashtbl.create 256 in
  List.map (fun (_, bytes, defs) ->
    let names = List.filter_map (fun (k, n) ->
      if k = T && Hashtbl.mem texts n then None else (if k = T then Hashtbl.replace texts n (); Some n)) defs in
    (bytes, List.sort_uniq compare names)) l

(* the first value's members: version 6's index, or version 5's
 * members, bytes and all (a library made before, read whole) *)
type first = Index of entry list | Members of member list

let first (f : Fpath.t) (b : string) : first =
  if not (Asm.marshalled b) then failwith (Fpath.to_string f ^ ": not a library");
  match (Marshal.from_string b 0 : int * Obj.t) with
  | v, x when v = lib_version -> Index (Obj.obj x : entry list)
  | 5, x -> Members (Obj.obj x : member list)
  | _ -> failwith (Fpath.to_string f ^ ": a library of another version (to make again: remove it)")

let read_library caps f : member list =
  let b = FS.read caps f in
  match first f b with
  | Members l -> l
  | Index l ->
      let start = Marshal.total_size (Bytes.unsafe_of_string b) 0 in
      List.map (fun ((file, defs, pos, len) : entry) -> (file, String.sub b (start + pos) len, defs)) l

(* the members' sources alone, in their order *)
let read_sources caps f : string list =
  let b = try Marshal_.first caps (Fpath.to_string f) with End_of_file | Failure _ -> failwith (Fpath.to_string f ^ ": not a library") in
  match first f b with
  | Index l -> List.map (fun ((file, _, _, _) : entry) -> file) l
  | Members l -> List.map member_file l

let write_library caps out (l : member list) =
  let pos = ref 0 in
  let index = List.map (fun ((file, bytes, defs) : member) ->
    let e : entry = (file, defs, !pos, String.length bytes) in
    pos := !pos + String.length bytes; e) l in
  FS.write caps out (String.concat "" (Marshal_.to_string (lib_version, index) [] :: List.map (fun ((_, b, _) : member) -> b) l))

let read_members caps f = index (read_library caps f)
