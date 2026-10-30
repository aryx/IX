(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Jit_run.mli *)

open Value

let compiled = ref 0

(* the machine: arm64's on 64 bits, arm's on 32 (the Pi 1's) *)
let mach = if Sys.word_size = 64 then Jit.Arm64 else Jit.Arm

(* the text read and encoded at 0: its bytes, and each TEXT's offset *)
let encode_arm (caps : < Cap.open_in; .. >) (text : string) : string * (string -> int) =
  let obj = Parser_asm.parse caps Asm.Arm (Fpath.v "jit.s") text in
  let (t : Arm.op Program.t) = Link.create Asm.Arm ~text_start:0 in
  Link.load_objects t ~decode:Arm.decode [ obj ];
  Arm.prepare t;
  Link.resolve t;
  Link.layout_data t;
  Link.drop_nops t;
  Arm.rewrite t;
  Arm.layout t;
  (Bytes.to_string (Arm.encode t), fun name -> (Hashtbl.find t.syms (name, 0)).value)

let encode (caps : < Cap.open_in; .. >) (text : string) : string * (string -> int) =
  if mach = Jit.Arm then encode_arm caps text else
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
let stack_overflow () : unit = raise Frame.Stack_overflow

(* the machine's stack's limit for the code, in words (0: not known
 * yet): 4 MB below where the first program was made (Linux's 8), 512 KB
 * on 32 bits (mini-5i's Plan 9 stack is 1 MB, mini-9pi's 8) *)
let limit = ref 0

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

(* an int32 past an int's 31 bits (arm), from its halves *)
let box (hi : int) (lo : int) : Obj.t = Obj.repr (Int32.logor (Int32.shift_left (Int32.of_int hi) 16) (Int32.of_int lo))

(* a value of the code's, of its kind, as the interpreter's, and back *)
(* (an int32 a tagged int, or on arm past 31 bits its Int32 block) *)
let of_word (k : Jit.kind) (x : Obj.t) : value =
  match k with
  | Jit.I -> if Obj.is_int x then I4 (Int32.of_int (Obj.obj x : int)) else I4 (Obj.obj x : int32)
  | Jit.R -> (Obj.obj x : value)

let to_word (k : Jit.kind) (v : value) : Obj.t =
  match k, v with
  | Jit.I, I4 n -> let i = Int32.to_int n in if Int32.of_int i = n then Obj.repr i else Obj.repr n
  | Jit.I, _ -> Frame.error "the JIT's code: an int32 expected"
  | Jit.R, v -> Obj.repr v

(* ------------------------------------------------------------------ *)
(* An assembly's code *)
(* ------------------------------------------------------------------ *)

(* the methods waiting for their first call, by their numbers: each
 * compiled when its stub calls compile *)
let pending : (unit -> unit) array ref = ref [||]

let compile (k : int) : unit = (!pending).(k) ()

(* the call-outs of a method's code: the instruction run by the
 * interpreter, in the method's code *)
let call_outs (codes : (int, meth * code) Hashtbl.t) (sites : Jit.site list) : unit =
  let calls = List.map (fun (s : Jit.site) ->
      let m, code = Hashtbl.find codes s.srow in
      let kinds = Array.of_list s.sargs and form = Array.of_list s.sform in
      let run = Machine.call_out m code s.sat in
      let result v = match s.sret with Some k -> to_word k v | None -> Obj.repr () in
      let operand j x = match form.(j) with
        | Jit.Made k -> Machine.exec m code k [||]
        | _ -> of_word kinds.(j) x in
      if not (List.mem Jit.Addr s.sform) then
        fun (a : Obj.t array) -> result (run (Array.mapi operand a))
      else
        (* a local's address: an interpreter's cell with its value, its
         * new value given back after the result *)
        fun (a : Obj.t array) ->
          let cells = Array.map (fun x -> [| x |]) (Array.mapi operand a) in
          let v = run (Array.mapi (fun j (c : value array) -> if form.(j) = Jit.Addr then Ptr (Slot (c, 0)) else c.(0)) cells) in
          let back = List.filter (fun j -> form.(j) = Jit.Addr) (List.init (Array.length a) (fun j -> j)) in
          Obj.repr (Array.of_list (result v :: List.map (fun j -> to_word kinds.(j) cells.(j).(0)) back))) sites in
  table := Array.append !table (Array.of_list calls)

(* the runtime's text, in each piece of code *)
let runtime () : string =
  let addr f = Code_memory.address (Obj.repr f) in
  Jit.runtime ~mach ~box:(addr box)
    ~throws:[ ("jit_divide_by_zero", addr divide_by_zero); ("jit_null", addr null_reference);
              ("jit_range", addr out_of_range); ("jit_overflow", addr stack_overflow) ]
    ~out:[| addr out0; addr out1; addr out2; addr out3; addr out4; addr out5; addr out6; addr out7 |]
    ~compile:(addr compile)

(* the stack's limit, once: below the stack pointer of now *)
let ensure_limit (caps : < Cap.open_in; .. >) : unit =
  if !limit = 0 then begin
    let code, offset = encode caps (Jit.sp_code mach) in
    let (sp : unit -> int) = Obj.obj (Code_memory.closure (Code_memory.load code + offset "jit_sp")) in
    limit := sp () - (if Sys.word_size = 64 then 4 * 1024 * 1024 else 512 * 1024) / 4
  end

(* a method's function for the interpreter: its arguments as words
 * (`this` first), its entry at [addr] called, its result back *)
let native (m : meth) (addr : int) : value array -> value =
  let ks = Array.of_list ((if m.static then [] else [ Jit.R ])
                          @ List.map (fun t -> if is_ref t then Jit.R else Jit.I) m.params) in
  let ret = if is_ref m.ret then Jit.R else Jit.I in
  let (f : Obj.t array -> Obj.t) = Obj.obj (Code_memory.closure addr) in
  fun (args : value array) ->
    let r = f (Array.mapi (fun j v -> to_word ks.(j) v) args) in
    if m.ret = T_void then Null else of_word ret r

(* each assembly's methods, by its name: a row's function *)
let programs : (string, (int, value array -> value) Hashtbl.t) Hashtbl.t = Hashtbl.create 4

let program (caps : < Cap.open_in; .. >) (im : image) : (int, value array -> value) Hashtbl.t =
  match Hashtbl.find_opt programs im.aname with
  | Some p -> p
  | None ->
      let p = Hashtbl.create 16 in
      Hashtbl.replace programs im.aname p;
      let prep = Jit.prepare mach im in
      let rows = Jit.rows prep in
      let name row = Listing.token_name im.img (Metadata.token Metadata.t_method_def row) in
      Logs.info (fun m -> m "JIT: %s: %d methods taken, %d not" im.aname (List.length rows) (List.length (Jit.refused prep)));
      List.iter (fun (row, why) -> Logs.debug (fun m -> m "JIT: not compiled: %s: %s" (name row) why)) (Jit.refused prep);
      if rows <> [] then begin
        let runtime = runtime () in
        ensure_limit caps;
        let index = Hashtbl.create 16 in
        List.iteri (fun i row -> Hashtbl.replace index row i) rows;
        let cells, set = Code_memory.cells (Array.make (List.length rows) 0) in
        let cell row = cells + (Sys.word_size / 8) * Hashtbl.find index row in
        let k0 = Array.length !pending in
        let text, entries, stubs = Jit.stubs prep ~cell ~number:(fun row -> k0 + Hashtbl.find index row) ~runtime in
        let code, offset = encode caps text in
        let base = Code_memory.load code in
        List.iter (fun (row, sym) -> set (Hashtbl.find index row) (base + offset sym)) stubs;
        (* each method's IL decoded now, before its body is Native: its
         * call-outs' *)
        let codes = Hashtbl.create 16 in
        List.iter (fun row -> let m = Types.meth_of_def im row in Hashtbl.replace codes row (m, Types.code m)) rows;
        pending := Array.append !pending (Array.of_list (List.map (fun row () ->
            let text, sites = Jit.method_code prep row ~cell ~base:(Array.length !table) ~limit:!limit ~runtime in
            let code, offset = encode caps text in
            let at = Code_memory.load code in
            Logs.info (fun m -> m "JIT: compiled %s (%d bytes, %d call-outs)" (name row) (String.length code) (List.length sites));
            Logs.debug (fun m -> m "JIT: %s's code at 0x%x" (name row) at);
            call_outs codes sites;
            incr compiled;
            set (Hashtbl.find index row) (at + offset (Jit.symbol_of prep row))) rows));
        List.iter (fun (row, sym) ->
            let m, _ = Hashtbl.find codes row in
            let call = native m (base + offset sym) in
            Hashtbl.replace p row call;
            m.body <- Native call) entries
      end;
      p

(* an instance of a generic method, compiled at its first call
 * (Jit.instance_code), its code its own *)
let instance (caps : < Cap.open_in; .. >) (m : meth) (row : int) : (value array -> value) option =
  ensure_limit caps;
  let code = Types.code m in
  let name = m.mcls.name ^ "::" ^ m.mname in
  match Jit.instance_code mach m ~base:(Array.length !table) ~limit:!limit ~runtime:(runtime ()) with
  | None -> Logs.debug (fun f -> f "JIT: instance not compiled: %s" name); None
  | Some (text, entry, sites) ->
      let bytes, offset = encode caps text in
      let at = Code_memory.load bytes in
      Logs.info (fun f -> f "JIT: compiled the instance %s (%d bytes, %d call-outs)" name (String.length bytes) (List.length sites));
      let codes = Hashtbl.create 1 in
      Hashtbl.replace codes row (m, code);
      call_outs codes sites;
      incr compiled;
      Some (native m (at + offset entry))

let jit (caps : < Cap.open_in; .. >) (m : meth) : (value array -> value) option =
  match m.def with
  | Some (im, row) when Code_memory.available ->
      if m.mcls.args <> [||] || m.margs <> [||] then instance caps m row
      else Hashtbl.find_opt (program caps im) row
  | _ -> None
