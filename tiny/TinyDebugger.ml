(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyDebugger.mli *)

module TSys = TinyLibSystem
module M = TinyLibMachine
module P = TinyLibPlayground
module GUI = TinyLibGUI

(* the kernel's trace of a process, a descriptor (-1 refused): tiny-kernel's
 * alone, no other system's, so not TinyLibSystem's (mlsys.c's u_trace) *)
external u_trace : TSys.pid -> TSys.fd = "u_trace"

(*****************************************************************************)
(* What debug says *)
(*****************************************************************************)

(* a command written to a trace, a refusal not a reason to end (the
 * process may have just ended) *)
let put fd s = try TSys.write fd s with Failure _ -> ()

(* where what debug says goes: its output, written at once (the
 * debugged program's own output comes between), or the window's text;
 * main sets it, with its capability *)
let saying = ref (fun (_ : string) -> ())
let say s = !saying s

(* what f says, as a string *)
let text f =
  let was = !saying in
  let b = Buffer.create 256 in
  saying := Buffer.add_string b;
  f ();
  saying := was;
  Buffer.contents b

(* a number in hexadecimal, a negative one in decimal *)
let hex a = if a < 0 then string_of_int a else M.hex a

(* a word, unsigned, by its halves: the whole may not fit tiny-ml's int *)
let word_hex (w : M.word) =
  let h = Int32.to_int (Int32.shift_right_logical w 16)
  and l = Int32.to_int (Int32.logand w (Int32.of_int 0xffff)) in
  if h = 0 then M.hex l else Printf.sprintf "0x%x%04x" h l

(*****************************************************************************)
(* The process *)
(*****************************************************************************)

(* The process debugged: the kernel's trace of it; its program's labels;
 * where it is stopped (None: it runs, or ended); its breakpoints; in a
 * window, the pipe its output comes on when debug started it, until its
 * end (old: globals, the descriptors -1 for none) *)
type process = {
  trace : TSys.fd;
  funcs : M.symbols;
  mutable pc : M.address option;
  mutable stops : M.address list;
  mutable output : TSys.fd option;
}

(* The reason in the kernel's "stopped pc why" line (TinyKernelScheduler
 * and TinyKernelCalls' stop). A breakpoint and an illegal instruction
 * are the same trap: the kernel says break when the word was its own 0,
 * written at b, and illegal with the word otherwise. A program debug
 * started stops at its exec first, before its first instruction. Other
 * keeps a reason this debugger does not know, shown as it came. *)
type stop =
  | Stepped
  | Breakpoint
  | Fault of M.address
  | Illegal of M.word
  | Exec
  | Other of string

(* the word at i in s, its low byte first (under 2^30: ML's ints) *)
let word_of s i =
  String.get_uint16_le s i + (String.get_uint16_le s (i + 2) lsl 16)

(* the program's labels, by address, from its file: after the image,
 * whose size the header says (none when it has no labels, or is not
 * read) *)
let symbols caps (file : Fpath.t) : M.symbols =
  (* (the header read, then a seek past the image: the image is not read,
   * the debugger's heap too small for a big program's whole file) *)
  match (try Some (TSys.open_in caps file) with Failure _ -> None) with
  | None -> Array.of_list []
  | Some fd ->
      let funcs =
        try
          let h = TSys.read fd 16 in
          let word i = word_of h i in
          (* (tiny-linker -n's header has a fourth word, the text's size) *)
          let split = String.length h = 16 && word 0 = 0x7a0ce6 in
          if String.length h >= 12 && (word 0 = 0x7a0ce5 || split) then begin
            TSys.seek fd ((if split then 16 else 12) + word 4);
            M.labels (TSys.read_all fd)
          end
          else Array.of_list []
        with Failure _ -> Array.of_list [] in
      TSys.close fd;
      funcs

(*****************************************************************************)
(* The trace *)
(*****************************************************************************)

(* the next line of the trace, and a command and its answer ("" when
 * the kernel refused it). In a window, the program's output is read
 * meanwhile, before its stops (its pipe never full) *)
let rec next (p : process) =
  match p.output with
  | Some o when TSys.ready [ o; p.trace ] None = Some o ->
      let s = TSys.read o 512 in
      if s = "" then (TSys.close o; p.output <- None) else say s;
      next p
  | _ ->
      let s = TSys.read p.trace 4096 in
      let n = String.length s in
      if n > 0 && s.[n - 1] = '\n' then String.sub s 0 (n - 1) else s
let ask p c =
  if (try TSys.write p.trace c; true with Failure _ -> false) then next p
  else ""

(* the next stop, and why (None when the process ended, said); a stop
 * said; the next stop said, false when the process ended. The
 * instruction at the stop is said by listing, below *)
let stopped p =
  let number s f = match int_of_string_opt s with Some n -> f n | None -> Other s in
  match String.split_on_char ' ' (next p) with
  | "stopped" :: at :: why ->
      p.pc <- Some (int_of_string at);
      Some (match why with
            | [ "step" ] -> Stepped
            | [ "break" ] -> Breakpoint
            | [ "fault"; a ] -> number a (fun a -> Fault a)
            | [ "illegal"; w ] ->
                (* (the word read whole: it may have its top bits set,
                 * past tiny-ml's int) *)
                (try Illegal (Int64.to_int32 (Int64.of_string w))
                 with Failure _ -> Other w)
            | [ "exec" ] -> Exec
            | _ -> Other (String.concat " " why))
  | "exited" :: rest -> say ("exited " ^ String.concat " " rest ^ "\n"); None
  | _ -> say "the trace ended\n"; None

(*****************************************************************************)
(* The process's memory *)
(*****************************************************************************)

(* n bytes of the process at a, from the kernel's hexadecimal ("" when
 * outside it) *)
let bytes p (a : M.address) n =
  let h = ask p ("m " ^ string_of_int a ^ " " ^ string_of_int n) in
  let digit c = if c <= '9' then Char.code c - 48 else Char.code c - 87 in
  String.init (String.length h / 2) (fun i ->
    Char.chr ((digit h.[2 * i] * 16) + digit h.[(2 * i) + 1]))

(* a word of s at i: as hexadecimal digits (a word may be past ML's 31
 * bits), and as an instruction's (under 2^30: the others are none) *)
let digits s i =
  let d = "0123456789abcdef" in
  String.init 8 (fun k ->
    let b = Char.code s.[i + 3 - (k / 2)] in
    d.[if k mod 2 = 0 then b / 16 else b mod 16])
let instr s i : M.instr option =
  if Char.code s.[i + 3] >= 0x40 then None else M.decode (word_of s i)

(* the process's word at a, read as an address (one past 2^30 is
 * none: no address of tiny-kernel's is), and as an instruction *)
let address_at p a : M.address option =
  let s = bytes p a 4 in
  if String.length s < 4 || Char.code s.[3] >= 0x40 then None
  else Some (word_of s 0)
let instr_at p a : M.instr option =
  let s = bytes p a 4 in
  if String.length s < 4 then None else instr s 0

(* the start of the function an address is in *)
let func_start p a =
  match M.find p.funcs a with Some (_, b) -> Some b | None -> None

(* an address by its function, main+0x14 (in hexadecimal when there is
 * none) *)
let name p a =
  match M.find p.funcs a with
  | Some (f, b) when a = b -> f
  | Some (f, b) -> f ^ "+" ^ hex (a - b)
  | None -> Printf.sprintf "%x" a

(* the instruction at a, as tiny-cpu -l lists it, by its function; a
 * jump's or a branch's target named when it is a function's start *)
let listing p a =
  let s = bytes p a 4 in
  let text =
    if String.length s < 4 then "?"
    else
      match instr s 0 with
      | Some i ->
          let target =
            match i with
            | M.Jal (_, off) -> Some (a + 4 + (4 * off))
            | M.Branch (_, _, _, off) -> Some (a + 4 + (4 * off))
            | _ -> None in
          M.listing a i
          ^ (match target with
             | Some t when func_start p t = Some t -> " <" ^ name p t ^ ">"
             | _ -> "")
      | None -> ".word\t0x" ^ digits s 0 in
  name p a ^ ":\t" ^ text ^ "\n"

let show p why =
  (match why with
   | Stepped -> ()
   | Breakpoint -> say "break\n"
   | Fault a -> say ("fault at " ^ hex a ^ "\n")
   | Illegal w -> say ("illegal " ^ word_hex w ^ "\n")
   | Exec -> say "exec\n"
   | Other s -> say (s ^ "\n"));
  match p.pc with Some at -> say (listing p at) | None -> ()
let wait p = match stopped p with Some why -> show p why; true | None -> false

(* the registers, as the kernel says them, "r1 v ... r15 v pc v": r1 to
 * r15 at their numbers in values (0 the zero register's), and the pc
 * (old: the kernel's pairs of words, a register by its name, "r14") *)
type registers = { values : int array; at : M.address }

let registers p : registers option =
  let values = Array.make 16 0 in
  let rec go l k =
    match l with
    | [ "pc"; v ] when k = 16 ->
        (match int_of_string_opt v with
         | Some at -> Some { values; at }
         | None -> None)
    | r :: v :: rest when k < 16 && r = "r" ^ string_of_int k ->
        (match int_of_string_opt v with
         | Some v -> values.(k) <- v; go rest (k + 1)
         | None -> None)
    | _ -> None in
  go (String.split_on_char ' ' (ask p "r")) 1
let reg p (r : M.reg) =
  match registers p with Some regs -> regs.values.(r) | None -> 0

(*****************************************************************************)
(* The commands *)
(*****************************************************************************)

(* an address typed: a number, pc, a function's name and maybe +n *)
let address p s =
  let at base =
    if base = "pc" then p.pc
    else
      match int_of_string_opt base with
      | Some a -> Some a
      | None -> M.address p.funcs base in
  match String.index_opt s '+' with
  | Some i ->
      (match at (String.sub s 0 i),
             int_of_string_opt (String.sub s (i + 1) (String.length s - i - 1))
       with
       | Some a, Some k -> Some (a + k)
       | _ -> None)
  | None -> at s

let ok s = if s <> "ok" then say "?\n"

(* c, s and n; false when the process ended *)
let continue p =
  if p.pc <> None then (put p.trace "c"; p.pc <- None);
  wait p
let step p =
  match p.pc with
  | None -> say "?\n"; true
  | Some _ -> put p.trace "s"; p.pc <- None; wait p
let over p (at : M.address) =
  let s = bytes p at 4 in
  let call =
    String.length s = 4
    && (match instr s 0 with
        | Some (M.Jal (d, _)) -> d = M.lr
        | Some (M.Jalr (d, _, _)) -> d = M.lr
        | _ -> false) in
  if not call then step p
  else begin
    (* the breakpoint after the call, a stop there not said; in a
     * recursive function the call's own return is told by its sp, the
     * same as at the call: one with a lower sp is a deeper call's, run
     * past *)
    let a = at + 4 and sp = reg p M.sp in
    let mine = not (List.mem a p.stops) in
    if mine then ok (ask p ("b " ^ string_of_int a));
    let rec go () =
      put p.trace "c";
      p.pc <- None;
      match stopped p with
      | Some Breakpoint when p.pc = Some a && reg p M.sp < sp -> go ()
      | Some Breakpoint when p.pc = Some a -> say (listing p a); true
      | Some why -> show p why; true
      | None -> false in
    let alive = go () in
    if alive && mine then ok (ask p ("d " ^ string_of_int a));
    alive
  end

(* a slot of the value stack, at i in s: an integer (odd: n is 2n+1)
 * in decimal, a pointer in hexadecimal, _ for 0 (a slot not set yet:
 * the prologue zeroes them) *)
let value s i =
  let b k = Char.code s.[i + k] in
  if b 0 land 1 = 1 then begin
    let n =
      (b 0 lsr 1) + (b 1 lsl 7) + (b 2 lsl 15) + ((b 3 land 0x7f) lsl 23) in
    string_of_int (if b 3 >= 0x80 then n - 0x20000000 - 0x20000000 else n)
  end
  else if b 0 + b 1 + b 2 + b 3 = 0 then "_"
  else if b 3 < 0x40 then hex (word_of s i)
  else "0x" ^ digits s i

(* an ML function's slots, the f bytes from v: its closure's (slot 0)
 * left out, then its parameters, its variables, its spills (six at
 * most) *)
let slots p v f =
  let s = bytes p v f in
  let n = min (String.length s / 4) 7 in
  String.concat " " (List.init (max 0 (n - 1)) (fun k -> value s (4 * (k + 1))))
  ^ (if f / 4 > 7 then " ..." else "")

(* tiny-ml's value stack's register, r12 (TinyMLMachine's vsp) *)
let vsp = 12

(* the prologue of the function at b, tiny-c's and tiny-ml's: addi sp,
 * sp, -f and stw lr, k(sp), its frame's f bytes and k *)
let prologue p b =
  match instr_at p b, instr_at p (b + 4) with
  | Some (M.Alui (M.Add, d, a, f)), Some (M.Store (M.W, r, a', k))
    when d = M.sp && a = M.sp && f < 0 && r = M.lr && a' = M.sp ->
      Some (-f, k)
  | _ -> None

(* the v bytes of the ML function at b on the value stack, its third
 * instruction addi vsp, vsp, v; 0 for another function *)
let ml_frame p b =
  match instr_at p (b + 8) with
  | Some (M.Alui (M.Add, d, a, v)) when d = vsp && a = vsp && v > 0 -> v
  | _ -> 0

(* bt: the frames, from the pc's, by the code itself. tiny-c's and
 * tiny-ml's functions all start with their prologue: a frame is f
 * bytes, its return address at k(sp). Before those two instructions
 * have run, the return address is still in lr, the frame not yet made
 * (the first frame alone can be there); a function without them
 * (assembly: write, _start) keeps it in lr, and ends the walk after the
 * first frame. A tail call's frame is gone: the frames are the callers
 * that will be returned to. Each line is the call's place (the return
 * address less 4).
 *
 * An ML function's frame on the value stack is v bytes below vsp
 * (ml_frame). Its slots follow its name; the frames above start v
 * lower. The first ML frame is vsp's when the pc is in ML, else
 * ml_vsp's (where ML leaves vsp when it calls C) *)
let backtrace p =
  match p.pc, registers p with
  | Some at, Some regs ->
      let lr = regs.values.(M.lr) in
      let rec go k pc sp vs =
        let b = func_start p pc in
        let v, entered =
          match b with Some b -> ml_frame p b, pc >= b + 12 | None -> 0, false in
        let shown = v > 0 && (k > 0 || entered) in
        say (string_of_int k ^ "\t" ^ name p pc
             ^ (if shown then "\t" ^ slots p (vs - v) v else "") ^ "\n");
        let vs = if shown then vs - v else vs in
        let frame =
          match b with
          | None -> None
          | Some b ->
              match prologue p b with
              | Some (f, off) ->
                  if pc = b then (if k = 0 then Some (lr, sp) else None)
                  else if pc = b + 4 then
                    (if k = 0 then Some (lr, sp + f) else None)
                  else
                    (match address_at p (sp + off) with
                     | Some ret -> Some (ret, sp + f)
                     | None -> None)
              | None -> if k = 0 then Some (lr, sp) else None in
        match frame with
        | Some (ret, sp) when ret > 0 && k < 64 -> go (k + 1) (ret - 4) sp vs
        | _ -> () in
      let in_ml =
        match func_start p at with Some b -> ml_frame p b > 0 | None -> false in
      let vs =
        if in_ml then regs.values.(vsp)
        else
          match M.address p.funcs "ml_vsp" with
          | Some a -> (match address_at p a with Some v -> v | None -> 0)
          | None -> 0 in
      go 0 at regs.values.(M.sp) vs
  | _ -> say "?\n"

(* the registers, four a line in columns, by the listing's names (zero,
 * sp, lr: reg_name), and the instruction at the pc *)
let show_registers p =
  match registers p with
  | Some regs ->
      for k = 1 to 15 do
        let r = M.reg_name k ^ " " ^ hex regs.values.(k) in
        say (if k mod 4 = 0 then r ^ "\n"
             else r ^ String.make (max 1 (16 - String.length r)) ' ')
      done;
      say ("\n" ^ listing p regs.at)
  | None -> say "?\n"

(* x: n words, four a line; x/i: n instructions *)
let words p a n =
  let s = bytes p a (4 * n) in
  if String.length s < 4 * n then say "?\n"
  else
    for k = 0 to n - 1 do
      if k mod 4 = 0 then say (Printf.sprintf "%x:" (a + (4 * k)));
      say ("\t" ^ digits s (4 * k));
      if k mod 4 = 3 || k = n - 1 then say "\n"
    done
let instructions p a n =
  for k = 0 to n - 1 do say (listing p (a + (4 * k))) done

(* x and x/i's n words or instructions at a *)
let examine p show a rest =
  match address p a, rest with
  | Some a, [] -> show p a 1
  | Some a, [ n ] ->
      (match int_of_string_opt n with
       | Some n when n > 0 && n <= 256 -> show p a n
       | _ -> say "?\n")
  | _ -> say "?\n"

(* a command; false to quit *)
let command p line =
  match List.filter (fun w -> w <> "") (String.split_on_char ' ' line) with
  | [] -> true
  | [ "b"; a ] ->
      (match address p a with
       | Some a when ask p ("b " ^ string_of_int a) = "ok" ->
           p.stops <- a :: p.stops
       | _ -> say "?\n");
      true
  | [ "d"; a ] ->
      (match address p a with
       | Some a ->
           ok (ask p ("d " ^ string_of_int a));
           p.stops <- List.filter (fun b -> b <> a) p.stops
       | None -> say "?\n");
      true
  | [ "c" ] -> continue p
  | [ "s" ] -> step p
  | [ "n" ] -> (match p.pc with None -> say "?\n"; true | Some at -> over p at)
  | [ "r" ] -> show_registers p; true
  | [ "bt" ] -> backtrace p; true
  | "x" :: a :: rest -> examine p words a rest; true
  | "x/i" :: a :: rest -> examine p instructions a rest; true
  | [ "q" ] -> false
  | _ -> say "?\n"; true

(* the commands, a line each, until q, the input's end or the process's *)
let pending = ref ""
let rec read_line () =
  match String.index_opt !pending '\n' with
  | Some i ->
      let l = String.sub !pending 0 i in
      pending := String.sub !pending (i + 1) (String.length !pending - i - 1);
      Some l
  | None ->
      let s = TSys.read TSys.fd_stdin 4096 in
      if s = "" then None else (pending := !pending ^ s; read_line ())
let rec loop p =
  match read_line () with
  | Some l -> if command p l then loop p else false
  | None -> false

(*****************************************************************************)
(* The window *)
(*****************************************************************************)

(* the window's model: what was said, its lines (the last 100); the
 * command typed; the panes, made after each command; the mouse's
 * buttons as last seen (1 left, 2 middle, 4 right); the window's size,
 * and its buttons' shapes and boxes, each with its command *)
type model = {
  log : string list; cmd : string; panes : string list; held : int;
  w : int; h : int; bar : P.shape list;
  boxes : string GUI.boxes;
}

(* a text's lines, the tabs as spaces to the next multiple of 8 *)
let lines s =
  let untab l =
    let b = Buffer.create 80 in
    String.iter (fun c ->
      if c = '\t' then
        Buffer.add_string b (String.make (8 - (Buffer.length b mod 8)) ' ')
      else Buffer.add_char b c) l;
    Buffer.contents b in
  let n = String.length s in
  let s = if n > 0 && s.[n - 1] = '\n' then String.sub s 0 (n - 1) else s in
  if s = "" then [] else List.map untab (String.split_on_char '\n' s)

let rec last n l =
  if n <= 0 then [] else if List.length l > n then last n (List.tl l) else l

(* the panes: the registers (without r's line of the pc), the
 * instructions around the pc (=> at it, * at a breakpoint), the
 * backtrace (its first 5 frames) *)
let panes p =
  match p.pc with
  | None -> [ "(no process)" ]
  | Some at ->
    let r = lines (text (fun () -> show_registers p)) in
    let r = List.filteri (fun i _ -> i < List.length r - 1) r in
    let code =
      List.init 6 (fun k ->
        let a = at + (4 * (k - 1)) in
        String.concat ""
          (lines ((if a = at then "=> "
                   else if List.mem a p.stops then " * " else "   ")
                  ^ listing p a))) in
    let bt = List.filteri (fun i _ -> i < 5) (lines (text (fun () -> backtrace p))) in
    r @ [ "" ] @ code @ [ "" ] @ bt

(* what was said since, to the log, and the panes made again *)
let out = Buffer.create 1024
let shown p m =
  let said = lines (Buffer.contents out) in
  Buffer.clear out;
  { m with log = last 100 (m.log @ said); panes = panes p }

(* a command run, said in the log first *)
let run_command p c m =
  say ("> " ^ c ^ "\n");
  ignore (command p c);
  shown p m

(* the picture: the ground, the buttons, the panes, the log's last
 * lines that fit, the command typed *)
let picture m =
  let rows = (m.h - 36) / 16 in
  let top = m.panes @ [ "" ] in
  let all =
    top @ last (rows - List.length top - 1) m.log @ [ "> " ^ m.cmd ^ "_" ] in
  P.Rect (255, m.w, m.h)
  :: m.bar
  @ List.mapi (fun i l -> P.Move (4, 34 + (16 * i), P.Words (0, l))) all

(* a key: Escape quits, Return runs the command (q quits), s, n and c
 * run at once when nothing is typed; a click on a button its command *)
let typed p (k : P.key) m =
  match k with
  | P.Escape -> None
  | P.Enter ->
      if m.cmd = "q" then None
      else Some (run_command p m.cmd { m with cmd = "" })
  | P.Backspace ->
      Some { m with cmd =
               (if m.cmd = "" then ""
                else String.sub m.cmd 0 (String.length m.cmd - 1)) }
  | P.Char ('s' | 'n' | 'c' as c) when m.cmd = "" ->
      Some (run_command p (String.make 1 c) m)
  | P.Char c when c >= ' ' && c < '\127' ->
      Some { m with cmd = m.cmd ^ String.make 1 c }
  | _ -> Some m
let moved p x y b m =
  let pressed =
    if b = 0 || m.held <> 0 then []
    else List.filter (fun (box, _) -> GUI.inside x y box) m.boxes in
  match pressed with
  | (_, GUI.Send "q") :: _ -> None
  | (_, GUI.Send c) :: _ -> Some (run_command p c { m with held = b })
  | _ -> Some { m with held = b }

let window caps p =
  let first w h =
    let bar, boxes =
      GUI.place 0 0 w 28
        (GUI.Row [
           GUI.Button ("step", "s"); GUI.Button ("next", "n");
           GUI.Button ("continue", "c");
           GUI.Button ("quit", "q") ])
    in
    shown p { log = []; cmd = ""; panes = []; held = 0; w = w; h = h;
              bar = bar; boxes = boxes } in
  GUI.run_canvas caps
    { first = first; picture = picture; typed = typed p; moved = moved p }

(*****************************************************************************)
(* The main *)
(*****************************************************************************)

let main caps argv =
  saying := (fun s -> TSys.print caps s; TSys.flush caps);
  let n = Array.length argv in
  let windowed = n > 1 && argv.(1) = "-window" in
  let first = if windowed then 2 else 1 in
  if n <= first then begin
    say "usage: debug [-window] prog [args] | debug [-window] pid [prog]\n";
    Exit.Code 1
  end
  else
  let file prog = Fpath.v (if String.contains prog '/' then prog else "/bin/" ^ prog) in
  (* in a window, the program's output and errors on a pipe: where to
   * read, where to write *)
  let pipe = if windowed then Some (TSys.pipe caps) else None in
  let pid, started, funcs =
    match int_of_string_opt argv.(first) with
    | Some pid ->
        pid, false,
        (if n > first + 1 then symbols caps (file argv.(first + 1))
         else Array.of_list [])
    | None ->
        let prog = argv.(first) in
        let funcs = symbols caps (file prog) in
        (match TSys.fork caps with
         | None ->
             (match pipe with
              | Some (r, w) ->
                  TSys.dup2 w TSys.fd_stdout;
                  TSys.dup2 w TSys.fd_stderr;
                  TSys.close w;
                  TSys.close r
              | None -> ());
             ignore (u_trace 0);
             ignore (TSys.exec caps (file prog)
                       (List.init (n - first) (fun i -> argv.(i + first))) []);
             say ("debug: " ^ prog ^ ": not found\n");
             (* the child's end, out of the parent's code: the status
              * TinyLibSystem.main gives the system *)
             raise (Exit.ExitCode 127)
         | Some pid -> pid, true, funcs) in
  let output =
    match pipe with
    | Some (r, w) ->
        TSys.close w;
        if started then Some r else (TSys.close r; None)
    | None -> None in
  if windowed then saying := Buffer.add_string out;
  (* (a program not found: its child said so, in the window's case on
   * the pipe, read into what is said) *)
  let fail () =
    TSys.print caps (Buffer.contents out); TSys.flush caps; Exit.Code 1 in
  let trace = u_trace pid in
  if trace < 0 then begin
    if not started then say ("debug: " ^ argv.(first) ^ ": no such process\n");
    fail ()
  end
  else
  let p = { trace; funcs; pc = None; stops = []; output } in
  if started && not (wait p) then fail ()
  else begin
    (* the process killed if debug started it and it still runs *)
    let quit = if windowed then (window caps p; true) else not (loop p) in
    if quit && started then ignore (TSys.kill caps pid);
    if started then ignore (TSys.wait_any caps);
    Exit.OK
  end
