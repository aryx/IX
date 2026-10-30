(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Das.mli *)

(*****************************************************************************)
(* Words *)
(*****************************************************************************)

let u32 v = Int64.logand v 0xffffffffL
let s32 v = Int64.of_int32 (Int64.to_int32 v)

(* the bits of w from [sh], masked *)
let fld w sh m =
  Int64.to_int (Int64.logand (Int64.shift_right_logical w sh) (Int64.of_int m))
let bit w n = fld w n 1 = 1
let masked w m v = Int64.logand w m = v

(* ROR, of a word *)
let ror v s =
  let v = u32 v in
  if s = 0 then v
  else u32 (Int64.logor (Int64.shift_right_logical v s) (Int64.shift_left v (32 - s)))

(* Plan 9's %x as acid's xfmt makes it, 0x before; %lux unsigned, %lx
 * signed *)
let lux v = Printf.sprintf "0x%Lx" (u32 v)
let llux v = Printf.sprintf "0x%Lx" v
let lx v =
  let v = s32 v in
  if v < 0L then Printf.sprintf "-0x%Lx" (Int64.neg v) else Printf.sprintf "0x%Lx" v

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

type table = {
  text : Symbols.sym array;
  locals : Symbols.sym list array;   (* each function's a, p, m entries *)
  globals : Symbols.sym array;
  sb : int64;
}

(* a symbol's value, a word (the table's 4 bytes: a parameter's
 * 0xfffffffc is not -4, on arm's 31-bit ints neither) *)
let value (s : Symbols.sym) = u32 (Int64.of_int s.value)

let is_text (s : Symbols.sym) = String.contains "TtLl" s.typ
let is_data (s : Symbols.sym) = String.contains "DdBb" s.typ

(* Plan 9's qsort (libc's port/qsort.c), which buildtbls sorts the
 * functions with: not stable, so of two functions at one address (cas
 * and casp) the one found is the one it puts last *)
let qsort cmp (a : 'a array) =
  let swap i j = let x = a.(i) in a.(i) <- a.(j); a.(j) <- x in
  let pivot lo n =
    let j = n / 6 in
    let pi = lo + j in
    let pj = pi + 2 * j in
    let pk = pj + 2 * j in
    if cmp a.(pi) a.(pj) < 0 then begin
      if cmp a.(pi) a.(pk) < 0 then (if cmp a.(pj) a.(pk) < 0 then pj else pk)
      else pi
    end
    else if cmp a.(pj) a.(pk) < 0 then (if cmp a.(pi) a.(pk) < 0 then pi else pk)
    else pj in
  let rec sorts lo n =
    let lo = ref lo and n = ref n in
    while !n > 1 do
      swap !lo (if !n > 10 then pivot !lo !n else !lo + !n / 2);
      let pn = !lo + !n in
      let pi = ref !lo and pj = ref pn and more = ref true in
      while !more do
        incr pi;
        while !pi < pn && cmp a.(!pi) a.(!lo) < 0 do incr pi done;
        decr pj;
        while !pj > !lo && cmp a.(!pj) a.(!lo) > 0 do decr pj done;
        if !pj < !pi then more := false else swap !pi !pj
      done;
      swap !lo !pj;
      let j = !pj - !lo in
      let rest = !n - j - 1 in
      if j >= rest then begin sorts !lo j; lo := !lo + j + 1; n := rest end
      else begin sorts (!lo + j + 1) rest; n := j end
    done in
  sorts 0 (Array.length a)

let table syms =
  let fns = ref [] and cur = ref None and locs = ref [] and globs = ref [] in
  let close () =
    match !cur with Some f -> fns := (f, List.rev !locs) :: !fns | None -> () in
  List.iter (fun (s : Symbols.sym) ->
    if is_text s then begin close (); cur := Some s; locs := [] end
    else if String.contains "apm" s.typ then locs := s :: !locs
    else if is_data s then globs := s :: !globs) syms;
  close ();
  let fns = Array.of_list (List.rev !fns) in
  qsort (fun ((a : Symbols.sym), _) ((b : Symbols.sym), _) ->
    compare (value a) (value b)) fns;
  (* the data by address, then name (symcomp) *)
  let globals = Array.of_list (List.sort (fun (a : Symbols.sym) (b : Symbols.sym) ->
    if value a <> value b then compare (value a) (value b)
    else compare a.name b.name) !globs) in
  let setr12 (s : Symbols.sym) = s.name = "setR12" && (is_text s || is_data s) in
  let sb = match List.find_opt setr12 syms with
    | Some s -> value s
    | None -> 0L in
  { text = Array.map fst fns; locals = Array.map snd fns; globals; sb }

(* srchtext, srchdata: the last entry at or below v, -1 if none *)
let search (a : Symbols.sym array) v =
  let lo = ref (-1) and hi = ref (Array.length a) in
  while !hi - !lo > 1 do
    let mid = (!lo + !hi) / 2 in
    if value a.(mid) <= v then lo := mid else hi := mid
  done;
  !lo

(* findsym: in the text (CTEXT), or anywhere (CANY: the text but its
 * last symbol, etext, then the data) *)
let findsym t v text_only =
  let i = search t.text v in
  if i >= 0 && (text_only || i <> Array.length t.text - 1) then Some t.text.(i)
  else if text_only then None
  else (let j = search t.globals v in if j >= 0 then Some t.globals.(j) else None)

(* a long's distance (a word's, as 5db's long delta) *)
let distance v (s : Symbols.sym) = Int64.abs (s32 (Int64.sub v (value s)))

let symoff t text_only v =
  match (if v = 0L then None else findsym t v text_only) with
  | None -> llux v
  | Some s ->
      let delta = distance v s in
      if s.typ <> 't' && s.typ <> 'T' && delta >= 4096L then llux v
      else if delta <> 0L then s.name ^ "+" ^ lux delta
      else s.name

(* gsymoff: a constant as a symbol, a data's plus an offset, or #0x... *)
let gsymoff t v =
  let v = u32 v in
  match (if v = 0L then None else findsym t v false) with
  | None -> "#" ^ lux v
  | Some s ->
      let delta = distance v s in
      if delta >= 4096L || s.name = ".string" then "#" ^ lux v
      else if delta = 0L then s.name
      else if s.typ <> 't' && s.typ <> 'T' then
        s.name ^ "+" ^ llux (Int64.sub v (value s))
      else "#" ^ lux v

(*****************************************************************************)
(* The opcodes *)
(*****************************************************************************)

(* 5db's Instr: the word and its fields, as the printers set them *)
type instr = {
  w : int64;
  addr : int64;
  op : int;                     (* the index in opcodes *)
  cond : int;                   (* bits 28-31 *)
  mutable store : int;
  mutable rd : int;             (* bits 12-15 *)
  mutable rn : int;             (* bits 16-19 *)
  mutable rs : int;             (* bits 0-3 *)
  mutable imm : int64;          (* a long's value *)
}

(* the printers (armdps...) and the follow functions (armfadd...) *)
type printer = Dps | Dpi | Sdti | Vstdi | Hwby | Sdts | Bdt | Unk | Branch | Bpt | Co
type foll = Next | Fadd | Fmov | Fmovm | Fbranch | Fbx

(* a mnemonic's template, its printer, its follow, its operands' *)
type opcode = { o : string; fmt : printer; foll : foll; a : string }

let op o fmt foll a = { o; fmt; foll; a }

(* the data processing instructions, 0 to 63: 16 operations, their
 * second operand a register, a register shifted by a constant or by a
 * register, a constant *)
let dp_names = [| "AND"; "EOR"; "SUB"; "RSB"; "ADD"; "ADC"; "SBC"; "RSC";
                  "TST"; "TEQ"; "CMP"; "CMN"; "ORR"; "MOVW"; "BIC"; "MVN" |]

let dp form k =
  let first = match form with
    | 0 -> "R%s" | 1 -> "(R%s%h%m)" | 2 -> "(R%s%hR%M)" | _ -> "$#%i" in
  let rest =
    if k >= 8 && k <= 11 then ",R%n"
    else if k = 13 || k = 15 then ",R%d"
    else ",R%n,R%d" in
  let foll = if k = 4 then Fadd else if k = 13 then Fmov else Next in
  op (dp_names.(k) ^ "%C%S") (if form = 3 then Dpi else Dps) foll (first ^ rest)

let opcodes = Array.append (Array.init 64 (fun n -> dp (n / 16) (n mod 16))) [|
(* 48+16 *)
  op "MUL%C%S" Dpi Next "R%M,R%s,R%n";
  op "MULA%C%S" Dpi Next "R%M,R%s,R%n,R%d";
  op "SWPW" Dpi Next "R%s,(R%n),R%d";
  op "SWPB" Dpi Next "R%s,(R%n),R%d";
(* 48+16+4 *)
  op "MOV%u%C%p" Hwby Next "R%d,(R%n%UR%M)";
  op "MOV%u%C%p" Hwby Next "R%d,%I";
  op "MOV%u%C%p" Hwby Fmov "(R%n%UR%M),R%d";
  op "MOV%u%C%p" Hwby Fmov "%I,R%d";
(* 48+24 *)
  op "MOVW%C%p" Sdti Next "R%d,%I";
  op "MOVB%C%p" Sdti Next "R%d,%I";
  op "MOVW%C%p" Sdti Fmov "%I,R%d";
  op "MOVBU%C%p" Sdti Fmov "%I,R%d";

  op "MOVW%C%p" Sdts Next "R%d,(R%s%h%m)(R%n)";
  op "MOVB%C%p" Sdts Next "R%d,(R%s%h%m)(R%n)";
  op "MOVW%C%p" Sdts Fmov "(R%s%h%m)(R%n),R%d";
  op "MOVBU%C%p" Sdts Fmov "(R%s%h%m)(R%n),R%d";

  op "MOVM%C%P%a" Bdt Fmovm "[%r],(R%n)";
  op "MOVM%C%P%a" Bdt Fmovm "(R%n),[%r]";

  op "B%C" Branch Fbranch "%b";
  op "BL%C" Branch Fbranch "%b";

  op "CDP%C" Co Next "";
  op "CDP%C" Co Next "";
  op "MCR%C" Co Next "";
  op "MRC%C" Co Next "";
(* 48+24+4+4+2+2+4 *)
  op "MULLU%C%S" Dpi Next "R%M,R%s,(R%n,R%d)";
  op "MULALU%C%S" Dpi Next "R%M,R%s,(R%n,R%d)";
  op "MULL%C%S" Dpi Next "R%M,R%s,(R%n,R%d)";
  op "MULAL%C%S" Dpi Next "R%M,R%s,(R%n,R%d)";
(* 92 *)
  op "UNK" Unk Next "";
(* 93: v7's *)
  op "LDREX" Dpi Next "(R%n),R%d";
  op "STREX" Dpi Next "R%s,(R%n),R%d";
  op "CLREX" Unk Next "";
(* 96 *)
  op "DSB" Unk Next "";
  op "DMB" Unk Next "";
  op "ISB" Unk Next "";
(* 99 *)
  op "RFEV7%P%a" Bdt Next "(R%n)";
(* 100: VFP *)
  op "MLA%f%C" Dps Next "F%s,F%n,F%d";
  op "MLS%f%C" Dps Next "F%s,F%n,F%d";
  op "NMLS%f%C" Dps Next "F%s,F%n,F%d";
  op "NMLA%f%C" Dps Next "F%s,F%n,F%d";
  op "MUL%f%C" Dps Next "F%s,F%n,F%d";
  op "NMUL%f%C" Dps Next "F%s,F%n,F%d";
  op "ADD%f%C" Dps Next "F%s,F%n,F%d";
  op "SUB%f%C" Dps Next "F%s,F%n,F%d";
  op "DIV%f%C" Dps Next "F%s,F%n,F%d";
(* 109 *)
  op "MOV%f%C" Dps Next "F%s,F%d";
  op "ABS%f%C" Dps Next "F%s,F%d";
  op "NEG%f%C" Dps Next "F%s,F%d";
  op "SQRT%f%C" Dps Next "F%s,F%d";
  op "CMP%f%C" Dps Next "F%s,F%d";
  op "CMPE%f%C" Dps Next "F%s,F%d";
  op "CMP%f%C" Dps Next "$0.0,F%d";
  op "CMPE%f%C" Dps Next "$0.0,F%d";
(* 117 *)
  op "MOV%F%R%C" Dps Next "F%s,F%d";
(* 118 *)
  op "MOVW%C" Dps Next "R%d,F%n";
  op "MOVW%C" Dps Next "F%n,R%d";
  op "MOVW%C" Dps Next "R%d,%x";
  op "MOVW%C" Dps Next "%x,R%d";
(* 122 *)
  op "MOV%f%C" Vstdi Next "F%d,%I";
  op "MOV%f%C" Vstdi Next "%I,F%d";
(* 124 *)
  op "BKPT%C" Bpt Next "$#%i";
  op "BX%C" Dps Fbx "(R%s)";
  op "BXJ%C" Dps Fbx "(R%s)";
  op "BLX%C" Dps Fbx "(R%s)";
|]

(* armclass: a word's opcode *)
let armclass w =
  let ldst base = base + fld w 22 1 + fld w 19 2 in
  match fld w 25 7 with
  | 0 ->                                (* data processing r,r,r *)
      if masked w 0x0ff00080L 0x01200000L then begin
        let op = fld w 4 7 in
        if op = 7 then 124                (* bkpt *)
        else if op > 0 && op < 4 then op + 124      (* bx, blx *)
        else 92
      end else begin
        let op = fld w 4 0xf in
        if op = 9 then begin             (* mul, swp or *rex *)
          if masked w 0x0ff00fffL 0x01900f9fL then 93
          else if masked w 0x0ff00ff0L 0x01800f90L then 94
          else if bit w 24 then 66 + fld w 22 1       (* swp, swpb *)
          else begin
            let op = if bit w 23 then 88 + 2 * fld w 22 1 else 64 in
            op + fld w 21 1             (* mla *)
          end
        end
        else if op land 9 = 9 then ldst 68     (* ld/st byte/half s/u *)
        else begin
          let op = fld w 21 0xf in
          if bit w 4 then op + 32
          else if fld w 7 31 <> 0 || bit w 5 then op + 16
          else op
        end
      end
  | 1 -> 48 + fld w 21 0xf              (* data processing i,r,r *)
  | 2 ->                                (* load/store byte/word i(r) *)
      let barrier =
        if masked w 0xffffff8fL 0xf57ff00fL then
          (match fld w 4 7 with 1 -> 95 | 4 -> 96 | 5 -> 97 | 6 -> 98 | _ -> 0)
        else 0 in
      if barrier <> 0 then barrier else ldst 72
  | 3 -> ldst 76                        (* load/store byte/word (r)(r) *)
  | 4 ->                                (* block data transfer *)
      if masked w 0xfe50ffffL 0xf8100a00L then 99 else 80 + fld w 20 1
  | 5 -> 82 + fld w 24 1                (* branch, branch and link *)
  | 7 ->                                (* coprocessors *)
      let cp = fld w 8 0xf in
      if cp = 10 || cp = 11 then begin  (* vfp *)
        if bit w 4 then
          (match fld w 21 7 with
           | 0 -> 118 + fld w 20 1
           | 7 -> 120 + fld w 20 1
           | _ -> 92)
        else if not (bit w 23) then 100 + fld w 19 6 + fld w 6 1
        else
          (match fld w 19 6 + fld w 6 1 with
           | 0 -> 108
           | 7 ->
               if not (bit w 19) then begin
                 if not (bit w 17) then 109 + fld w 16 4 + fld w 15 2 + fld w 7 1
                 else if fld w 16 7 = 7 then 117
                 else 92
               end
               else (match fld w 16 7 with 0 | 4 | 5 -> 117 | _ -> 92)
           | _ -> 92)
      end
      else 84 + fld w 3 2 + fld w 20 1
  | 6 -> if fld w 21 9 = 8 then 122 + fld w 20 1 else 92   (* vfp load/store *)
  | _ -> 92

let decode load pc =
  match load pc with
  | None -> None
  | Some w ->
      let w = u32 w in
      Some { w; addr = pc; op = armclass w; cond = fld w 28 0xf;
             store = 0; rd = 0; rn = 0; rs = 0; imm = 0L }

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

let cond = [| "EQ"; "NE"; "CS"; "CC"; "MI"; "PL"; "VS"; "VC";
              "HI"; "LS"; "GE"; "LT"; "GT"; "LE"; ""; "NV" |]
let shtype = [| "<<"; ">>"; "->"; "@>" |]
let hb = [| "???"; "HU"; "B"; "H" |]
let addsub = [| "-"; "+" |]
let mode = [| ""; "IA"; "DB"; "IB" |]
let pw = [| "P"; "PW"; ""; "W" |]
let sw = [| ""; "W"; "S"; "SW" |]

let dot b s = if s <> "" then Buffer.add_string b ("." ^ s)

(* plocal: an offset from SP as the function's parameter or local, by
 * its .frame: below the frame a local, name-off(SP), above it a
 * parameter, name+off(FP) *)
let plocal t (i : instr) =
  let k = search t.text i.addr in
  let locals = if k < 0 then [] else t.locals.(k) in
  match List.find_opt (fun (s : Symbols.sym) -> s.name = ".frame") locals with
  | None -> None
  | Some f ->
      let frame = value f in
      let imm = s32 i.imm in
      (* (the frame unsigned, the offset converted: a negative one is
       * a parameter's) *)
      let auto = imm >= 0L && frame > imm in
      let off =
        s32 (if auto then Int64.sub frame imm else Int64.sub (Int64.sub imm frame) 4L) in
      let typ = if auto then 'a' else 'p' in
      let at (s : Symbols.sym) = s.typ = typ && value s = off in
      match List.find_opt at locals with
      | None -> None
      | Some s ->
          if auto then Some (s.name ^ "-" ^ Int64.to_string (value s) ^ "(SP)")
          else Some (s.name ^ "+" ^ Int64.to_string (value s) ^ "(FP)")

(* an operand at an address: a parameter or local; a load from the
 * literal pool after the function its constant; from R12, setR12's
 * base, a static's address *)
let address t load (i : instr) b =
  match (if i.rn = 13 then plocal t i else None) with
  | Some s -> Buffer.add_string b s
  | None ->
      let suffix = ref None in
      if i.rn = 15 then
        (match load (Int64.add (Int64.add i.addr i.imm) 8L) with
         | Some v -> i.imm <- s32 v; suffix := Some ""
         | None -> ());
      if t.sb <> 0L then begin
        if i.rd = 11 then
          (match load (Int64.add i.addr 4L) with
           | Some nxt when masked (u32 nxt) 0x0e0f0fffL 0x060c000bL ->
               i.imm <- s32 (Int64.add i.imm t.sb); suffix := Some "-SB"
           | _ -> ());
        if i.rn = 12 then begin
          i.imm <- s32 (Int64.add i.imm t.sb); suffix := Some "-SB(SB)"
        end
      end;
      match !suffix with
      | Some s -> Buffer.add_string b ("$" ^ gsymoff t i.imm ^ s)
      | None ->
          Buffer.add_string b ("#" ^ lx i.imm ^ "(R" ^ string_of_int i.rn ^ ")")

(* a register list, its runs as R0-R3 *)
let reglist (i : instr) b =
  let n = ref (Int64.to_int (Int64.logand i.imm 0xffffL)) in
  let j = ref 0 and k = ref false in
  while !n <> 0 do
    let m = !j in
    while !n land 1 = 1 do incr j; n := !n lsr 1 done;
    if !j <> m then begin
      if !k then Buffer.add_string b ",";
      if !j = m + 1 then Buffer.add_string b ("R" ^ string_of_int m)
      else
        Buffer.add_string b ("R" ^ string_of_int m ^ "-R" ^ string_of_int (!j - 1));
      k := true
    end;
    incr j;
    n := !n lsr 1
  done

(* a template expanded (format's loop) *)
let expand t load (i : instr) b f =
  let w = i.w in
  let add s = Buffer.add_string b s in
  let n = String.length f in
  let k = ref 0 in
  while !k < n do
    let c = f.[!k] in
    if c <> '%' then Buffer.add_char b c
    else if !k + 1 >= n then Buffer.add_char b '%'
    else begin
      incr k;
      match f.[!k] with
      | 'C' -> dot b cond.(i.cond)                      (* .CONDITION *)
      | 'S' -> if i.store <> 0 then add ".S"            (* .STORE *)
      | 'P' -> dot b mode.(fld w 23 3)                  (* block move's P, U *)
      | 'p' -> dot b pw.(i.store)                       (* P, W *)
      | 'a' -> dot b sw.(i.store)                       (* S, W *)
      | 's' -> add (string_of_int (i.rs land 0xf))
      | 'M' -> add (string_of_int (fld w 8 0xf))
      | 'm' -> add (string_of_int (fld w 7 0x1f))
      | 'h' -> add shtype.(fld w 5 3)
      | 'u' -> add hb.(fld w 5 3)                       (* signed, half, byte *)
      | 'I' -> address t load i b
      | 'U' -> add addsub.(fld w 23 1)
      | 'n' -> add (string_of_int i.rn)
      | 'd' -> add (string_of_int i.rd)
      | 'i' -> add (lux i.imm)
      | 'b' -> add (symoff t true (u32 i.imm))
      | 'g' -> add (gsymoff t i.imm)
      | 'f' -> (match fld w 8 0xf with 10 -> add "F" | 11 -> add "D" | _ -> ())
      | 'F' ->
          let unsigned = not (bit w 7) in
          (match fld w 15 0xe + fld w 8 1 with
           | 0x0 -> add (if unsigned then "WF.U" else "WF")
           | 0x1 -> add (if unsigned then "WD.U" else "WD")
           | 0x8 -> add "FW.U"
           | 0x9 -> add "DW.U"
           | 0xA -> add "FW"
           | 0xB -> add "DW"
           | 0xE -> add "FD"
           | 0xF -> add "DF"
           | _ -> ())
      | 'R' -> if not (bit w 7) then add "R"
      | 'x' ->
          (match i.rn with
           | 0 -> add "FPSID"
           | 1 -> add "FPSCR"
           | 2 -> add "FPEXC"
           | r -> add ("FPS(" ^ string_of_int r ^ ")"))
      | 'r' -> reglist i b
      | c -> add ("%" ^ String.make 1 c)
    end;
    incr k
  done

(* format: the mnemonic, a tab, the operands *)
let format t load (i : instr) b mnemonic operands =
  expand t load i b mnemonic;
  Buffer.add_char b '\t';
  expand t load i b operands

(* the printers: an instruction's fields, as its kind has them *)
let print t load (i : instr) b =
  let o = opcodes.(i.op) in
  let w = i.w in
  let fmt m a = format t load i b m a in
  let negated v = if bit w 23 then v else Int64.neg v in
  match o.fmt with
  | Dps ->
      i.store <- fld w 20 1;
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      i.rs <- fld w 0 0xf;
      if i.rn = 15 && i.rs = 0 && i.op = 8 then fmt "MOVW" "CPSR, R%d"
      else if i.rn = 15 && i.rs = 0 && i.op = 10 then fmt "MOVW" "SPSR, R%d"
      else if i.rn = 9 && i.rd = 15 && i.op = 9 then fmt "MOVW" "R%s, CPSR"
      else if i.rn = 9 && i.rd = 15 && i.op = 11 then fmt "MOVW" "R%s, SPSR"
      else if i.rd = 15 && i.op = 120 then fmt "MOVW" "PSR, %x"
      else if i.rd = 15 && i.op = 121 then fmt "MOVW" "%x, PSR"
      else fmt o.o o.a
  | Dpi ->
      i.imm <- s32 (ror (Int64.logand w 0xffL) (2 * fld w 8 0xf));
      i.store <- fld w 20 1;
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      i.rs <- fld w 0 0xf;
      (* RET is ADD $0,R14,R15 *)
      if masked w 0x0fffffffL 0x028ef000L then fmt "RET%C" ""
      else if masked w 0x0ff0ffffL 0x0280f000L then fmt "B%C" "0(R%n)"
      else fmt o.o o.a
  | Sdti ->
      i.imm <- s32 (negated (Int64.logand w 0xfffL));
      i.store <- fld w 23 2 lor fld w 21 1;
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      (* RET is MOVW.P x(R13),R15 *)
      if masked w 0x0ffff000L 0x049df000L then fmt "RET%C%p" "%I"
      else fmt o.o o.a
  | Vstdi ->
      i.imm <- s32 (negated (Int64.shift_left (Int64.logand w 0xffL) 2));
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      fmt o.o o.a
  | Hwby ->
      (* (5db's: the offset's two nibbles or'ed, not the high one
       * shifted) *)
      i.store <- fld w 23 2 lor fld w 21 1;
      i.imm <- s32 (negated (Int64.of_int (fld w 0 0xf lor fld w 8 0xf)));
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      i.rs <- fld w 0 0xf;
      fmt o.o o.a
  | Sdts ->
      i.store <- fld w 23 2 lor fld w 21 1;
      i.rs <- fld w 0 0xf;
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      fmt o.o o.a
  | Bdt ->
      i.store <- fld w 21 3;
      i.rn <- fld w 16 0xf;
      i.imm <- Int64.logand w 0xffffL;
      if w = 0xe8fd8000L then fmt "RFE" "" else fmt o.o o.a
  | Unk -> fmt o.o o.a
  | Branch ->
      let v = Int64.logand w 0xffffffL in
      let v = if bit v 23 then Int64.logor v 0xff000000L else v in
      i.imm <- s32 (Int64.add (Int64.shift_left v 2) (Int64.add i.addr 8L));
      fmt o.o o.a
  | Bpt ->
      i.imm <- Int64.of_int ((fld w 4 0xfff0) lor fld w 0 0xf);
      fmt o.o o.a
  | Co ->
      i.rn <- fld w 16 0xf;
      i.rd <- fld w 12 0xf;
      i.rs <- fld w 0 0xf;
      let cp = fld w 8 0xf and p = fld w 5 7 in
      let operands =
        if bit w 4 then
          Printf.sprintf "#0x%x, #0x%x, R%d, C(%d), C(%d), #0x%x"
            cp (fld w 21 7) i.rd i.rn i.rs p
        else
          Printf.sprintf "#0x%x, #0x%x, C(%d), C(%d), C(%d), #0x%x"
            cp (fld w 20 0xf) i.rd i.rn i.rs p in
      fmt o.o operands

let instruction t load pc =
  match decode load pc with
  | None -> None
  | Some i ->
      let b = Buffer.create 64 in
      print t load i b;
      Some (Buffer.contents b)

(*****************************************************************************)
(* Following *)
(*****************************************************************************)

let r n = "R" ^ string_of_int n

(* armcondpass: whether the PSR's flags pass the condition *)
let condpass reg c =
  let psr = reg "PSR" in
  let n = bit psr 31 and z = bit psr 30 and c' = bit psr 29 and v = bit psr 28 in
  match c with
  | 1 -> not z
  | 2 -> c'
  | 3 -> not c'
  | 4 -> n
  | 5 -> not n
  | 6 -> v
  | 7 -> not v
  | 8 -> c' && not z
  | 9 -> not c' || z
  | 10 -> n = v
  | 11 -> n <> v
  | 12 -> not z && n = v
  | 13 -> z || n <> v
  | 14 -> true
  | 15 -> false
  | _ -> z

(* the carry, on top (RRX) *)
let carry reg v =
  let c = Int64.of_int (fld (reg "PSR") 29 1) in
  Int64.logor (Int64.shift_left c 31) (Int64.shift_right_logical v 1)

let sign v = if bit v 31 then 0xffffffffL else 0L
let asr32 v s = u32 (Int64.shift_right (s32 v) s)

(* armshiftval: a data processing instruction's second operand *)
let shiftval reg w =
  if bit w 25 then ror (Int64.logand w 0xffL) (fld w 7 0x1e)
  else begin
    let v = u32 (reg (r (fld w 0 0xf))) in
    let s = fld w 7 0x1f in
    let by () = Int64.to_int (Int64.logand (reg (r (s lsr 1))) 0xffL) in
    match fld w 4 7 with
    | 1 -> let s = by () in if s >= 32 then 0L else u32 (Int64.shift_left v s)
    | 2 -> Int64.shift_right_logical v s
    | 3 -> let s = by () in if s >= 32 then 0L else Int64.shift_right_logical v s
    | 4 -> if s = 0 then sign v else asr32 v s
    | 5 -> let s = by () in if s >= 32 then sign v else asr32 v s
    | 6 -> if s = 0 then carry reg v else ror v s
    | 7 ->
        let s = Int64.to_int (Int64.logand (reg (r ((s lsr 1) land 0xf))) 0xfL) in
        if s = 0 then v else ror v s
    | _ -> u32 (Int64.shift_left v s)
  end

let rec nbits v = if v = 0 then 0 else (v land 1) + nbits (v lsr 1)

(* armmaddr: a MOVM's first address (5db's count without R15) *)
let maddr reg w =
  let v = reg (r (fld w 16 0xf)) in
  let nb = Int64.of_int (4 * nbits (fld w 0 0x7fff)) in
  u32 (match fld w 23 3 with
       | 1 -> v
       | 2 -> Int64.sub v nb
       | 3 -> Int64.add v 4L
       | _ -> Int64.add (Int64.sub v nb) 4L)

(* armaddr: a load's address (its index register read as a byte, as
 * 5db's uchar) *)
let addr reg w =
  let rn = u32 (reg (r (fld w 16 0xf))) in
  let plus x = u32 (if bit w 23 then Int64.add rn x else Int64.sub rn x) in
  if not (bit w 24) then rn
  else if not (bit w 25) then plus (Int64.logand w 0xfffL)
  else begin
    let rm = Int64.logand (reg (r (fld w 0 0xf))) 0xffL in
    let s = fld w 7 0x1f in
    plus (match fld w 5 3 with
          | 0 -> u32 (Int64.shift_left rm s)
          | 1 | 2 -> Int64.shift_right_logical rm s
          | _ -> if s = 0 then carry reg rm else ror rm s)
  end

let follow load reg pc =
  match decode load pc with
  | None -> None
  | Some i ->
      let w = i.w in
      let next = Int64.add pc 4L in
      let pass () = condpass reg (fld w 28 0xf) in
      match opcodes.(i.op).foll with
      | Next -> Some next
      | Fadd ->
          if fld w 12 0xf <> 15 || not (pass ()) then Some next
          else Some (Int64.add (reg (r (fld w 16 0xf))) (shiftval reg w))
      | Fbx -> if not (pass ()) then Some next else Some (reg (r (fld w 0 0xf)))
      | Fmovm ->
          if not (bit w 15) || not (pass ()) then Some next
          else
            load (u32 (Int64.add (maddr reg w) (Int64.of_int (nbits (fld w 0 0xffff)))))
      | Fbranch ->
          if not (pass ()) then Some next
          else begin
            let off = Int64.shift_right (s32 (Int64.shift_left w 8)) 6 in
            Some (Int64.add pc (Int64.add off 8L))
          end
      | Fmov ->
          if fld w 12 0xf <> 15 || not (pass ()) then Some next
          else if fld w 26 3 = 1 then
            (match load (addr reg w) with Some v -> Some (u32 v) | None -> Some next)
          else Some (shiftval reg w)
