(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyTracer.mli *)

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

(* the process whose stop is handled and its trace's descriptor; the
 * next line read, and a command and its answer ("" when the kernel
 * refused it: an address outside the process) *)
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

(* The stops, until the processes' end: before a call, its line is
 * made (its paths are read then: an exec's is gone after it); after,
 * said with its result, and the bytes the call filled. A stop for
 * another reason, a fault, is said and the process killed. The
 * processes traced: each its pid, its descriptor, and the call it is
 * in (its number, its arguments and its line made before it) *)
let fills n =
  n < Array.length calls
  && List.exists (fun k -> match k with Filled -> true | _ -> false)
       (snd calls.(n))
type traced = {
  tpid : int; fd : int; mutable pending : (int * int list * string) option;
}
let procs = ref []
let children = ref false
let say_of s =
  say ((if !children then "[" ^ string_of_int !pid ^ "] " else "") ^ s ^ "\n")

(* a stop of the process p, read from its descriptor; false when it
 * ended *)
let handle p =
  pid := p.tpid;
  t := p.fd;
  let s = next () in
  let num = int_of_string in
  let go on = p.pending <- on; tell "c"; true in
  match String.split_on_char ' ' s, p.pending with
  | [ "" ], _ -> false
  | [ "call"; "0"; a; _; _ ], _ -> say_of ("exit(" ^ a ^ ")"); go None
  | [ "call"; n; a1; a2; a3 ], _ ->
      let n = num n and args = [ num a1; num a2; num a3 ] in
      go (Some (n, args, line n args (-1)))
  | [ "ret"; n; r ], Some (_, args, text) ->
      let n = num n and r = num r in
      say_of ((if fills n then line n args r else text) ^ " = "
              ^ string_of_int r);
      (* a child forked: traced from its first call, which waits for it *)
      if n = 3 && r > 0 && !children then begin
        let fd = u_trace r in
        if fd >= 0 then
          procs := !procs @ [ { tpid = r; fd = fd; pending = None } ]
      end;
      go None
  | [ "stopped"; _; "exec" ], Some (_, _, text) ->
      say_of (text ^ " = 0"); go None
  | "exited" :: rest, _ -> say_of ("exited " ^ String.concat " " rest); false
  | "stopped" :: pc :: why, _ ->
      say_of ("stopped at " ^ hex (num pc) ^ ": " ^ String.concat " " why);
      ignore (u_kill p.tpid); go None
  | _ -> say_of ("trace: " ^ s); go None

(* the stops of all the processes, the first one ready first, until
 * none is left *)
let rec follow () =
  match !procs with
  | [] -> ()
  | l ->
      let fds = Array.of_list (List.map (fun p -> p.fd) l) in
      let k = u_ready fds (Array.length fds) 0 in
      (match List.filter (fun p -> p.fd = k) l with
       | [ p ] ->
           if not (handle p) then begin
             ignore (u_close p.fd);
             procs := List.filter (fun q -> q.fd <> p.fd) !procs
           end
       | _ -> procs := []);
      follow ()

let main () =
  let n = u_argc () in
  let first = if n > 1 && u_arg 1 = "-f" then 2 else 1 in
  children := first = 2;
  if n <= first then (say "usage: trace [-f] prog [args] | trace [-f] pid\n";
                      exit 1);
  let p, started =
    match int_of_string_opt (u_arg first) with
    | Some p -> p, false
    | None ->
        let prog = u_arg first in
        let file = if String.contains prog '/' then prog else "/bin/" ^ prog in
        let pid = u_fork () in
        if pid = 0 then begin
          ignore (u_trace 0);
          ignore (u_exec file
                    (List.init (n - first) (fun i -> u_arg (i + first))));
          say ("trace: " ^ prog ^ ": not found\n");
          exit 127
        end;
        pid, true in
  pid := p;
  t := u_trace p;
  (* (a program not found: its child said so) *)
  if started && (!t < 0 || next () <> "stopped 0 exec") then exit 1;
  if !t < 0 then
    (say ("trace: " ^ u_arg first ^ ": no such process\n"); exit 1);
  ignore (ask "y");
  if !children then ignore (ask "f");
  if started then tell "c";
  procs := [ { tpid = p; fd = !t; pending = None } ];
  follow ();
  if started then ignore (u_waits ());
  exit 0
