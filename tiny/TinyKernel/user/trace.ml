(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* trace, the system calls of a process as it makes them, a line each
 * on the error output, so that trace prog > f keeps the program's
 * output apart (strace's idea, Plan 9's ratrace; plan_tiny_debugger.md,
 * section 5). It starts its program stopped at its first instruction
 * (a child that calls trace(0), then exec), or attaches to a process
 * by its pid, asks the kernel to stop it before and after each call
 * (y), and at each stop reads what the call's arguments point to (m)
 * and lets it go on (c). A forked child is not followed.
 *
 *     trace cat f
 *     trace 12 *)
open TinyCalls

let say s = ignore (u_write 2 s)

(* the calls, by their numbers (TinyKernel.ml's syscall, user.h's
 * order), and the kind of each argument: a number, a path, bytes
 * given (their length the next argument), bytes filled (as many as
 * the result says), an address *)
type arg = Num | Path | Given | Filled | Addr
let calls =
  Array.of_list [
    "exit", [ Num ]; "write", [ Num; Given; Num ]; "read", [ Num; Filled; Num ];
    "fork", []; "exec", [ Path; Addr ]; "wait", [ Addr ]; "getpid", [];
    "open", [ Path; Num ]; "close", [ Num ]; "pipe", [ Addr ]; "dup", [ Num ];
    "mkdir", [ Path ]; "unlink", [ Path ]; "chdir", [ Path ]; "kill", [ Num ];
    "ready", [ Addr; Num; Num ]; "ticks", []; "box", [ Addr ];
    "dial", [ Path; Num ]; "listen", [ Num ]; "getcwd", [ Filled; Num ];
    "link", [ Path; Path ]; "rawcons", [ Num ]; "trace", [ Num ];
    "seek", [ Num; Num; Num ]; "time", []; "stat", [ Path; Addr ]; "seed", [] ]

(* the process and the trace's descriptor; the next line read, and a
 * command and its answer ("" when the kernel refused it: an address
 * outside the process) *)
let pid = ref 0
let t = ref (-1)
let tell c = ignore (u_write !t c)
let next () =
  let s = u_read !t 4096 in
  let n = String.length s in
  if n > 0 && s.[n - 1] = '\n' then String.sub s 0 (n - 1) else s
let ask c = if u_write !t c < 0 then "" else next ()

