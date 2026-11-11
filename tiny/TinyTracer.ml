(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyTracer.mli *)

module TSys = TinyLibSystem

(* the kernel's trace of a process, a descriptor (-1 refused): tiny-kernel's
 * alone, no other system's, so not TinyLibSystem's (mlsys.c's u_trace) *)
external u_trace : TSys.pid -> TSys.fd = "u_trace"

(* written, a refusal not a reason to end *)
let put fd s = try TSys.write fd s with Failure _ -> ()
let say s = put TSys.fd_stderr s

(*****************************************************************************)
(* The calls *)
(*****************************************************************************)

(* the calls, by their numbers (TinyKernel.ml's syscall, sys.tm's
 * order), and the kind of each argument: a number, a path, bytes
 * given (their length the next argument), bytes filled (as many as
 * the result says), an address.
 * coupling: TinyKernel/libc/user.h, its prototypes the arguments'
 * kinds (a char* a path or bytes, an int* or char** an address), and
 * TinyKernel/libc/sys.tm, its sys n each call's index here; a call
 * added to the kernel is added in the three places *)
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
    "seek", [ Num; Num; Num ]; "time", []; "stat", [ Path; Addr ]; "seed", [];
    "spawn", [ Path; Addr ] ]

(* a call's name by its number ("" for none) *)
let call_name n =
  if n < 0 || n >= Array.length calls then "" else fst calls.(n)

(* whether the call fills bytes, shown after it returns *)
let fills n =
  n >= 0 && n < Array.length calls
  && List.exists (fun k -> match k with Filled -> true | _ -> false)
       (snd calls.(n))

(*****************************************************************************)
(* The processes *)
(*****************************************************************************)

(* A process traced: its pid, the kernel's trace of it, and the call it
 * is in, its arguments and its line made before it ran (old: a triple,
 * the call's number too; the process whose stop was handled and its
 * descriptor globals, -1 for none) *)
type call = { args : int list; text : string }
type traced = { pid : TSys.pid; trace : TSys.fd; mutable call : call option }

(* the next line of p's trace, and a command and its answer ("" when
 * the kernel refused it: an address outside the process) *)
let next (p : traced) =
  let s = TSys.read p.trace 4096 in
  let n = String.length s in
  if n > 0 && s.[n - 1] = '\n' then String.sub s 0 (n - 1) else s
let ask p c =
  if (try TSys.write p.trace c; true with Failure _ -> false) then next p
  else ""

(* n bytes of the process at a, from the kernel's hexadecimal *)
let bytes p a n =
  let h = ask p ("m " ^ string_of_int a ^ " " ^ string_of_int n) in
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
let path p a =
  let rec go a k acc =
    let s = bytes p a k in
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
 * bytes it fills shown after it returns (r, its result; None before) *)
let line p n args (r : int option) =
  if call_name n = "" then "sys" ^ string_of_int n ^ "(...)"
  else begin
    let name, kinds = calls.(n) in
    let rec go kinds args =
      match kinds, args with
      | Given :: rest, a :: (k :: _ as more) ->
          quoted (bytes p a (min k 33)) :: go rest more
      | Filled :: rest, a :: more ->
          (match r with
           | Some r when r >= 0 -> quoted (bytes p a (min r 33))
           | _ -> hex a)
          :: go rest more
      | Path :: rest, a :: more -> path p a :: go rest more
      | Addr :: rest, a :: more -> hex a :: go rest more
      | _ :: rest, a :: more -> string_of_int a :: go rest more
      | _ -> [] in
    name ^ "(" ^ String.concat ", " (go kinds args) ^ ")"
  end

(*****************************************************************************)
(* The stops *)
(*****************************************************************************)

(* A line of the trace, once main's y asked the kernel to stop at each
 * call: TinyKernelCalls' "call n a1 a2 a3" before it, always three
 * arguments whatever the call takes, and "ret n r" after. An exec that
 * works never returns, so a stop at exec comes in place of its ret.
 * Ended is the empty read of a trace the kernel closed. *)
type event =
  | Entering of int * int list
  | Returning of int * int
  | Stopped of int * string
  | Exited of string
  | Ended
  | Unknown of string

let event s =
  let num = int_of_string in
  match String.split_on_char ' ' s with
  | [ "" ] -> Ended
  | [ "call"; n; a1; a2; a3 ] -> Entering (num n, [ num a1; num a2; num a3 ])
  | [ "ret"; n; r ] -> Returning (num n, num r)
  | "exited" :: rest -> Exited (String.concat " " rest)
  | "stopped" :: pc :: why -> Stopped (num pc, String.concat " " why)
  | _ -> Unknown s

(* The stops of p, until its end: before a call, its line is made (its
 * paths are read then: an exec's is gone after it); after, said with
 * its result, and the bytes the call filled. A stop for another reason,
 * a fault, is said and the process killed. With -f (children), each
 * line names its process, and a child forked or spawned is traced from
 * its first call, which waits for it. A stop handled: whether p is
 * still traced, and the children it made *)
let handle caps children p : bool * traced list =
  let said s =
    say ((if children then "[" ^ string_of_int p.pid ^ "] " else "") ^ s ^ "\n") in
  let go call = p.call <- call; put p.trace "c" in
  let s = next p in
  match event s, p.call with
  | Ended, _ -> false, []
  | Entering (0, a :: _), _ ->
      said ("exit(" ^ string_of_int a ^ ")"); go None; true, []
  | Entering (n, args), _ ->
      go (Some { args; text = line p n args None }); true, []
  | Returning (n, r), Some c ->
      said ((if fills n then line p n c.args (Some r) else c.text) ^ " = "
            ^ string_of_int r);
      let born =
        match call_name n with
        | "fork" | "spawn" when r > 0 && children ->
            let fd = u_trace r in
            if fd >= 0 then [ { pid = r; trace = fd; call = None } ] else []
        | _ -> [] in
      go None;
      true, born
  | Stopped (_, "exec"), Some c -> said (c.text ^ " = 0"); go None; true, []
  | Exited how, _ -> said ("exited " ^ how); false, []
  | Stopped (pc, why), _ ->
      said ("stopped at " ^ hex pc ^ ": " ^ why);
      ignore (TSys.kill caps p.pid);
      go None;
      true, []
  | Returning _, None | Unknown _, _ ->
      (* (a return with no call before it: the line as it came) *)
      said ("trace: " ^ s); go None; true, []

(* the stops of all the processes, the first one ready first, until
 * none is left *)
let rec follow caps children (procs : traced list) =
  if procs <> [] then
    match TSys.ready (List.map (fun p -> p.trace) procs) None with
    | Some fd ->
        (match List.filter (fun p -> p.trace = fd) procs with
         | [ p ] ->
             let alive, born = handle caps children p in
             if not alive then TSys.close p.trace;
             let left =
               if alive then procs
               else List.filter (fun q -> q.trace <> p.trace) procs in
             follow caps children (left @ born)
         | _ -> ())
    | None -> ()

(*****************************************************************************)
(* The main *)
(*****************************************************************************)

let main caps argv =
  let n = Array.length argv in
  let children = n > 1 && argv.(1) = "-f" in
  let first = if children then 2 else 1 in
  if n <= first then (say "usage: trace [-f] prog [args] | trace [-f] pid\n";
                      exit 1);
  let pid, started =
    match int_of_string_opt argv.(first) with
    | Some pid -> pid, false
    | None ->
        let prog = argv.(first) in
        let file = if String.contains prog '/' then prog else "/bin/" ^ prog in
        (match TSys.fork caps with
         | None ->
             ignore (u_trace 0);
             ignore (TSys.exec caps (Fpath.v file)
                       (List.init (n - first) (fun i -> argv.(i + first))) []);
             say ("trace: " ^ prog ^ ": not found\n");
             exit 127
         | Some pid -> pid, true) in
  let trace = u_trace pid in
  if trace < 0 then begin
    if not started then
      say ("trace: " ^ argv.(first) ^ ": no such process\n");
    exit 1
  end;
  let p = { pid; trace; call = None } in
  (* (a program not found: its child said so) *)
  if started && next p <> "stopped 0 exec" then exit 1;
  ignore (ask p "y");
  if children then ignore (ask p "f");
  if started then put trace "c";
  follow caps children [ p ];
  if started then ignore (TSys.wait_any caps);
  exit 0
