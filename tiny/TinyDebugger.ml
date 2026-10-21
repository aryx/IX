(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyDebugger.mli *)

open TinyCalls
open TinyLibPlayground
open TinyLibGUI
open TinyMachineISA

(* what debug says: on its output, or kept for the window *)
let sink = ref None
let say s =
  match !sink with
  | Some b -> Buffer.add_string b s
  | None -> ignore (u_write 1 s)

(* what f says, as a string *)
let text f =
  let was = !sink in
  let b = Buffer.create 256 in
  sink := Some b;
  f ();
  sink := was;
  Buffer.contents b

(* the process, the trace's descriptor, where the process is (-1:
 * running), whether debug started it, its breakpoints *)
let pid = ref 0
let t = ref (-1)
let pc = ref (-1)
let started = ref false
let stops = ref []

(* the program's labels, by address, from its file: after the image,
 * whose size the header says *)
let funcs = ref (Array.of_list [])
let symbols file =
  let fd = u_open file 0 in
  if fd >= 0 then begin
    let h = u_read fd 12 in
    let word i =
      Char.code h.[i] + (Char.code h.[i + 1] lsl 8)
      + (Char.code h.[i + 2] lsl 16) + (Char.code h.[i + 3] lsl 24) in
    if String.length h = 12 && word 0 = 0x7a0ce5
       && u_seek fd (12 + word 4) 0 >= 0 then begin
      let rec rest acc =
        let s = u_read fd 4096 in
        if s = "" then String.concat "" (List.rev acc) else rest (s :: acc) in
      funcs := TinyLibSymbols.labels (rest [])
    end;
    ignore (u_close fd)
  end

(* the next line of the trace, and a command and its answer ("" when
 * the kernel refused it). In a window, the program's output is read
 * meanwhile, before its stops (its pipe never full) *)
let output = ref (-1)
let rec next () =
  let fds = Array.make 2 !output in
  fds.(1) <- !t;
  if !output >= 0 && u_ready fds 2 0 = !output then begin
    let s = u_read !output 512 in
    if s = "" then (ignore (u_close !output); output := -1) else say s;
    next ()
  end
  else
  let s = u_read !t 4096 in
  let n = String.length s in
  if n > 0 && s.[n - 1] = '\n' then String.sub s 0 (n - 1) else s
let ask c = if u_write !t c < 0 then "" else next ()

let hex a = if a < 0 then string_of_int a else hex a

(* n bytes of the process at a, from the kernel's hexadecimal ("" when
 * outside it) *)
let bytes a n =
  let h = ask ("m " ^ string_of_int a ^ " " ^ string_of_int n) in
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
let instr s i =
  if Char.code s.[i + 3] >= 0x40 then None
  else
    decode
      (Char.code s.[i] + (Char.code s.[i + 1] lsl 8)
       + (Char.code s.[i + 2] lsl 16) + (Char.code s.[i + 3] lsl 24))

(* an address by its function, main+0x14 (in hexadecimal when there is
 * none) *)
let name a =
  match TinyLibSymbols.find !funcs a with
  | Some (f, b) when a = b -> f
  | Some (f, b) -> f ^ "+" ^ hex (a - b)
  | None -> Printf.sprintf "%x" a