(* n bytes of the process at a, from the kernel's hexadecimal *)
let bytes a n =
  let h = ask ("m " ^ string_of_int a ^ " " ^ string_of_int n) in
  let digit c = if c <= '9' then Char.code c - 48 else Char.code c - 87 in
  String.init (String.length h / 2) (fun i ->
    Char.chr ((digit h.[2 * i] * 16) + digit h.[(2 * i) + 1]))

(* bytes as a C string, the first 32 of them *)
let quoted s =
  let b = Buffer.create 40 in
  Buffer.add_char b '"';
  String.iteri (fun i c ->
    if i < 32 then
      match c with
      | '\n' -> Buffer.add_string b "\\n"
      | '\t' -> Buffer.add_string b "\\t"
      | '"' | '\\' -> Buffer.add_char b '\\'; Buffer.add_char b c
      | c when c >= ' ' && c <= '~' -> Buffer.add_char b c
      | c ->
          let d = "0123456789abcdef" in
          Buffer.add_string b "\\x";
          Buffer.add_char b d.[Char.code c / 16];
          Buffer.add_char b d.[Char.code c mod 16]) s;
  Buffer.add_char b '"';
  if String.length s > 32 then Buffer.add_string b "...";
  Buffer.contents b

(* a path, up to its 0, read 64 bytes at a time (fewer at the end of
 * the process's memory) *)
let path a =
  let rec go a k acc =
    let s = bytes a k in
    match String.index_opt s '\000' with
    | Some i -> acc ^ String.sub s 0 i
    | None when s = "" -> if k > 1 then go a 1 acc else acc
    | None when String.length acc > 256 -> acc ^ s
    | None -> go (a + k) k (acc ^ s) in
  quoted (go a 64 "")

let hex a =
  let d = "0123456789abcdef" in
  let rec go a =
    (if a < 16 then "" else go (a / 16)) ^ String.make 1 d.[a mod 16] in
  "0x" ^ go a

(* a call's line without its result: its name and its arguments, the
 * bytes it fills shown after it returns (r, its result; -1 before) *)
let line n args r =
  if n < 0 || n >= Array.length calls then "sys" ^ string_of_int n ^ "(...)"
  else begin
    let name, kinds = calls.(n) in
    let rec go kinds args =
      match kinds, args with
      | Given :: rest, a :: (k :: _ as more) ->
          quoted (bytes a (min k 33)) :: go rest more
      | Filled :: rest, a :: more ->
          (if r < 0 then hex a else quoted (bytes a (min r 33))) :: go rest more
      | Path :: rest, a :: more -> path a :: go rest more
      | Addr :: rest, a :: more -> hex a :: go rest more
      | _ :: rest, a :: more -> string_of_int a :: go rest more
      | _ -> [] in
    name ^ "(" ^ String.concat ", " (go kinds args) ^ ")"
  end

(* the stops, until the process's end: before a call, its line is
 * made (its paths are read then: an exec's is gone after it); after,
 * said with its result, and the bytes the call filled. A stop for
 * another reason, a fault, is said and the process killed *)
let fills n =
  n < Array.length calls
  && List.exists (fun k -> match k with Filled -> true | _ -> false)
       (snd calls.(n))
let rec follow pending =
  let s = next () in
  let num = int_of_string in
  match String.split_on_char ' ' s, pending with
  | [ "" ], _ -> ()
  | [ "call"; "0"; a; _; _ ], _ ->
      say ("exit(" ^ a ^ ")\n"); tell "c"; follow None
  | [ "call"; n; a1; a2; a3 ], _ ->
      let n = num n and args = [ num a1; num a2; num a3 ] in
      let text = line n args (-1) in
      tell "c"; follow (Some (n, args, text))
  | [ "ret"; n; r ], Some (_, args, text) ->
      let n = num n and r = num r in
      say ((if fills n then line n args r else text) ^ " = " ^ string_of_int r
           ^ "\n");
      tell "c"; follow None
  | [ "stopped"; _; "exec" ], Some (_, _, text) ->
      say (text ^ " = 0\n"); tell "c"; follow None
  | "exited" :: rest, _ -> say ("exited " ^ String.concat " " rest ^ "\n")
  | "stopped" :: pc :: why, _ ->
      say ("stopped at " ^ hex (num pc) ^ ": " ^ String.concat " " why ^ "\n");
      ignore (u_kill !pid); follow None
  | _ -> say ("trace: " ^ s ^ "\n"); tell "c"; follow None

let () =
  let n = u_argc () in
  if n < 2 then (say "usage: trace prog [args] | trace pid\n"; exit 1);
  let p, started =
    match int_of_string_opt (u_arg 1) with
    | Some p -> p, false
    | None ->
        let prog = u_arg 1 in
        let file = if String.contains prog '/' then prog else "/bin/" ^ prog in
        let pid = u_fork () in
        if pid = 0 then begin
          ignore (u_trace 0);
          ignore (u_exec file (List.init (n - 1) (fun i -> u_arg (i + 1))));
          say ("trace: " ^ prog ^ ": not found\n");
          exit 127
        end;
        pid, true in
  pid := p;
  t := u_trace p;
  (* (a program not found: its child said so) *)
  if started && (!t < 0 || next () <> "stopped 0 exec") then exit 1;
  if !t < 0 then (say ("trace: " ^ u_arg 1 ^ ": no such process\n"); exit 1);
  ignore (ask "y");
  if started then tell "c";
  follow None;
  if started then ignore (u_waits ());
  exit 0
