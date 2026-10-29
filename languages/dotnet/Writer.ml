(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Writer.mli *)

module M = Metadata

type clause = {
  kind : int;
  try_start : int;
  try_end : int;
  handler_start : int;
  handler_end : int;
  catch : int;
}

(* a heap: its bytes, and what is in it already, to write each once *)
type heap = { bytes : Buffer.t; seen : (string, int) Hashtbl.t }

let new_heap (first : string) : heap =
  let h = { bytes = Buffer.create 256; seen = Hashtbl.create 64 } in
  Buffer.add_string h.bytes first;
  h

(* a field or a method defined: its owner, its row's columns but the
 * owner's ranges; its body *)
type fdef = { fowner : int; fname : string; fflags : int; fsig : string }
type mdef = {
  mowner : int; mname : string; mflags : int; msig : Signature.meth;
  mutable body : (Signature.t list * Il.op array * clause list) option;
}

type t = {
  name : string;
  strings : heap;
  user_strings : heap;
  blobs : heap;
  assembly_refs : (string, int) Hashtbl.t;
  mutable assembly_ref_rows : string list;           (* in order, reversed *)
  type_refs : (int * string * string, int) Hashtbl.t;
  mutable type_ref_rows : (int * string * string) list;
  member_refs : (int * string * string, int) Hashtbl.t;
  mutable member_ref_rows : (int * string * string) list;
  sigs : (int, int * bool) Hashtbl.t;               (* a method's token: its arguments, a result? *)
  type_specs : (string, int) Hashtbl.t;
  mutable type_spec_rows : string list;
  mutable type_defs : (int * string * string * int) list;   (* flags, namespace, name, extends; reversed *)
  mutable fields : fdef list;                        (* reversed, by provisional number - 1 *)
  mutable methods : mdef list;
  mutable nested : (int * int) list;
  mutable impls : (int * int) list;
  mutable stand_alone : string list;
  mutable entry : int;
}

let create (name : string) : t =
  let w = { name; strings = new_heap "\000"; user_strings = new_heap "\000";
            blobs = new_heap "\000"; assembly_refs = Hashtbl.create 4;
            assembly_ref_rows = []; type_refs = Hashtbl.create 16; type_ref_rows = [];
            member_refs = Hashtbl.create 16; member_ref_rows = [];
            sigs = Hashtbl.create 16; type_specs = Hashtbl.create 8; type_spec_rows = [];
            type_defs = []; fields = []; methods = []; nested = []; impls = []; stand_alone = [];
            entry = 0 } in
  (* the first TypeDef, <Module>: what is global *)
  w.type_defs <- [ (0, "", "<Module>", 0) ];
  w

(* ------------------------------------------------------------------ *)
(* The heaps *)
(* ------------------------------------------------------------------ *)

let add_heap (h : heap) (key : string) (bytes : string) : int =
  match Hashtbl.find_opt h.seen key with
  | Some i -> i
  | None ->
      let i = Buffer.length h.bytes in
      Buffer.add_string h.bytes bytes;
      Hashtbl.replace h.seen key i;
      i

let str (w : t) (s : string) : int =
  if s = "" then 0 else add_heap w.strings s (s ^ "\000")

let blob (w : t) (s : string) : int =
  let b = Buffer.create (String.length s + 2) in
  Signature.add_number b (String.length s);
  Buffer.add_string b s;
  add_heap w.blobs s (Buffer.contents b)

(* #US: UTF-16, its length in bytes and one more, the last byte 1 if
 * a character needs more than a simple comparison (II.24.2.4) *)
let user_string (w : t) (s : string) : int =
  let b = Buffer.create (2 * String.length s + 3) in
  let n = String.length s in
  Signature.add_number b (2 * n + 1);
  let special = ref 0 in
  String.iter (fun c ->
      let k = Char.code c in
      if k >= 0x80 || (k >= 1 && k <= 8) || (k >= 0x0E && k <= 0x1F) || k = 0x27 || k = 0x2D || k = 0x7F
      then special := 1;
      Buffer.add_char b c; Buffer.add_char b '\000') s;
  Buffer.add_char b (Char.chr !special);
  M.token M.t_user_string (add_heap w.user_strings s (Buffer.contents b))

(* ------------------------------------------------------------------ *)
(* What is used, what is defined *)
(* ------------------------------------------------------------------ *)

let assembly_ref (w : t) (name : string) : int =
  match Hashtbl.find_opt w.assembly_refs name with
  | Some t -> t
  | None ->
      w.assembly_ref_rows <- name :: w.assembly_ref_rows;
      let t = M.token M.t_assembly_ref (List.length w.assembly_ref_rows) in
      Hashtbl.replace w.assembly_refs name t;
      t

let type_ref (w : t) (scope : int) (ns : string) (name : string) : int =
  let k = (scope, ns, name) in
  match Hashtbl.find_opt w.type_refs k with
  | Some t -> t
  | None ->
      w.type_ref_rows <- k :: w.type_ref_rows;
      let t = M.token M.t_type_ref (List.length w.type_ref_rows) in
      Hashtbl.replace w.type_refs k t;
      t

let args_of (m : Signature.meth) : int * bool =
  (List.length m.params + (if m.has_this then 1 else 0), m.ret <> Signature.Void)

let member (w : t) (parent : int) (name : string) (sg : string) : int =
  let k = (parent, name, sg) in
  match Hashtbl.find_opt w.member_refs k with
  | Some t -> t
  | None ->
      w.member_ref_rows <- k :: w.member_ref_rows;
      let t = M.token M.t_member_ref (List.length w.member_ref_rows) in
      Hashtbl.replace w.member_refs k t;
      t

let member_ref (w : t) (parent : int) (name : string) (m : Signature.meth) : int =
  let t = member w parent name (Signature.encode_method m) in
  Hashtbl.replace w.sigs t (args_of m);
  t

let field_ref (w : t) (parent : int) (name : string) (ty : Signature.t) : int =
  member w parent name (Signature.encode_field ty)

let type_spec (w : t) (ty : Signature.t) : int =
  let sg = Signature.encode_type_spec ty in
  match Hashtbl.find_opt w.type_specs sg with
  | Some t -> t
  | None ->
      w.type_spec_rows <- sg :: w.type_spec_rows;
      let t = M.token M.t_type_spec (List.length w.type_spec_rows) in
      Hashtbl.replace w.type_specs sg t;
      t

let type_def (w : t) (ns : string) (name : string) (flags : int) (extends : int) : int =
  w.type_defs <- (flags, ns, name, extends) :: w.type_defs;
  M.token M.t_type_def (List.length w.type_defs)

(* (provisional: the n-th field or method defined, renumbered by write) *)
let field_def (w : t) (owner : int) (name : string) (flags : int) (ty : Signature.t) : int =
  w.fields <- { fowner = M.token_row owner; fname = name; fflags = flags;
                fsig = Signature.encode_field ty } :: w.fields;
  M.token M.t_field (List.length w.fields)

let method_def (w : t) (owner : int) (name : string) (flags : int) (m : Signature.meth) : int =
  w.methods <- { mowner = M.token_row owner; mname = name; mflags = flags; msig = m; body = None }
               :: w.methods;
  let t = M.token M.t_method_def (List.length w.methods) in
  Hashtbl.replace w.sigs t (args_of m);
  t

let nest (w : t) (inner : int) (outer : int) : unit =
  w.nested <- (M.token_row inner, M.token_row outer) :: w.nested

let implements (w : t) (cls : int) (iface : int) : unit =
  w.impls <- (M.token_row cls, iface) :: w.impls

let set_body (w : t) (tok : int) (locals : Signature.t list) (code : Il.op array) (clauses : clause list) : unit =
  let n = List.length w.methods in
  let m = List.nth w.methods (n - M.token_row tok) in
  m.body <- Some (locals, code, clauses)

let set_entry_point (w : t) (tok : int) : unit = w.entry <- tok

(* ------------------------------------------------------------------ *)
(* A method's body *)
(* ------------------------------------------------------------------ *)

(* the deepest the stack goes: each instruction's depth from the ones
 * that lead to it (the next, a branch's target; a handler's start: the
 * exception, or nothing for a finally) *)
let max_stack (w : t) (returns : bool) (code : Il.op array) (clauses : clause list) : int =
  let n = Array.length code in
  let depth = Array.make (n + 1) (-1) in
  let work = ref [ 0 ] in
  depth.(0) <- 0;
  List.iter (fun c ->
      depth.(c.handler_start) <- (if c.kind = 0 then 1 else 0);
      work := c.handler_start :: !work) clauses;
  let most = ref 0 in
  let call t = match Hashtbl.find_opt w.sigs t with
    | Some s -> s
    | None -> failwith (Printf.sprintf "Writer: a call to 0x%08x, not made by this writer" t) in
  let reach i d = if i <= n && depth.(i) < 0 then (depth.(i) <- d; work := i :: !work) in
  while !work <> [] do
    let i = List.hd !work in
    work := List.tl !work;
    if i < n then begin
      let op = code.(i) in
      let pops, pushes = Il.stack_effect call returns op in
      let d = depth.(i) - pops + pushes in
      if depth.(i) - pops < 0 then
        failwith (Printf.sprintf "Writer: the stack empty at instruction %d" i);
      if d > !most then most := d;
      if depth.(i) > !most then most := depth.(i);
      (match op with
       | Il.Br t -> reach t d
       | Il.Leave t -> reach t 0
       | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) -> reach t d; reach (i + 1) d
       | Il.Switch ts -> Array.iter (fun t -> reach t d) ts; reach (i + 1) d
       | Il.Ret | Il.Throw | Il.Rethrow | Il.Endfinally -> ()
       | _ -> reach (i + 1) d)
    end
  done;
  !most

(* II.25.4: the body's header, its IL, its clauses; the IL's tokens
 * renumbered *)
let body_bytes (w : t) (remap : int -> int) (locals_tok : int) (m : mdef)
    (code : Il.op array) (clauses : clause list) : string =
  (* (its depth from the tokens as they were made: the calls' signatures
   * are known by those) *)
  let stack = max_stack w (m.msig.ret <> Signature.Void) code clauses in
  let code = Array.map (Il.map_tokens remap) code in
  (* the instructions' offsets: each one's size, a branch in its long
   * form whatever its target *)
  let n = Array.length code in
  let offsets = Array.make (n + 1) 0 in
  let tmp = Buffer.create 16 in
  for i = 0 to n - 1 do
    Buffer.clear tmp;
    let sized = match code.(i) with
      | Il.Br _ -> Il.Br 0 | Il.Brfalse _ -> Il.Brfalse 0 | Il.Brtrue _ -> Il.Brtrue 0
      | Il.Bcmp (c, u, _) -> Il.Bcmp (c, u, 0) | Il.Leave _ -> Il.Leave 0
      | op -> op in
    Il.encode tmp sized;
    offsets.(i + 1) <- offsets.(i) + Buffer.length tmp
  done;
  let il = Buffer.create offsets.(n) in
  let at i = offsets.(i) in
  Array.iter (fun op ->
      Il.encode il (match op with
          | Il.Br t -> Il.Br (at t) | Il.Brfalse t -> Il.Brfalse (at t)
          | Il.Brtrue t -> Il.Brtrue (at t) | Il.Bcmp (c, u, t) -> Il.Bcmp (c, u, at t)
          | Il.Leave t -> Il.Leave (at t) | Il.Switch ts -> Il.Switch (Array.map at ts)
          | op -> op)) code;
  let il = Buffer.contents il in
  let b = Buffer.create (String.length il + 32) in
  if String.length il < 64 && stack <= 8 && locals_tok = 0 && clauses = [] then
    Buffer.add_char b (Char.chr ((String.length il lsl 2) lor 2))
  else begin
    let flags = 0x3003 lor (if clauses <> [] then 0x08 else 0) lor (if locals_tok <> 0 then 0x10 else 0) in
    Buffer.add_uint16_le b flags;
    Buffer.add_uint16_le b stack;
    Buffer.add_int32_le b (Int32.of_int (String.length il));
    Buffer.add_int32_le b (Int32.of_int locals_tok)
  end;
  Buffer.add_string b il;
  if clauses <> [] then begin
    while Buffer.length b mod 4 <> 0 do Buffer.add_char b '\000' done;
    (* a fat section: 24 bytes a clause *)
    let size = 4 + 24 * List.length clauses in
    Buffer.add_char b '\x41';
    Buffer.add_char b (Char.chr (size land 0xFF));
    Buffer.add_char b (Char.chr ((size lsr 8) land 0xFF));
    Buffer.add_char b (Char.chr ((size lsr 16) land 0xFF));
    let i32 x = Buffer.add_int32_le b (Int32.of_int x) in
    List.iter (fun c ->
        i32 c.kind; i32 (at c.try_start); i32 (at c.try_end - at c.try_start);
        i32 (at c.handler_start); i32 (at c.handler_end - at c.handler_start);
        i32 (if c.kind = 0 then remap c.catch else 0)) clauses
  end;
  Buffer.contents b

(* ------------------------------------------------------------------ *)
(* The file *)
(* ------------------------------------------------------------------ *)

let pad4 (b : Buffer.t) : unit = while Buffer.length b mod 4 <> 0 do Buffer.add_char b '\000' done

let runtime_config =
  "{\"runtimeOptions\":{\"tfm\":\"net8.0\",\"framework\":{\"name\":\"Microsoft.NETCore.App\",\"version\":\"8.0.0\"}}}\n"

(* where .text starts in memory and in the file *)
let text_rva = 0x2000
let text_file = 0x200

let write (w : t) : string =
  (* the fields and methods by their owner, in the order defined: their
   * rows; a provisional token to its row's *)
  let fields = Array.of_list (List.rev w.fields) in
  let methods = Array.of_list (List.rev w.methods) in
  let order owner a : int array =
    let idx = Array.init (Array.length a) (fun i -> i) in
    let l = List.stable_sort (fun i j -> compare (owner a.(i)) (owner a.(j))) (Array.to_list idx) in
    Array.of_list l in
  let forder = order (fun f -> f.fowner) fields in
  let morder = order (fun m -> m.mowner) methods in
  let frow = Array.make (Array.length fields) 0 and mrow = Array.make (Array.length methods) 0 in
  Array.iteri (fun row i -> frow.(i) <- row + 1) forder;
  Array.iteri (fun row i -> mrow.(i) <- row + 1) morder;
  let remap (tok : int) : int =
    match M.token_table tok with
    | t when t = M.t_field -> M.token t frow.(M.token_row tok - 1)
    | t when t = M.t_method_def -> M.token t mrow.(M.token_row tok - 1)
    | _ -> tok in
  let type_defs = Array.of_list (List.rev w.type_defs) in
  (* the bodies, after the CLI header, each on 4 bytes *)
  let text = Buffer.create 4096 in
  Buffer.add_string text (String.make 72 '\000');         (* the CLI header, written last *)
  let rvas = Array.make (Array.length methods) 0 in
  Array.iteri (fun i m ->
      match m.body with
      | None -> ()
      | Some (locals, code, clauses) ->
          let ltok =
            if locals = [] then 0
            else begin
              w.stand_alone <- Signature.encode_locals locals :: w.stand_alone;
              M.token M.t_stand_alone_sig (List.length w.stand_alone)
            end in
          pad4 text;
          rvas.(i) <- text_rva + Buffer.length text;
          Buffer.add_string text (body_bytes w remap ltok m code clauses)) methods;
  pad4 text;
  (* the tables' rows, as columns of ints *)
  let rows = Array.make M.count [] in
  let add t r = rows.(t) <- r :: rows.(t) in
  add M.t_module [| 0; str w (w.name ^ ".dll"); 1; 0; 0 |];
  List.iter (fun (scope, ns, name) ->
      let st, sr = (M.token_table scope, M.token_row scope) in
      let tag = if st = M.t_assembly_ref then 2 else if st = M.t_type_ref then 3 else 0 in
      add M.t_type_ref [| (sr lsl 2) lor tag; str w name; str w ns |]) (List.rev w.type_ref_rows);
  (* (a type's first field and method: the first row whose owner is it
   * or after it) *)
  let first (owners : int array) (n : int) (row : int) =
    let rec go i = if i >= n || owners.(i) >= row then i + 1 else go (i + 1) in
    go 0 in
  let fowners = Array.map (fun i -> fields.(i).fowner) forder in
  let mowners = Array.map (fun i -> methods.(i).mowner) morder in
  Array.iteri (fun i (flags, ns, name, extends) ->
      let ext = if extends = 0 then 0 else
          let tag = match M.token_table extends with
            | t when t = M.t_type_def -> 0 | t when t = M.t_type_ref -> 1 | _ -> 2 in
          (M.token_row extends lsl 2) lor tag in
      add M.t_type_def [| flags; str w name; str w ns; ext;
                          first fowners (Array.length fowners) (i + 1);
                          first mowners (Array.length mowners) (i + 1) |]) type_defs;
  Array.iter (fun i -> let f = fields.(i) in
               add M.t_field [| f.fflags; str w f.fname; blob w f.fsig |]) forder;
  Array.iter (fun i -> let m = methods.(i) in
               add M.t_method_def [| rvas.(i); 0; m.mflags; str w m.mname;
                                     blob w (Signature.encode_method m.msig); 1 |]) morder;
  List.iter (fun (parent, name, sg) ->
      let tag = match M.token_table parent with
        | t when t = M.t_type_def -> 0 | t when t = M.t_type_ref -> 1
        | t when t = M.t_method_def -> 3 | _ -> 4 in
      add M.t_member_ref [| (M.token_row parent lsl 3) lor tag; str w name; blob w sg |])
    (List.rev w.member_ref_rows);
  List.iter (fun sg -> add M.t_stand_alone_sig [| blob w sg |]) (List.rev w.stand_alone);
  List.iter (fun sg -> add M.t_type_spec [| blob w sg |]) (List.rev w.type_spec_rows);
  add M.t_assembly [| 0x8004; 0; 0; 0; 0; 0; 0; str w w.name; 0 |];
  (* Microsoft's key's token, for its assemblies *)
  let key = blob w "\xb0\x3f\x5f\x7f\x11\xd5\x0a\x3a" in
  List.iter (fun name -> add M.t_assembly_ref [| 8; 0; 0; 0; 0; key; str w name; 0; 0 |])
    (List.rev w.assembly_ref_rows);
  (* (InterfaceImpl sorted by its class, as ECMA asks) *)
  List.iter (fun (cls, iface) ->
      let tag = match M.token_table iface with
        | t when t = M.t_type_def -> 0 | t when t = M.t_type_ref -> 1 | _ -> 2 in
      add M.t_interface_impl [| cls; (M.token_row iface lsl 2) lor tag |])
    (List.stable_sort (fun (a, _) (b, _) -> compare a b) (List.rev w.impls));
  List.iter (fun (inner, outer) -> add M.t_nested_class [| inner; outer |])
    (List.sort compare w.nested);
  let rows = Array.map (fun l -> Array.of_list (List.rev l)) rows in
  (* the indexes' sizes, as the reader computes them *)
  let counts = Array.map Array.length rows in
  let big_heap h = Buffer.length h.bytes >= 0x10000 in
  let heaps = (if big_heap w.strings then 1 else 0) lor (if big_heap w.blobs then 4 else 0) in
  let size (k : M.column) = match k with
    | U8 | U16 -> 2
    | U32 -> 4
    | String -> if heaps land 1 <> 0 then 4 else 2
    | Guid -> 2
    | Blob -> if heaps land 4 <> 0 then 4 else 2
    | Table t -> if counts.(t) < 0x10000 then 2 else 4
    | Coded c ->
        let most = Array.fold_left (fun m t -> if t < 0 then m else max m counts.(t)) 0 c.tables in
        if most < 1 lsl (16 - c.bits) then 2 else 4 in
  let tables = Buffer.create 1024 in
  Buffer.add_int32_le tables 0l;
  Buffer.add_char tables '\002'; Buffer.add_char tables '\000';
  Buffer.add_char tables (Char.chr heaps); Buffer.add_char tables '\001';
  let valid = ref 0L in
  Array.iteri (fun t n -> if n > 0 then valid := Int64.logor !valid (Int64.shift_left 1L t)) counts;
  Buffer.add_int64_le tables !valid;
  (* (sorted: NestedClass among those ECMA asks to be, Roslyn's mask) *)
  Buffer.add_int64_le tables 0x000016003301FA00L;
  Array.iter (fun n -> if n > 0 then Buffer.add_int32_le tables (Int32.of_int n)) counts;
  Array.iteri (fun t rs ->
      let cols = M.columns t in
      Array.iter (fun r ->
          Array.iteri (fun i (_, k) ->
              if size k = 2 then Buffer.add_uint16_le tables r.(i)
              else Buffer.add_int32_le tables (Int32.of_int r.(i))) cols) rs) rows;
  pad4 tables;
  (* the metadata: its root, its five streams *)
  let guid = Digest.string w.name in
  let pad h = let b = h.bytes in while Buffer.length b mod 4 <> 0 do Buffer.add_char b '\000' done; Buffer.contents b in
  let streams = [ "#~", Buffer.contents tables; "#Strings", pad w.strings;
                  "#US", pad w.user_strings; "#GUID", guid; "#Blob", pad w.blobs ] in
  let md = Buffer.create 4096 in
  Buffer.add_int32_le md 0x424A5342l;
  Buffer.add_uint16_le md 1; Buffer.add_uint16_le md 1;
  Buffer.add_int32_le md 0l;
  Buffer.add_int32_le md 12l;
  Buffer.add_string md "v4.0.30319\000\000";
  Buffer.add_uint16_le md 0;
  Buffer.add_uint16_le md (List.length streams);
  let header_size = Buffer.length md + List.fold_left (fun a (n, _) ->
      a + 8 + ((String.length n + 4) land (lnot 3))) 0 streams in
  let off = ref header_size in
  List.iter (fun (n, data) ->
      Buffer.add_int32_le md (Int32.of_int !off);
      Buffer.add_int32_le md (Int32.of_int (String.length data));
      Buffer.add_string md n;
      Buffer.add_string md (String.make (((String.length n + 4) land (lnot 3)) - String.length n) '\000');
      off := !off + String.length data) streams;
  List.iter (fun (_, data) -> Buffer.add_string md data) streams;
  let md_rva = text_rva + Buffer.length text in
  Buffer.add_buffer text md;
  (* the CLI header *)
  let cli = Buffer.create 72 in
  Buffer.add_int32_le cli 72l;
  Buffer.add_uint16_le cli 2; Buffer.add_uint16_le cli 5;
  Buffer.add_int32_le cli (Int32.of_int md_rva);
  Buffer.add_int32_le cli (Int32.of_int (Buffer.length md));
  Buffer.add_int32_le cli 1l;                                   (* IL only *)
  Buffer.add_int32_le cli (Int32.of_int (remap w.entry));
  Buffer.add_string cli (String.make 48 '\000');
  let text = Buffer.contents text in
  let text = Buffer.contents cli ^ String.sub text 72 (String.length text - 72) in
  (* the PE around it: a DOS header, the PE's and one section *)
  let raw = (String.length text + 0x1FF) land (lnot 0x1FF) in
  let vsize = String.length text in
  let image_size = (text_rva + vsize + 0x1FFF) land (lnot 0x1FFF) in
  let pe = Buffer.create (text_file + raw) in
  let u16 x = Buffer.add_uint16_le pe x and u32 x = Buffer.add_int32_le pe (Int32.of_int x) in
  Buffer.add_string pe "MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00\xb8";
  Buffer.add_string pe (String.make (0x3C - Buffer.length pe) '\000');
  u32 0x80;
  Buffer.add_string pe "\x0e\x1f\xba\x0e\x00\xb4\x09\xcd\x21\xb8\x01\x4c\xcd\x21This program cannot be run in DOS mode.\r\r\n$";
  Buffer.add_string pe (String.make (0x80 - Buffer.length pe) '\000');
  Buffer.add_string pe "PE\000\000";
  u16 0x14c; u16 1; u32 0; u32 0; u32 0; u16 0xE0; u16 0x22;
  (* the optional header, PE32 *)
  u16 0x10b; Buffer.add_char pe '\048'; Buffer.add_char pe '\000';
  u32 raw; u32 0; u32 0; u32 0; u32 text_rva; u32 0;
  u32 0x400000; u32 0x2000; u32 0x200;
  u16 4; u16 0; u16 0; u16 0; u16 4; u16 0; u32 0;
  u32 image_size; u32 text_file; u32 0; u16 3; u16 0x8540;
  u32 0x100000; u32 0x1000; u32 0x100000; u32 0x1000; u32 0; u32 16;
  for d = 0 to 15 do
    if d = 14 then (u32 text_rva; u32 72) else (u32 0; u32 0)
  done;
  (* the section *)
  Buffer.add_string pe ".text\000\000\000";
  u32 vsize; u32 text_rva; u32 raw; u32 text_file; u32 0; u32 0; u16 0; u16 0;
  u32 0x60000020;
  Buffer.add_string pe (String.make (text_file - Buffer.length pe) '\000');
  Buffer.add_string pe text;
  Buffer.add_string pe (String.make (raw - String.length text) '\000');
  Buffer.contents pe
