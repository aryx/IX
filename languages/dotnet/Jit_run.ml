(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Jit_run.mli *)

open Value

let compiled = ref 0

(* the text read and encoded at 0: its bytes, and each TEXT's offset *)
let encode (caps : < Cap.open_in; .. >) (text : string) : string * (string -> int) =
  let obj = Parser_asm.parse caps Asm.Arm64 (Fpath.v "jit.s") text in
  let (t : Arm64.op Program.t) = Link.create Asm.Arm64 ~text_start:0 in
  Link.load_objects t ~decode:Arm64.decode [ obj ];
  Arm64.prepare t;
  Link.resolve t;
  Link.layout_data t;
  Link.drop_nops t;
  Arm64.rewrite t;
  Arm64.layout t;
  (Bytes.to_string (Arm64.encode t), fun name -> (Hashtbl.find t.syms (name, 0)).value)

(* ------------------------------------------------------------------ *)
(* The runtime's functions the code calls: static closures *)
(* ------------------------------------------------------------------ *)

let divide_by_zero () : unit = Frame.throw_new "System.DivideByZeroException" "Attempted to divide by zero."
let null_reference () : unit = Frame.null_ref ()
let out_of_range () : unit = Frame.out_of_range ()

(* the call-outs, by their numbers: each its operands to its result *)
let table : (Obj.t array -> Obj.t) array ref = ref [||]

let out0 (k : int) : Obj.t = (!table).(k) [||]
let out1 (k : int) (a : Obj.t) : Obj.t = (!table).(k) [| a |]
let out2 (k : int) (a : Obj.t) (b : Obj.t) : Obj.t = (!table).(k) [| a; b |]
let out3 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) : Obj.t = (!table).(k) [| a; b; c |]
let out4 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) (d : Obj.t) : Obj.t = (!table).(k) [| a; b; c; d |]
let out5 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) (d : Obj.t) (e : Obj.t) : Obj.t =
  (!table).(k) [| a; b; c; d; e |]
let out6 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) (d : Obj.t) (e : Obj.t) (f : Obj.t) : Obj.t =
  (!table).(k) [| a; b; c; d; e; f |]
let out7 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) (d : Obj.t) (e : Obj.t) (f : Obj.t) (g : Obj.t) : Obj.t =
  (!table).(k) [| a; b; c; d; e; f; g |]
let out8 (k : int) (a : Obj.t) (b : Obj.t) (c : Obj.t) (d : Obj.t) (e : Obj.t) (f : Obj.t) (g : Obj.t)
    (h : Obj.t) : Obj.t =
  (!table).(k) [| a; b; c; d; e; f; g; h |]

(* a value of the code's, of its kind, as the interpreter's, and back *)
let of_word (k : Jit.kind) (x : Obj.t) : value =
  match k with
  | Jit.I -> I4 (Int32.of_int (Obj.obj x : int))
  | Jit.R -> (Obj.obj x : value)

let to_word (k : Jit.kind) (v : value) : Obj.t =
  match k, v with
  | Jit.I, I4 n -> Obj.repr (Int32.to_int n)
  | Jit.I, _ -> Frame.error "the JIT's code: an int32 expected"
  | Jit.R, v -> Obj.repr v

(* ------------------------------------------------------------------ *)
(* An assembly's code *)
(* ------------------------------------------------------------------ *)

(* each assembly's methods compiled, by its name: a row's function *)
let programs : (string, (int, value array -> value) Hashtbl.t) Hashtbl.t = Hashtbl.create 4

let program (caps : < Cap.open_in; .. >) (im : image) : (int, value array -> value) Hashtbl.t =
  match Hashtbl.find_opt programs im.aname with
  | Some p -> p
  | None ->
      let p = Hashtbl.create 16 in
      Hashtbl.replace programs im.aname p;
      let addr f = Code_memory.address (Obj.repr f) in
      let throws = [ ("jit_divide_by_zero", addr divide_by_zero); ("jit_null", addr null_reference);
                     ("jit_range", addr out_of_range) ] in
      let out = [| addr out0; addr out1; addr out2; addr out3; addr out4; addr out5; addr out6;
                   addr out7; addr out8 |] in
      let text, entries, sites =
        Jit.program im ~base:(Array.length !table) ~throws ~out in
      if entries <> [] then begin
        let code, offset = encode caps text in
        let base = Code_memory.load code in
        (* the call-outs: the instruction run by the interpreter, in its
         * method's code (decoded now, before the bodies are Native) *)
        let calls = List.map (fun (s : Jit.site) ->
            let m = Types.meth_of_def im s.srow in
            let code = Types.code m in
            let kinds = Array.of_list s.sargs in
            let run = Machine.call_out m code s.sat in
            fun (a : Obj.t array) ->
              let v = run (Array.mapi (fun j x -> of_word kinds.(j) x) a) in
              match s.sret with Some k -> to_word k v | None -> Obj.repr ()) sites in
        table := Array.append !table (Array.of_list calls);
        compiled := !compiled + List.length entries;
        List.iter (fun (row, sym) ->
            let m = Types.meth_of_def im row in
            let ks = Array.of_list ((if m.static then [] else [ Jit.R ])
                                    @ List.map (fun t -> if is_ref t then Jit.R else Jit.I) m.params) in
            let ret = if is_ref m.ret then Jit.R else Jit.I in
            let (f : Obj.t array -> Obj.t) = Obj.obj (Code_memory.closure (base + offset sym)) in
            let call (args : value array) : value =
              let r = f (Array.mapi (fun j v -> to_word ks.(j) v) args) in
              if m.ret = T_void then Null else of_word ret r in
            Hashtbl.replace p row call;
            m.body <- Native call) entries
      end;
      p

let jit (caps : < Cap.open_in; .. >) (m : meth) : (value array -> value) option =
  match m.def with
  | Some (im, row) when Code_memory.available -> Hashtbl.find_opt (program caps im) row
  | _ -> None