(* the instruction at a, as tiny-cpu -l lists it, by its function *)
let listing a =
  let s = bytes a 4 in
  let text =
    if String.length s < 4 then "?"
    else
      match instr s 0 with
      | Some i ->
          (* a jump's or a branch's target named, at a function's start *)
          let target =
            match i with
            | Jal (_, off) -> a + 4 + (4 * off)
            | Branch (_, _, _, off) -> a + 4 + (4 * off)
            | _ -> -1 in
          print a i
          ^ (match TinyLibSymbols.find !funcs target with
             | Some (f, b) when b = target -> " <" ^ f ^ ">"
             | _ -> "")
      | None -> ".word\t0x" ^ digits s 0 in
  name a ^ ":\t" ^ text ^ "\n"

(* the next stop, and why (None when the process ended, said); a stop
 * said; the next stop said, false when the process ended *)
let stopped () =
  match String.split_on_char ' ' (next ()) with
  | "stopped" :: p :: why -> pc := int_of_string p; Some why
  | "exited" :: rest -> say ("exited " ^ String.concat " " rest ^ "\n"); None
  | _ -> say "the trace ended\n"; None
let show why =
  (match why with
   | [ "step" ] -> ()
   | [ "fault"; a ] -> say ("fault at " ^ hex (int_of_string a) ^ "\n")
   | [ "illegal"; w ] -> say ("illegal " ^ hex (int_of_string w) ^ "\n")
   | _ -> say (String.concat " " why ^ "\n"));
  say (listing !pc)
let wait () = match stopped () with Some why -> show why; true | None -> false

(* an address typed: a number, pc, a function's name and maybe +n *)
let address s =
  let at base =
    if base = "pc" then (if !pc >= 0 then Some !pc else None)
    else
      match int_of_string_opt base with
      | Some a -> Some a
      | None -> TinyLibSymbols.address !funcs base in
  match String.index_opt s '+' with
  | Some i ->
      (match at (String.sub s 0 i),
             int_of_string_opt (String.sub s (i + 1) (String.length s - i - 1))
       with
       | Some a, Some k -> Some (a + k)
       | _ -> None)
  | None -> at s

let ok s = if s <> "ok" then say "?\n"

(* the registers, as the kernel says them: r1 v ... r15 v pc v *)
let regs () =
  let rec pairs l =
    match l with
    | n :: v :: rest ->
        (match int_of_string_opt v with
         | Some v -> (n, v) :: pairs rest
         | None -> [])
    | _ -> [] in
  pairs (String.split_on_char ' ' (ask "r"))
let reg name = match List.assoc_opt name (regs ()) with Some v -> v | None -> 0

(* c, s and n; false when the process ended *)
let continue () =
  if !pc >= 0 then (ignore (u_write !t "c"); pc := -1);
  wait ()
let step () =
  if !pc < 0 then (say "?\n"; true)
  else (ignore (u_write !t "s"); pc := -1; wait ())
let over () =
  let s = bytes !pc 4 in
  let call =
    String.length s = 4
    && (match instr s 0 with
        | Some (Jal (d, _)) -> d = lr
        | Some (Jalr (d, _, _)) -> d = lr
        | _ -> false) in
  if not call then step ()
  else begin
    (* the breakpoint after the call, a stop there not said; in a
     * recursive function the call's own return is told by its sp, the
     * same as at the call: one with a lower sp is a deeper call's, run
     * past *)
    let a = !pc + 4 and sp = reg "r14" in
    let mine = not (List.mem a !stops) in
    if mine then ok (ask ("b " ^ string_of_int a));
    let rec go () =
      ignore (u_write !t "c");
      pc := -1;
      match stopped () with
      | Some [ "break" ] when !pc = a && reg "r14" < sp -> go ()
      | Some [ "break" ] when !pc = a -> say (listing !pc); true
      | Some why -> show why; true
      | None -> false in
    let alive = go () in
    if alive && mine then ok (ask ("d " ^ string_of_int a));
    alive
  end


(* a word of the process, an address or an instruction: under 2^30 *)
let word a =
  let s = bytes a 4 in
  if String.length s < 4 || Char.code s.[3] >= 0x40 then None
  else
    Some (Char.code s.[0] + (Char.code s.[1] lsl 8)
          + (Char.code s.[2] lsl 16) + (Char.code s.[3] lsl 24))

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
  else if b 3 < 0x40 then
    hex (b 0 + (b 1 lsl 8) + (b 2 lsl 16) + (b 3 lsl 24))
  else "0x" ^ digits s i

(* an ML function's slots, the f bytes from v: its closure's (slot 0)
 * left out, then its parameters, its variables, its spills (six at
 * most) *)
let slots v f =
  let s = bytes v f in
  let n = min (String.length s / 4) 7 in
  String.concat " " (List.init (max 0 (n - 1)) (fun k -> value s (4 * (k + 1))))
  ^ (if f / 4 > 7 then " ..." else "")

(* bt: the frames, from the pc's, by the code itself. tiny-c's and
 * tiny-ml's functions all start with addi sp, sp, -f and stw lr, k(sp):
 * a frame is f bytes, its return address at k(sp). Before those two
 * instructions have run, the return address is still in lr, the frame
 * not yet made (the first frame alone can be there); a function without
 * them (assembly: write, _start) keeps it in lr, and ends the walk
 * after the first frame. A tail call's frame is gone: the frames are
 * the callers that will be returned to. Each line is the call's place
 * (the return address less 4).
 *
 * An ML function's third instruction is addi r12, r12, v: its frame on
 * the value stack, v bytes below r12 (TinyML.ml's machine). Its slots
 * follow its name; the frames above start v lower. The first ML frame
 * is r12's when the pc is in ML, else ml_vsp's (where ML leaves r12
 * when it calls C) *)
let backtrace () =
  let r = regs () in
  let reg n = match List.assoc_opt n r with Some v -> v | None -> 0 in
  let ml b =
    match word (b + 8) with
    | Some w ->
        (match decode w with
         | Some (Alui (Add, 12, 12, v)) when v > 0 -> v
         | _ -> 0)
    | None -> 0 in
  let start pc =
    match TinyLibSymbols.find !funcs pc with Some (_, b) -> b | None -> -1 in
  let rec go k pc sp vsp =
    let b = start pc in
    let v = if b >= 0 then ml b else 0 in
    let shown = v > 0 && (k > 0 || pc >= b + 12) in
    say (string_of_int k ^ "\t" ^ name pc
         ^ (if shown then "\t" ^ slots (vsp - v) v else "") ^ "\n");
    let vsp = if shown then vsp - v else vsp in
    let frame =
      match TinyLibSymbols.find !funcs pc with
      | None -> None
      | Some (_, b) ->
          match word b, word (b + 4) with
          | Some w1, Some w2 ->
              (match decode w1, decode w2 with
               | Some (Alui (Add, 14, 14, f)), Some (Store (W, 15, 14, off))
                 when f < 0 ->
                   if pc = b then (if k = 0 then Some (reg "r15", sp) else None)
                   else if pc = b + 4 then
                     (if k = 0 then Some (reg "r15", sp - f) else None)
                   else
                     (match word (sp + off) with
                      | Some ret -> Some (ret, sp - f)
                      | None -> None)
               | _ -> if k = 0 then Some (reg "r15", sp) else None)
          | _ -> None in
    match frame with
    | Some (ret, sp) when ret > 0 && k < 64 -> go (k + 1) (ret - 4) sp vsp
    | _ -> () in
  if !pc < 0 then say "?\n"
  else begin
    let b = start !pc in
    let vsp =
      if b >= 0 && ml b > 0 then reg "r12"
      else
        match TinyLibSymbols.address !funcs "ml_vsp" with
        | Some a -> (match word a with Some v -> v | None -> 0)
        | None -> 0 in
    go 0 !pc (reg "r14") vsp
  end

(* the registers, four a line in columns, and the instruction at the pc *)
let registers () =
  let rec go l k =
    match l with
    | name :: v :: rest when name <> "pc" ->
        let r = name ^ " " ^ hex (int_of_string v) in
        say (if k mod 4 = 3 then r ^ "\n"
             else r ^ String.make (max 1 (16 - String.length r)) ' ');
        go rest (k + 1)
    | [ "pc"; v ] ->
        say ((if k mod 4 = 0 then "" else "\n") ^ listing (int_of_string v))
    | _ -> say "?\n" in
  go (String.split_on_char ' ' (ask "r")) 0

(* x: n words, four a line; x/i: n instructions *)
let words a n =
  let s = bytes a (4 * n) in
  if String.length s < 4 * n then say "?\n"
  else
    for k = 0 to n - 1 do
      if k mod 4 = 0 then say (Printf.sprintf "%x:" (a + (4 * k)));
      say ("\t" ^ digits s (4 * k));
      if k mod 4 = 3 || k = n - 1 then say "\n"
    done
let instructions a n = for k = 0 to n - 1 do say (listing (a + (4 * k))) done

(* x and x/i's n words or instructions at a *)
let examine show a rest =
  match address a, rest with
  | Some a, [] -> show a 1
  | Some a, [ n ] ->
      (match int_of_string_opt n with
       | Some n when n > 0 && n <= 256 -> show a n
       | _ -> say "?\n")
  | _ -> say "?\n"

(* a command; false to quit *)
let command line =
  match List.filter (fun w -> w <> "") (String.split_on_char ' ' line) with
  | [] -> true
  | [ "b"; a ] ->
      (match address a with
       | Some a when ask ("b " ^ string_of_int a) = "ok" -> stops := a :: !stops
       | _ -> say "?\n");
      true
  | [ "d"; a ] ->
      (match address a with
       | Some a ->
           ok (ask ("d " ^ string_of_int a));
           stops := List.filter (fun b -> b <> a) !stops
       | None -> say "?\n");
      true
  | [ "c" ] -> continue ()
  | [ "s" ] -> step ()
  | [ "n" ] -> if !pc < 0 then (say "?\n"; true) else over ()
  | [ "r" ] -> registers (); true
  | [ "bt" ] -> backtrace (); true
  | "x" :: a :: rest -> examine words a rest; true
  | "x/i" :: a :: rest -> examine instructions a rest; true
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
      let s = u_read 0 4096 in
      if s = "" then None else (pending := !pending ^ s; read_line ())
let rec loop () =
  match read_line () with
  | Some l -> if command l then loop () else false
  | None -> false

(*****************************************************************************)
(* The window *)
(*****************************************************************************)

(* the window's model: what was said, its lines (the last 100); the
 * command typed; the panes, made after each command; the mouse's
 * buttons as last seen; the window's size, and its buttons' shapes and
 * boxes, each with its command *)
type model = {
  log : string list; cmd : string; panes : string list; held : int;
  w : int; h : int; bar : shape list;
  boxes : ((int * int * int * int) * string action) list;
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
let panes () =
  if !pc < 0 then [ "(no process)" ]
  else begin
    let r = lines (text registers) in
    let r = List.filteri (fun i _ -> i < List.length r - 1) r in
    let code =
      List.init 6 (fun k ->
        let a = !pc + (4 * (k - 1)) in
        String.concat ""
          (lines ((if a = !pc then "=> "
                   else if List.mem a !stops then " * " else "   ")
                  ^ listing a))) in
    let bt = List.filteri (fun i _ -> i < 5) (lines (text backtrace)) in
    r @ [ "" ] @ code @ [ "" ] @ bt
  end

(* what was said since, to the log, and the panes made again *)
let out = Buffer.create 1024
let shown m =
  let said = lines (Buffer.contents out) in
  Buffer.clear out;
  { m with log = last 100 (m.log @ said); panes = panes () }

(* a command run, said in the log first *)
let run_command c m =
  say ("> " ^ c ^ "\n");
  ignore (command c);
  shown m

(* the picture: the ground, the buttons, the panes, the log's last
 * lines that fit, the command typed *)
let picture m =
  let rows = (m.h - 36) / 16 in
  let top = m.panes @ [ "" ] in
  let all =
    top @ last (rows - List.length top - 1) m.log @ [ "> " ^ m.cmd ^ "_" ] in
  Rect (255, m.w, m.h)
  :: m.bar
  @ List.mapi (fun i l ->
      Move (4, 34 + (16 * i), Words (0, l)))
      all

(* a key: Escape quits, Return runs the command (q quits), s, n and c
 * run at once when nothing is typed; a click on a button its command *)
let typed k m =
  if k = 27 then None
  else if k = 13 || k = 10 then
    (if m.cmd = "q" then None else Some (run_command m.cmd { m with cmd = "" }))
  else if k = 8 || k = 127 then
    Some { m with cmd =
             (if m.cmd = "" then ""
              else String.sub m.cmd 0 (String.length m.cmd - 1)) }
  else if m.cmd = "" && (k = 115 || k = 110 || k = 99) then
    Some (run_command (String.make 1 (Char.chr k)) m)
  else if k >= 32 && k < 127 then
    Some { m with cmd = m.cmd ^ String.make 1 (Char.chr k) }
  else Some m
let moved x y b m =
  let pressed =
    if b = 0 || m.held <> 0 then []
    else List.filter (fun (box, _) -> inside x y box) m.boxes in
  match pressed with
  | (_, Send "q") :: _ -> None
  | (_, Send c) :: _ -> Some (run_command c { m with held = b })
  | _ -> Some { m with held = b }

let window () =
  let first w h =
    let bar, boxes =
      place 0 0 w 28
        (Row [
           Button ("step", "s"); Button ("next", "n");
           Button ("continue", "c");
           Button ("quit", "q") ])
    in
    shown { log = []; cmd = ""; panes = []; held = 0; w = w; h = h; bar = bar;
            boxes = boxes } in
  run_canvas
    { first = first; picture = picture; typed = typed; moved = moved }

let main () =
  let n = u_argc () in
  let windowed = n > 1 && u_arg 1 = "-window" in
  let first = if windowed then 2 else 1 in
  if n <= first then
    (say "usage: debug [-window] prog [args] | debug [-window] pid [prog]\n";
     exit 1);
  let file prog = if String.contains prog '/' then prog else "/bin/" ^ prog in
  (* in a window, the program's output and errors on a pipe *)
  let pipe = if windowed then u_pipe () else -1 in
  (match int_of_string_opt (u_arg first) with
   | Some p ->
       pid := p;
       if n > first + 1 then symbols (file (u_arg (first + 1)))
   | None ->
       let prog = u_arg first in
       let file = file prog in
       symbols file;
       let p = u_fork () in
       if p = 0 then begin
         if pipe >= 0 then begin
           List.iter (fun fd ->
             ignore (u_close fd); ignore (u_dup (pipe / 256))) [ 1; 2 ];
           ignore (u_close (pipe / 256));
           ignore (u_close (pipe mod 256))
         end;
         ignore (u_trace 0);
         ignore (u_exec file
                   (List.init (n - first) (fun i -> u_arg (i + first))));
         say ("debug: " ^ prog ^ ": not found\n");
         exit 127
       end;
       pid := p;
       started := true);
  if pipe >= 0 then begin
    ignore (u_close (pipe / 256));
    if !started then output := pipe mod 256
    else ignore (u_close (pipe mod 256))
  end;
  if windowed then sink := Some out;
  t := u_trace !pid;
  if !t < 0 && not !started then
    (say ("debug: " ^ u_arg first ^ ": no such process\n"); exit 1);
  (* (a program not found: its child said so, in the window's case on
   * the pipe, read into what is said) *)
  if !t < 0 || (!started && not (wait ())) then begin
    ignore (u_write 1 (Buffer.contents out));
    exit 1
  end;
  (* the process killed if debug started it and it still runs *)
  let quit = if windowed then (window (); true) else not (loop ()) in
  if quit && !started then ignore (u_kill !pid);
  if !started then ignore (u_waits ());
  exit 0
