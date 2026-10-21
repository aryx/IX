(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* debug, a debugger for tiny-kernel's programs, at the level of their
 * instructions (plan_tiny_debugger.md; Plan 9's db). It starts its
 * program stopped at its first instruction (a child that calls
 * trace(0), then exec), or attaches to a process by its pid, and
 * controls it through the kernel's trace descriptor: commands written,
 * lines read (TinyKernel.ml's command). Its own commands are typed as
 * ed's, a letter and its arguments, the numbers in hexadecimal (0x1a4)
 * or decimal, pc for the pc:
 *
 *     b addr        a breakpoint          d addr   one removed
 *     c             continue              s        one instruction
 *     n             one instruction, over a call (jal or jalr to lr)
 *     r             the registers, and the instruction at the pc
 *     x addr [n]    n words               x/i addr [n]  instructions
 *     q             quit (the program killed, or left to run if attached)
 *
 * At each stop it shows why, and the instruction at the pc. No names
 * yet: tiny-linker's labels are not in the program's file (the plan's
 * step 4).
 *
 *     debug cat f
 *     debug 12 *)
open TinyCalls
open TinyMachineISA

let say s = ignore (u_write 1 s)

(* the process, the trace's descriptor, where the process is (-1:
 * running), whether debug started it, its breakpoints *)
let pid = ref 0
let t = ref (-1)
let pc = ref (-1)
let started = ref false
let stops = ref []

(* the next line of the trace, and a command and its answer ("" when
 * the kernel refused it) *)
let next () =
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

(* the instruction at a, as tiny-cpu -l lists it *)
let listing a =
  let s = bytes a 4 in
  let text =
    if String.length s < 4 then "?"
    else
      match instr s 0 with
      | Some i -> print a i
      | None -> ".word\t0x" ^ digits s 0 in
  Printf.sprintf "%x:\t%s\n" a text

(* the next stop said (but n's breakpoint, after its call); false when
 * the process ended *)
let after = ref (-1)
let wait () =
  match String.split_on_char ' ' (next ()) with
  | "stopped" :: p :: why ->
      pc := int_of_string p;
      (match why with
       | [ "step" ] -> ()
       | [ "break" ] when !pc = !after -> ()
       | [ "fault"; a ] -> say ("fault at " ^ hex (int_of_string a) ^ "\n")
       | [ "illegal"; w ] -> say ("illegal " ^ hex (int_of_string w) ^ "\n")
       | _ -> say (String.concat " " why ^ "\n"));
      say (listing !pc);
      true
  | "exited" :: rest -> say ("exited " ^ String.concat " " rest ^ "\n"); false
  | _ -> say "the trace ended\n"; false

(* an address typed, or pc *)
let address s =
  if s = "pc" && !pc >= 0 then Some !pc else int_of_string_opt s

let ok s = if s <> "ok" then say "?\n"

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
    let a = !pc + 4 in
    let mine = not (List.mem a !stops) in
    if mine then ok (ask ("b " ^ string_of_int a));
    after := a;
    let alive = continue () in
    after := -1;
    if alive && mine then ok (ask ("d " ^ string_of_int a));
    alive
  end

(* the registers, four a line, and the instruction at the pc *)
let registers () =
  let rec go l k =
    match l with
    | name :: v :: rest when name <> "pc" ->
        say ((if k mod 4 = 0 then "" else "  ") ^ name ^ " "
             ^ hex (int_of_string v) ^ (if k mod 4 = 3 then "\n" else ""));
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

let () =
  let n = u_argc () in
  if n < 2 then (say "usage: debug prog [args] | debug pid\n"; exit 1);
  (match int_of_string_opt (u_arg 1) with
   | Some p -> pid := p
   | None ->
       let prog = u_arg 1 in
       let file = if String.contains prog '/' then prog else "/bin/" ^ prog in
       let p = u_fork () in
       if p = 0 then begin
         ignore (u_trace 0);
         ignore (u_exec file (List.init (n - 1) (fun i -> u_arg (i + 1))));
         say ("debug: " ^ prog ^ ": not found\n");
         exit 127
       end;
       pid := p;
       started := true);
  t := u_trace !pid;
  if !t < 0 && not !started then
    (say ("debug: " ^ u_arg 1 ^ ": no such process\n"); exit 1);
  (* (a program not found: its child said so) *)
  if !t < 0 || (!started && not (wait ())) then exit 1;
  (* the process killed if debug started it and it still runs *)
  if not (loop ()) && !started then ignore (u_kill !pid);
  if !started then ignore (u_waits ());
  exit 0
