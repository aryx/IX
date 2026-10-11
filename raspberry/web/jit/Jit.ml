(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Jit.mli *)

open Arm32_isa
module U = Js_of_ocaml.Js.Unsafe
module Js = Js_of_ocaml.Js

(* a place run so many times after a jump is translated: 200, where a
 * boot under node is 13.7 s (16: 17.8 s, a block's making being a
 * quarter of a millisecond; 2000: 13.4) *)
let threshold = ref 200
(* a block's instructions at most; the instructions a block that
 * loops on itself runs before it gives the board's loop a look *)
let max_len = 64
let loop_limit = 1024

let compiled = ref 0
let reused = ref 0
let refused = ref 0
(* a kind of instruction left to the interpreter, to find a wrong
 * translation: reg (shifts by a register), pc (pc written by a
 * data-processing instruction or a load), mem (halves, signed bytes,
 * offsets shifted right) *)
(* (and to find a wrong block: no more than [most] made, the last one's
 * text printed) *)
let most = ref max_int
let made = ref 0
let without : string list ref = ref []
(* a block goes on through an unconditional jump or call *)
let follow = ref true
let has k = not (List.mem k !without)
let retexted = ref 0

(*****************************************************************************)
(* What the host's code stands on *)
(*****************************************************************************)

(* The translated code reads and writes the emulator's own values: under
 * js_of_ocaml a record and an array are an array of JavaScript's whose
 * first element is a tag, a bool is 0 or 1, an int is the 32 bits. So,
 * in a block's text:
 *   R[k + 1]   register k (the state's r)
 *   S[2..6]    the state's n, z, c, v and next
 *   TG, PG, RT the TLB's tags, pages and rights (Mmu32's), at i + 1
 *   U8, I32    the RAM's bytes, and the same as words
 * [fields] checks the state's five places before anything is run. *)
let f_n = 2 and f_z = 3 and f_c = 4 and f_v = 5 and f_next = 6

let fields (st : state) =
  let o = Obj.repr st in
  let int_at i : int = Obj.obj (Obj.field o (i - 1)) in
  let was = st.next in
  st.next <- 0x1234564;
  let ok_next = int_at f_next = 0x1234564 in
  st.next <- was;
  let flag get set i = let was = get () in set true; let a = int_at i = 1 in set false; let b = int_at i = 0 in set was; a && b in
  ok_next
  && flag (fun () -> st.n) (fun b -> st.n <- b) f_n && flag (fun () -> st.z) (fun b -> st.z <- b) f_z
  && flag (fun () -> st.c) (fun b -> st.c <- b) f_c && flag (fun () -> st.v) (fun b -> st.v <- b) f_v
  && Obj.field o 0 == Obj.repr st.r

(* The table of the blocks by where they start (the board's key: the pc,
 * and bit 0 in user mode), emptied by a number: a block is in it when
 * its slot has its key and the number of now, and the TLB has the
 * block's physical page for that address (so an emptied TLB, each
 * switch of process, costs a look at E.miss a page of code and not the
 * table). E.miss is asked for a key not in it. *)
let runtime = {|
  var SIZE = 65536, MASK = SIZE - 1;
  var TK = new Int32Array(SIZE), TN = new Int32Array(SIZE), TP = new Int32Array(SIZE), TF = new Array(SIZE), now = 1;
  var HK = new Int32Array(SIZE), HC = new Int32Array(SIZE);
  var TG = E.TG, PG = E.PG, RT = E.RT, S = E.S, W = E.W, tr = E.tr, slots = new Map();
  E.forget = function () { now++; slots.clear(); };
  // a block of a physical page (its slot kept by the page: E.written);
  // f null: no block is worth making there, the interpreter's
  E.install = function (key, f, page) {
    var s = (key >>> 2) & MASK; TK[s] = key; TN[s] = now; TF[s] = f; TP[s] = page;
    var l = slots.get(page); if (l === undefined) slots.set(page, [s]); else if (l.length < 4096) l.push(s);
  };
  E.written = function (page) {
    var l = slots.get(page);
    if (l !== undefined) { for (var k = 0; k < l.length; k++) if (TP[l[k]] === page) TN[l[k]] = 0; slots.delete(page); }
  };
  // Block after block while each one is there, up to CHAIN instructions:
  // nothing that interrupts can have changed between two of them (a
  // block that wrote a device, or that the interpreter ended, sets
  // W[3]: back to the board's loop). A block starts at key when its
  // slot says so, of now, and the TLB still gives its physical page for
  // the key's page (looked at when the page is not the last block's),
  // which the mode may read. W[0..2], for a block that raises: the
  // instructions of its turns done, its start, those of the blocks
  // before it.
  // A key not there: one that follows the last one not found is not a
  // place a block may start (E.miss says why); a slot that had this key
  // is asked of E.miss at once (its block is put back); another key is
  // counted, and asked when it came THRESHOLD times.
  var CHAIN = 1024, last = -1, cur = null;
  // the block running: where the instruction that raised is in it (by
  // its address + 8), and a block's first run, E.miss's
  E.at = function (pc8) { return cur === null ? 1 : (cur.pos[pc8] | 0); };
  E.first = function (f) { cur = f; W[0] = 0; W[2] = 0; return f(); };
  E.run = function (key) {
    var total = 0, user = key & 1, page = -1, phys = -1;
    W[3] = 0;
    for (;;) {
      var s = (key >>> 2) & MASK;
      if (TK[s] === key && TN[s] === now) {
        // (the last block's page: the same one of the memory too, a
        // slot may be another program's at the same address)
        var g = key >>> 12, ok = g === page && TP[s] === phys;
        if (!ok) {
          var i = (g & 1023) + 1;
          // (the TLB was emptied, a switch of process: the page's
          // translation asked again, here; an abort is E.miss's to find)
          if (TG[i] !== g) { try { tr(key & -4, 0); } catch (e) { } }
          ok = TG[i] === g && PG[i] === TP[s] && (RT[i] & (user ? 4 : 1)) !== 0;
        }
        if (ok) {
          var f = TF[s];
          if (f === null) { last = key; return total; }
          page = g; phys = TP[s];
          W[0] = 0; W[2] = total; cur = f;
          var ran = f();
          // (a block that stopped before its first instruction, the
          // interpreter's: when blocks are checked)
          if (ran === 0) { last = key; return total; }
          total += ran;
          if (W[3] !== 0 || total >= CHAIN) { last = -1; return total; }
          key = S[6] | user;
          continue;
        }
      }
      else {
        if (total !== 0) { last = -1; return total; }
        if (key === last + 4) { last = key; return 0; }
        last = key;
        if (HK[s] !== key) { HK[s] = key; HC[s] = 1; return 0; }
        if (++HC[s] < E.threshold) return 0;
        HC[s] = 0;
      }
      if (total !== 0) { last = -1; return total; }
      W[2] = 0;
      total = E.miss(key);
      last = total !== 0 ? -1 : key;
      return total;
    }
  };
  E.make = function (src) { return (new Function("E", src))(E); };
  // a block's memory accesses (Jit.ml: [inlined])
  var U8 = E.U8, I32 = E.I32, RAM = E.RAM, ld32 = E.ld32, ld16 = E.ld16, ld8 = E.ld8, st32 = E.st32, st16 = E.st16, st8 = E.st8;
  E.TR = function (a, need, w) { var g = a >>> 12, i = (g & 1023) + 1; return TG[i] === g && (RT[i] & need) ? PG[i] | (a & 4095) : tr(a, w); };
  E.L32 = function (p) { return (p >>> 0) < RAM && !(p & 3) ? I32[p >> 2] : ld32(p); };
  E.L16 = function (p) { return (p >>> 0) < RAM - 1 ? U8[p] | (U8[p + 1] << 8) : ld16(p); };
  E.L8 = function (p) { return (p >>> 0) < RAM ? U8[p] : ld8(p); };
  E.S32 = function (p, v) { if ((p >>> 0) < RAM && !(p & 3)) { I32[p >> 2] = v; return 0; } st32(p, v); return 1; };
  E.S16 = function (p, v) { if ((p >>> 0) < RAM - 1) { U8[p] = v; U8[p + 1] = v >> 8; return 0; } st16(p, v); return 1; };
  E.S8 = function (p, v) { if ((p >>> 0) < RAM) { U8[p] = v; return 0; } st8(p, v); return 1; };
|}

(* a block's text around its instructions: what it reads of E once, its
 * variables (a an address, p a physical one, x set by a store that was
 * not the RAM's: the block ends after that instruction) *)
let head =
  "var R=E.R,S=E.S,W=E.W,TG=E.TG,PG=E.PG,RT=E.RT,U8=E.U8,I32=E.I32,RAM=E.RAM,tr=E.tr,ld32=E.ld32,ld16=E.ld16,ld8=E.ld8,st32=E.st32,st16=E.st16,st8=E.st8,ex=E.ex,lg=E.lg,TR=E.TR,L32=E.L32,L16=E.L16,L8=E.L8,S32=E.S32,S16=E.S16,S8=E.S8;\n\
   var f=function(){var n=0,x=0,a,p,i,v,b,q,r,y,c,t0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11,t12,t13,t14,t15;\nL:for(;;){\n"

(*****************************************************************************)
(* An instruction's text *)
(*****************************************************************************)

let buf = Buffer.create 8192
let p fmt = Printf.bprintf buf fmt

(* the instructions the interpreter runs for a block ([ex]'s number) *)
let insts : (int * Arm32_isa.t) array ref = ref (Array.make 1024 (0, Undefined 0))
let insts_n = ref 0
(* (an instruction at an address has one number: a block made again has
 * the same text, and its code is found by it) *)
let kept : (int * Arm32_isa.t, int) Hashtbl.t = Hashtbl.create 1024
(* (the block being made has one) *)
let asked = ref false
let keep addr i =
  asked := true;
  match Hashtbl.find_opt kept (addr, i) with
  | Some g -> g
  | None ->
  Hashtbl.add kept (addr, i) !insts_n;
  if !insts_n = Array.length !insts then begin
    let a = Array.make (2 * !insts_n) (0, Undefined 0) in
    Array.blit !insts 0 a 0 !insts_n; insts := a
  end;
  !insts.(!insts_n) <- (addr, i);
  incr insts_n;
  !insts_n - 1

let cond_text = function
  | EQ -> "S[3]" | NE -> "!S[3]" | CS -> "S[4]" | CC -> "!S[4]" | MI -> "S[2]" | PL -> "!S[2]" | VS -> "S[5]" | VC -> "!S[5]"
  | HI -> "S[4]&&!S[3]" | LS -> "!S[4]||S[3]" | GE -> "S[2]===S[5]" | LT -> "S[2]!==S[5]"
  | GT -> "!S[3]&&S[2]===S[5]" | LE -> "S[3]||S[2]!==S[5]" | AL -> ""

(* a register read: pc is the instruction's address + 8 *)
let reg pc r = if r = 15 then Printf.sprintf "(%d)" (Bits.mask32 (pc + 8)) else Printf.sprintf "R[%d]" (r + 1)

(* the address in a through the TLB, in p: Mmu32.translate's first line,
 * else the emulator's own ([write]; [user]: the block's mode) *)
(* A block's memory accesses are calls of a few functions made once
 * ([runtime]: TR the TLB's line or the emulator's translation; L32, L16,
 * L8 the RAM's word, half, byte, or the emulator's load; S32, S16, S8
 * the store, 1 when it was not the RAM's): the browser inlines them
 * where a block is hot. ([inlined]: their text in each block instead,
 * as it was. A block then had a call it almost never makes at each
 * access, the emulator's on a TLB's miss or a device, and the browser,
 * which compiles a block before that call was ever made, threw its
 * code away the first time each was: 852 of 1,046 such
 * deoptimizations under node for rio and cameltry, "insufficient type
 * feedback for call", and Chrome still compiling a minute into a
 * game.) *)
let inlined = ref false

let translate ~user ~write =
  let access = (if write then 1 else 0) lor (if user then 2 else 0) in
  if !inlined then p "i=((a>>>12)&1023)+1;if(TG[i]===(a>>>12)&&(RT[i]&%d))p=PG[i]|(a&4095);else p=tr(a,%d);" (1 lsl access) (if write then 1 else 0)
  else p "p=TR(a,%d,%d);" (1 lsl access) (if write then 1 else 0)

let load_word into = if !inlined then p "%s=(p>>>0)<RAM&&!(p&3)?I32[p>>2]:ld32(p);" into else p "%s=L32(p);" into
let load_byte into = if !inlined then p "%s=(p>>>0)<RAM?U8[p]:ld8(p);" into else p "%s=L8(p);" into
(* (when blocks are checked against the interpreter, each store says
 * first where it writes: [attach]'s run_checked puts the bytes back) *)
let checking = ref false
let logged n = if !checking then p "lg(p,%d);" n

let load_half into = if !inlined then p "%s=(p>>>0)<RAM-1?U8[p]|(U8[p+1]<<8):ld16(p);" into else p "%s=L16(p);" into
let store_half v =
  logged 2;
  if !inlined then p "if((p>>>0)<RAM-1){U8[p]=%s;U8[p+1]=%s>>8;}else{st16(p,%s);x=1;}" v v v else p "x|=S16(p,%s);" v
let store_word v =
  logged 4;
  if !inlined then p "if((p>>>0)<RAM&&!(p&3))I32[p>>2]=%s;else{st32(p,%s);x=1;}" v v else p "x|=S32(p,%s);" v
let store_byte v =
  logged 1;
  if !inlined then p "if((p>>>0)<RAM)U8[p]=%s;else{st8(p,%s);x=1;}" v v else p "x|=S8(p,%s);" v

(* the second operand in b; its carry out as text, None when it is the
 * flag as it was; false: a shift the interpreter keeps *)
let operand pc op2 =
  match op2 with
  | Imm { imm8; rot } ->
      let v = Arm32.imm_value ~imm8 ~rot in
      p "b=%d;" v;
      Some (if rot = 0 then None else Some (if (v lsr 31) land 1 = 1 then "1" else "0"))
  | Sreg (rm, No_shift) -> p "b=%s;" (reg pc rm); Some None
  | Sreg (rm, By_imm (LSL, n)) when n > 0 && n < 32 -> p "v=%s;b=v<<%d;" (reg pc rm) n; Some (Some (Printf.sprintf "(v>>>%d)&1" (32 - n)))
  | Sreg (rm, By_imm (LSR, n)) when n > 0 && n < 32 -> p "v=%s;b=v>>>%d;" (reg pc rm) n; Some (Some (Printf.sprintf "(v>>>%d)&1" (n - 1)))
  | Sreg (rm, By_imm (ASR, n)) when n > 0 && n < 32 -> p "v=%s;b=v>>%d;" (reg pc rm) n; Some (Some (Printf.sprintf "(v>>>%d)&1" (n - 1)))
  (* by a register's low byte (Arm32's shift): 0 leaves the value and
   * the carry, 32 and more shift everything out *)
  | Sreg (rm, By_reg (LSL, rs)) when rs <> 15 && has "reg" ->
      p "v=%s;c=R[%d]&255;b=c<32?v<<c:0;" (reg pc rm) (rs + 1);
      Some (Some "(c===0?S[4]:c<32?(v>>>(32-c))&1:c===32?v&1:0)")
  | Sreg (rm, By_reg (LSR, rs)) when rs <> 15 && has "reg" ->
      p "v=%s;c=R[%d]&255;b=c<32?(v>>>c)|0:0;" (reg pc rm) (rs + 1);
      Some (Some "(c===0?S[4]:c<32?(v>>>(c-1))&1:c===32?v>>>31:0)")
  | Sreg (rm, By_reg (ASR, rs)) when rs <> 15 && has "reg" ->
      p "v=%s;c=R[%d]&255;b=c<32?v>>c:v>>31;" (reg pc rm) (rs + 1);
      Some (Some "(c===0?S[4]:c<32?(v>>>(c-1))&1:v>>>31)")
  | _ -> None

let nz () = p "S[2]=r>>>31;S[3]=+(r===0);"

(* Arm32_fast's dp: a logical result with the shifter's carry, a sum
 * with its own *)
let logical s rd expr carry =
  (* (pc written: the value left in r, the jump is [instruction]'s) *)
  if rd = 15 then p "r=%s;" expr
  else if not s then p "R[%d]=%s;" (rd + 1) expr
  else begin
    p "r=%s;" expr; nz ();
    (match carry with Some c -> p "S[4]=%s;" c | None -> ());
    p "R[%d]=r;" (rd + 1)
  end

(* q + y + cin: cin "0", "1" or the flag *)
let sum s x y cin =
  (match cin with
   | "0" -> p "r=(%s+%s)|0;" x y
   | "1" -> p "r=(%s+%s+1)|0;" x y
   | _ -> p "c=S[4];r=(%s+%s+c)|0;" x y);
  if s then begin
    (match cin with
     | "0" -> p "c=+((r>>>0)<(%s>>>0));" x
     | "1" -> p "c=+((r>>>0)<=(%s>>>0));" x
     | _ -> p "c=+(c?(r>>>0)<=(%s>>>0):(r>>>0)<(%s>>>0));" x x);
    nz ();
    p "S[4]=c;S[5]=((%s^r)&(%s^r))>>>31;" x y
  end

(* a data-processing instruction (its condition passed); false: the
 * interpreter's *)
let dp pc op s rd rn op2 =
    let at = Buffer.length buf in
    match operand pc op2 with
    | None -> Buffer.truncate buf at; false
    | Some carry ->
        let a = reg pc rn in
        let put () = if rd <> 15 then p "R[%d]=r;" (rd + 1) in
        let arith x y cin = p "q=%s;" a; sum s x y cin; put () in
        let compare x y cin = p "q=%s;" a; sum true x y cin in
        (match op with
         | AND -> logical s rd (a ^ "&b") carry
         | EOR -> logical s rd (a ^ "^b") carry
         | ORR -> logical s rd (a ^ "|b") carry
         | BIC -> logical s rd (a ^ "&~b") carry
         | MOV -> logical s rd "b" carry
         | MVN -> logical s rd "~b" carry
         | ADD -> arith "q" "b" "0"
         | ADC -> arith "q" "b" "c"
         | SUB -> p "y=~b;"; arith "q" "y" "1"
         | SBC -> p "y=~b;"; arith "q" "y" "c"
         | RSB -> p "q=%s;y=~q;" a; sum s "b" "y" "1"; put ()
         | RSC -> p "q=%s;y=~q;" a; sum s "b" "y" "c"; put ()
         | TST -> p "r=%s&b;" a; nz (); (match carry with Some c -> p "S[4]=%s;" c | None -> ())
         | TEQ -> p "r=%s^b;" a; nz (); (match carry with Some c -> p "S[4]=%s;" c | None -> ())
         | CMP -> p "y=~b;"; compare "q" "y" "1"
         | CMN -> compare "q" "b" "0");
        true

(* a word or a byte loaded or stored (Arm32's Mem); false: the
 * interpreter's (a half, a double, as the user, a shift it keeps, pc
 * loaded) *)
let mem ~user pc ~load ~size ~rd ~rn ~offset ~up ~index ~writeback ~as_user ~interp ~count =
  let off =
    match offset with
    | Off_imm n -> Some (string_of_int n)
    | Off_reg (rm, No_shift) when rm <> 15 -> Some (reg pc rm)
    | Off_reg (rm, By_imm (LSL, n)) when rm <> 15 && n > 0 && n < 32 -> Some (Printf.sprintf "(%s<<%d)" (reg pc rm) n)
    | Off_reg (rm, By_imm (LSR, n)) when rm <> 15 && n > 0 && n < 32 && has "mem" -> Some (Printf.sprintf "(%s>>>%d)" (reg pc rm) n)
    | Off_reg (rm, By_imm (ASR, n)) when rm <> 15 && n > 0 && n < 32 && has "mem" -> Some (Printf.sprintf "(%s>>%d)" (reg pc rm) n)
    | _ -> None in
  match off with
  | Some off when size <> Dword && not as_user && not (rd = 15 && (not load || size <> Word))
                  && (has "pc" || not (load && rd = 15)) && (has "mem" || size = Word || size = Byte) ->
      let back = (index = Post || writeback) && rn <> 15 in
      p "q=%s;y=(q%s(%s))|0;a=%s;" (reg pc rn) (if up then "+" else "-") off (if index = Pre then "y" else "q");
      translate ~user ~write:(not load);
      if load then begin
        (match size with
         | Word -> load_word "v"
         | Byte -> load_byte "v"
         | Sbyte -> load_byte "v"; p "v=(v<<24)>>24;"
         | Half -> load_half "v"
         | Shalf -> load_half "v"; p "v=(v<<16)>>16;"
         | Dword -> ());
        (* (pc loaded: a jump; bit 0 would be Thumb, the interpreter's
         * refusal, nothing being written yet) *)
        if rd = 15 then p "if(v&1){ex(%d);return n+%d;}" interp count;
        if back then p "R[%d]=y;" (rn + 1);
        if rd = 15 then p "S[6]=v&~3;return n+%d;" count else p "R[%d]=v;" (rd + 1)
      end
      else begin
        (* (the value before the base is written back) *)
        p "v=%s;" (reg pc rd);
        (match size with Word -> store_word "v" | Byte -> store_byte "v" | _ -> store_half "v");
        if back then p "R[%d]=y;" (rn + 1)
      end;
      true
  | _ -> false

(* registers pushed or popped (Arm32_fast's Block, without ^); the text
 * after it when pc is loaded: the block's end. false: the
 * interpreter's *)
let block ~user pc ~load ~rn ~writeback ~mode ~regs ~interp ~count =
  if rn = 15 || regs = 0 then false
  else begin
    let nreg = ref 0 in
    for k = 0 to 15 do nreg := !nreg + ((regs lsr k) land 1) done;
    let nreg = !nreg in
    let start = match mode with IA -> 0 | IB -> 4 | DA -> 4 - (4 * nreg) | DB -> - (4 * nreg) in
    let final = match mode with IA | IB -> 4 * nreg | DA | DB -> - (4 * nreg) in
    p "q=R[%d];a=(q+(%d))|0;" (rn + 1) start;
    let j = ref 0 in
    for k = 0 to 15 do
      if (regs lsr k) land 1 = 1 then begin
        translate ~user ~write:(not load);
        (if load then load_word (Printf.sprintf "t%d" !j) else (p "v=%s;" (reg pc k); store_word "v"));
        incr j;
        if !j < nreg then p "a=(a+4)|0;"
      end
    done;
    if load then begin
      (* (pc with bit 0: Thumb, which the interpreter refuses; nothing
       * is written yet, it runs the instruction again) *)
      if regs land 0x8000 <> 0 then p "if(t%d&1){ex(%d);return n+%d;}" (nreg - 1) interp count;
      if writeback then p "R[%d]=(q+(%d))|0;" (rn + 1) final;
      j := 0;
      for k = 0 to 14 do
        if (regs lsr k) land 1 = 1 then (p "R[%d]=t%d;" (k + 1) !j; incr j)
      done;
      if regs land 0x8000 <> 0 then p "S[6]=t%d&~3;return n+%d;" !j count
    end
    else if writeback then p "R[%d]=(q+(%d))|0;" (rn + 1) final;
    true
  end

(* what the interpreter runs and the block must end after: the
 * interrupts or the translation may have changed, or a device was
 * written *)
let ends = function
  | Msr _ | Cps _ | Coproc _ | Coproc2 _ | Svc _ | Hint _ | Undefined _ | Vmsr _ | Clrex | Barrier _ -> true
  | Mem { load = false; _ } | Swp _ | Strex _ | Vldst { load = false; _ } | Vblock { load = false; _ } -> true
  | Block { psr = true; _ } -> true
  | Dp { s = true; rd = 15; _ } -> true
  | _ -> false

(* (the last instruction was the interpreter's: a block of them mostly
 * is not made) *)
let was_interpreted = ref false

(* One instruction, number k of its block, at pc. `Ended: nothing can
 * follow it in the block. *)
let instruction ~user ~start k pc (i : Arm32_isa.t) =
  let count = k + 1 in
  let pc4 = Bits.mask32 (pc + 4) and pc8 = Bits.mask32 (pc + 8) in
  (* by the interpreter: the instruction kept, run by its number; the
   * block goes on when the interpreter did (next is pc + 4) *)
  let interpreted () =
    was_interpreted := true;
    let g = keep pc i in
    (* (blocks checked against the interpreter have none of its
     * instructions: they stop before one, which the board's loop runs) *)
    if !checking then (p "S[6]=%d;return n+%d;\n" pc k; `Ended)
    else
    if ends i then (p "ex(%d);W[3]=1;return n+%d;\n" g count; `Ended)
    else (p "ex(%d);if(S[6]!==%d)return n+%d;\n" g pc4 count; `Goes) in
  (* under its condition *)
  let guarded cond body =
    let c = cond_text cond in
    if c = "" then body () else begin p "if(%s){" c; let r = body () in p "}"; r end in
  (* a store that was a device's: the block ends *)
  let stored () = p "if(x){W[3]=1;S[6]=%d;return n+%d;}" pc4 count in
  let at = Buffer.length buf in
  let fallback () = Buffer.truncate buf at; interpreted () in
  match i with
  | Dp { cond; op; s; rd; rn; op2 } when not (s && rd = 15) && (rd <> 15 || has "pc") ->
      (* (pc written, mov pc, lr: a jump; bit 0 would be Thumb, the
       * interpreter's refusal, nothing being written yet) *)
      let jump = rd = 15 && (match op with TST | TEQ | CMP | CMN -> false | _ -> true) in
      let g = if jump then keep pc i else 0 in
      if guarded cond (fun () ->
          dp pc op s rd rn op2
          && (if jump then p "if(r&1){ex(%d);return n+%d;}S[6]=r&~3;return n+%d;" g count count; true))
      then (p "\n"; if jump && cond = AL then `Ended else `Goes)
      else fallback ()
  | Mem { cond; load; size; rd; rn; offset; up; index; writeback; user = as_user } ->
      p "R[16]=%d;" pc8;
      let jump = load && rd = 15 in
      let g = if jump then keep pc i else 0 in
      if guarded cond (fun () -> mem ~user pc ~load ~size ~rd ~rn ~offset ~up ~index ~writeback ~as_user ~interp:g ~count) then begin
        if not load then stored ();
        p "\n"; if jump && cond = AL then `Ended else `Goes
      end
      else fallback ()
  | Block { cond; load; rn; writeback; mode; regs; psr = false } ->
      p "R[16]=%d;" pc8;
      let g = keep pc i in
      if guarded cond (fun () -> block ~user pc ~load ~rn ~writeback ~mode ~regs ~interp:g ~count) then begin
        if not load then stored ();
        p "\n";
        if load && regs land 0x8000 <> 0 && cond = AL then `Ended else `Goes
      end
      else fallback ()
  | Branch { cond; link; offset } ->
      let target = Bits.mask32 (pc + 8 + offset) in
      let loops = target = start && not link in
      (* (an unconditional one elsewhere: only the link here, the
       * block's maker goes on at the target or leaves) *)
      if cond = AL && not loops then begin
        if link then p "R[15]=%d;" pc4;
        `Jumps target
      end
      else begin
        ignore (guarded cond (fun () ->
          if link then p "R[15]=%d;" pc4;
          (* (to the block's start: around again, a look at the board's
           * loop every [loop_limit] instructions) *)
          if loops then p "n+=%d;if(n<%d){W[0]=n;continue L;}S[6]=%d;return n;" count loop_limit target
          else p "S[6]=%d;return n+%d;" target count;
          true));
        p "\n";
        if cond = AL then `Ended else `Goes
      end
  | Bx { cond; link; rm } when rm <> 15 ->
      (* (bit 0: Thumb, the interpreter's refusal) *)
      let g = keep pc i in
      ignore (guarded cond (fun () ->
        p "v=R[%d];if(v&1){ex(%d);return n+%d;}" (rm + 1) g count;
        if link then p "R[15]=%d;" pc4;
        p "S[6]=v&~3;return n+%d;" count;
        true));
      p "\n";
      if cond = AL then `Ended else `Goes
  | Mul { cond; s = false; rd; rm; rs; acc } when rd <> 15 && rm <> 15 && rs <> 15 && acc <> Some 15 ->
      ignore (guarded cond (fun () ->
        (match acc with
         | Some ra -> p "R[%d]=(Math.imul(R[%d],R[%d])+R[%d])|0;" (rd + 1) (rm + 1) (rs + 1) (ra + 1)
         | None -> p "R[%d]=Math.imul(R[%d],R[%d]);" (rd + 1) (rm + 1) (rs + 1));
        true));
      p "\n"; `Goes
  | Extend { cond; signed; half; rd; rn = 15; rm; rot = 0 } when rd <> 15 && rm <> 15 ->
      ignore (guarded cond (fun () ->
        (match signed, half with
         | false, false -> p "R[%d]=R[%d]&255;" (rd + 1) (rm + 1)
         | false, true -> p "R[%d]=R[%d]&65535;" (rd + 1) (rm + 1)
         | true, false -> p "R[%d]=(R[%d]<<24)>>24;" (rd + 1) (rm + 1)
         | true, true -> p "R[%d]=(R[%d]<<16)>>16;" (rd + 1) (rm + 1));
        true));
      p "\n"; `Goes
  | _ -> interpreted ()

(*****************************************************************************)
(* The blocks *)
(*****************************************************************************)

(* a block: where it starts (the key), its instructions' words when it
 * was translated, its code (None: not worth one) *)
type block = { key : int; words : (int * int) array; code : U.any option; mutable checked : int; pure : bool }

(* the number of the I-cache's invalidations: a block's words are
 * compared with the memory's once after each ([checked]), and after its
 * page was written (-1) *)
let age = ref 0

(* by the physical address of their first instruction: a block outlives
 * the table's emptying (Plan 9 invalidates the instructions' cache at
 * each switch of process), and is put back when its words are still
 * the memory's *)
let by_pa : (int, block) Hashtbl.t = Hashtbl.create 4096

(* the code of a text: a program run again has its pages elsewhere and
 * the same blocks *)
let by_text : (string, U.any) Hashtbl.t = Hashtbl.create 4096

let translate_block (st : state) env key pa =
  let user = key land 1 = 1 and start = key land lnot 3 in
  Buffer.clear buf;
  asked := false;
  Buffer.add_string buf head;
  let words = ref [] and native = ref 0 and places = ref [] in
  let rec go k pc pa =
    let w = Memory.load32 st.mem pa in
    Board.code_page pa;
    words := (pa, w) :: !words;
    places := (pc, k + 1) :: !places;
    let i = Arm32.decode w in
    was_interpreted := false;
    let r = instruction ~user ~start k pc i in
    if not !was_interpreted then incr native;
    let leave target = p "S[6]=%d;return n+%d;\n" target (k + 1) in
    match r with
    | `Ended -> ()
    | `Goes ->
        (* (not into the next page: its translation is another) *)
        if k + 1 < max_len && (pc + 4) land 0xfff <> 0 then go (k + 1) (pc + 4) (pa + 4)
        else leave (Bits.mask32 (pc + 4))
    | `Jumps target ->
        (* A jump or a call to a place of the same page, not yet in the
         * block: the block goes on there (a trace: the call and what is
         * called in one function of the host's). The same page: the
         * block is found by its first page's translation, and put back
         * by its words. *)
        if k + 1 < max_len && target lsr 12 = start lsr 12 && not (List.mem_assoc target !places) && !follow
        then (p "\n"; go (k + 1) target (pa - (pc land 0xfff) + (target land 0xfff)))
        else leave target in
  go 0 start pa;
  (* (where each instruction is in the block, by its address + 8, what
   * r15 is when one raises: [attach]'s blocks_done) *)
  Buffer.add_string buf "}};f.pos={";
  List.iter (fun (pc, count) -> p "\"%d\":%d," (Bits.mask32 (pc + 8)) count) !places;
  Buffer.add_string buf "};return f;";
  let words = Array.of_list (List.rev !words) in
  (* (a block the interpreter would run all of is not one) *)
  if !native * 2 < Array.length words || !native < 2 || !made >= !most then begin
    incr refused;
    { key; words; code = None; checked = !age; pure = false }
  end
  else begin
    let text = Buffer.contents buf in
    let code =
      match Hashtbl.find_opt by_text text with
      | Some c -> incr retexted; c
      | None ->
          incr compiled;
          if !made + 1 = !most then prerr_endline (Printf.sprintf "the last block made, at %x:\n%s" (key land lnot 3) text);
          let c = U.meth_call env "make" [| U.inject (Js.string text) |] in Hashtbl.replace by_text text c; c in
    incr made;
    (* (no instruction of the interpreter's in it: [attach]'s run_checked) *)
    { key; words; code = Some code; checked = !age; pure = not !asked }
  end

let same (st : state) (b : block) =
  let ok = ref true in
  Array.iter (fun (pa, w) -> if !ok && Memory.load32 st.mem pa <> w then ok := false) b.words;
  !ok

(* [attach board]: the board's blocks are this module's *)
let attach board =
  (match Sys.getenv_opt "JIT_WITHOUT" with Some l -> without := String.split_on_char ',' l | None -> ());
  (match Sys.getenv_opt "JIT_MOST" with Some n -> most := int_of_string n | None -> ());
  checking := Sys.getenv_opt "JIT_CHECK" <> None;
  if has "follow" then () else follow := false;
  if has "calls" then () else inlined := true;
  (match Sys.getenv_opt "JIT_THRESHOLD" with Some n -> threshold := int_of_string n | None -> ());
  let (st : state), (mmu : Mmu32.t), mem = Board.parts board in
  if not (fields st) then failwith "Jit: the state is not where the translated code reads it";
  let ram, _ = Memory.direct mem 0 4 in
  let u8 = Js_of_ocaml.Typed_array.Bytes.to_uint8Array ram in
  let get o name = U.get o (Js.string name) in
  let i32 = U.new_obj (get U.global "Int32Array")
      [| U.inject (get u8 "buffer"); U.inject (get u8 "byteOffset"); U.inject (Bytes.length ram / 4) |] in
  let svc (st : state) _ = Arm32.take st Supervisor_call ~ret:(st.r.(15) - 4) in
  let env = U.obj [|
    "R", U.inject st.r; "S", U.inject st; "TG", U.inject mmu.tags; "PG", U.inject mmu.pages; "RT", U.inject mmu.rights;
    "U8", U.inject u8; "I32", U.inject i32; "RAM", U.inject (Bytes.length ram);
    "W", U.inject (U.new_obj (get U.global "Int32Array") [| U.inject 4 |]); "threshold", U.inject !threshold;
    "ld16", U.inject (Js.wrap_callback (fun (pa : int) -> Memory.load16 mem pa));
    "st16", U.inject (Js.wrap_callback (fun (pa : int) (v : int) -> Memory.store16 mem pa v));
    "tr", U.inject (Js.wrap_callback (fun (va : int) (access : int) -> st.translate va access));
    "ld32", U.inject (Js.wrap_callback (fun (pa : int) -> Memory.load32 mem pa));
    "ld8", U.inject (Js.wrap_callback (fun (pa : int) -> Memory.load8 mem pa));
    "st32", U.inject (Js.wrap_callback (fun (pa : int) (v : int) -> Memory.store32 mem pa v));
    "st8", U.inject (Js.wrap_callback (fun (pa : int) (v : int) -> Memory.store8 mem pa v));
    "ex", U.inject (Js.wrap_callback (fun (g : int) -> let addr, i = !insts.(g) in Arm32_fast.execute st ~addr ~svc i));
  |] in
  ignore (U.fun_call (U.new_obj (get U.global "Function") [| U.inject (Js.string "E"); U.inject (Js.string runtime) |]) [| U.inject env |]);
  let install key code pa = ignore (U.meth_call env "install" [| U.inject key; U.inject code; U.inject (pa land lnot 0xfff) |]) in
  (* where the blocks of each physical page start *)
  let in_page : (int, int list) Hashtbl.t = Hashtbl.create 1024 in
  let cells = get env "W" in
  let run_plain (code : U.any) : int = U.meth_call env "first" [| U.inject code |] in
  let run = run_plain in
  (* [checked]: a block's first run is done again by the interpreter,
   * from the same registers and flags and the same memory (the bytes
   * the block's stores wrote are put back: [log]), and what each left
   * compared: the registers, the flags, where it goes next, those
   * bytes. A block that raises, or that the interpreter's instructions
   * are part of, is not compared. To find a wrong translation:
   * JIT_CHECK=1 for Boot_jit. *)
  let log = ref [] in
  U.set env (Js.string "lg") (U.inject (Js.wrap_callback (fun (pa : int) (n : int) ->
    for k = 0 to n - 1 do log := (pa + k, (try Memory.load8 mem (pa + k) with _ -> 0)) :: !log done)));
  let run_checked key (code : U.any) : int =
    let r0 = Array.copy st.r and f0 = (st.n, st.z, st.c, st.v, st.next) in
    log := [];
    let n = run code in
    let r1 = Array.copy st.r and f1 = (st.n, st.z, st.c, st.v, st.next) in
    let wrote = List.map (fun (a, _) -> a, (try Memory.load8 mem a with _ -> 0)) !log in
    (* (the first value logged of an address is the oldest: put back last) *)
    (try List.iter (fun (a, old) -> if a < Bytes.length ram then Memory.store8 mem a old) !log with _ -> ());
    Array.blit r0 0 st.r 0 16;
    (let (a, b, c, d, e) = f0 in st.n <- a; st.z <- b; st.c <- c; st.v <- d; st.next <- e);
    let pc = ref (key land lnot 3) and trace = Buffer.create 256 in
    (try
       for _ = 1 to n do
         let w = Memory.load32 mem (st.translate !pc 0) in
         Printf.bprintf trace " %x:%08x" !pc w;
         Arm32_fast.execute st ~addr:!pc ~svc (Arm32.decode w);
         pc := st.next
       done
     with e -> Printf.bprintf trace " raised %s" (Printexc.to_string e));
    let same = ref ((st.n, st.z, st.c, st.v, st.next) = f1) in
    List.iter (fun (a, v) -> if (try Memory.load8 mem a with _ -> 0) <> v then (same := false; Printf.eprintf "  byte %x: the block's %x\n" a v)) wrote;
    for k = 0 to 14 do if st.r.(k) <> r1.(k) then same := false done;
    if not !same then begin
      Printf.eprintf "Jit: the block at %x and the interpreter differ after %d instructions:%s\n" (key land lnot 3) n (Buffer.contents trace);
      for k = 0 to 14 do
        if st.r.(k) <> r1.(k) then Printf.eprintf "  r%d: the block's %x, the interpreter's %x (it was %x)\n" k r1.(k) st.r.(k) r0.(k)
      done;
      let (a, b, c, d, e) = f1 in
      Printf.eprintf "  flags and next: the block's %b %b %b %b %x, the interpreter's %b %b %b %b %x\n%!" a b c d e st.n st.z st.c st.v st.next;
      exit 2
    end;
    n in
  let run key code = if !checking then run_checked key code else run code in
  (* A key with no block in the table, and worth asking (E.run: reached
   * by a jump often, or its slot lost): its block put back when its
   * words are still the memory's, or made, and run. Only a place
   * reached by a jump may start a block: else every instruction of a
   * loop would start one. 0: no block, the interpreter's. *)
  let miss (key : int) : int =
      match st.translate (key land lnot 3) 0 with
      | exception Arm32.Abort _ -> 0
      | pa ->
          let b =
            match Hashtbl.find_opt by_pa pa with
            | Some b when b.key = key && (b.checked = !age || same st b) -> b.checked <- !age; incr reused; b
            | _ ->
                let b = translate_block st env key pa in
                Hashtbl.replace by_pa pa b;
                let page = pa land lnot 0xfff in
                let l = Option.value (Hashtbl.find_opt in_page page) ~default:[] in
                if not (List.mem pa l) then Hashtbl.replace in_page page (pa :: l);
                b in
          (match b.code with
           | Some code -> install key code pa; if b.pure then run key code else run_plain code
           | None -> install key Js.null pa; 0) in
  U.set env (Js.string "miss") (U.inject (Js.wrap_callback miss));
  (* (a function of JavaScript's of one argument is a closure of OCaml's) *)
  Board.blocks := (Obj.magic (get env "run") : int -> int);
  Board.blocks_forget := (fun () -> incr age; ignore (U.meth_call env "forget" [||]));
  (* (a page's blocks are forgotten, and are out of the table: made again
   * when run again, their code found by their text if it is the same) *)
  Board.blocks_written := (fun pa n ->
    let page = ref (pa land lnot 0xfff) in
    while !page < pa + n do
      (match Hashtbl.find_opt in_page !page with
       | Some l ->
           List.iter (Hashtbl.remove by_pa) l; Hashtbl.remove in_page !page;
           ignore (U.meth_call env "written" [| U.inject !page |])
       | None -> ());
      page := !page + 4096
    done);
  (* the instructions a block ran when it raised: those of its turns
   * done and of the blocks before it, and up to the one that raised (r15 is its address + 8) *)
  Board.blocks_done := (fun () ->
    let cell i : int = Obj.magic (U.get cells i) in
    let b = cell 0 and t = cell 2 in
    t + b + (Obj.magic (U.meth_call env "at" [| U.inject st.r.(15) |]) : int));
  Board.blocks_on := true
