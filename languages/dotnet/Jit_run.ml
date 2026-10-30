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

(* each assembly's entries, by its name, made at its first method's
 * first call: a row's closure *)
let programs : (string, (int, Obj.t) Hashtbl.t) Hashtbl.t = Hashtbl.create 4

let program (caps : < Cap.open_in; .. >) (im : image) : (int, Obj.t) Hashtbl.t =
  match Hashtbl.find_opt programs im.aname with
  | Some p -> p
  | None ->
      let p = Hashtbl.create 16 in
      Hashtbl.replace programs im.aname p;
      let divide = Code_memory.address (Obj.repr Code_memory.divide_by_zero) in
      let text, entries = Jit.program im.img ~divide_by_zero:divide in
      if entries <> [] then begin
        let code, offset = encode caps text in
        let base = Code_memory.load code in
        compiled := !compiled + List.length entries;
        List.iter (fun (row, sym) -> Hashtbl.replace p row (Code_memory.closure (base + offset sym))) entries
      end;
      p

let jit (caps : < Cap.open_in; .. >) (m : meth) : (value array -> value) option =
  match m.def with
  | Some (im, row) when Code_memory.available ->
      (match Hashtbl.find_opt (program caps im) row with
       | None -> None
       | Some c ->
           let (f : int array -> int) = Obj.obj c in
           Some (fun (args : value array) ->
               let a = Array.map (fun (v : value) -> match v with
                   | I4 n -> Int32.to_int n
                   | _ -> Frame.error "the JIT's code: an argument not an int32") args in
               match f a with
               | n -> if m.ret = T_void then Null else I4 (Int32.of_int n)
               | exception Code_memory.Divide_by_zero ->
                   Frame.throw_new "System.DivideByZeroException" "Attempted to divide by zero."))
  | _ -> None
