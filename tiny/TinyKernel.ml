(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A tiny kernel, in ML, for tiny-machine (TinyMachine.ml): the
 * essential of an operating system, with nothing borrowed from an
 * existing one but ideas. Compiled by tiny-ml -tm (TinyML.ml's second
 * back end), its runtime TinyML's (Cheney's collector, in C by
 * tiny-c -tm), its user programs C (tiny-c -tm, tiny-os's libc):
 *
 *     ./tiny-machine tiny-kernel   (at the top of ix; or make run in TinyKernel/)
 *     $ echo hello | wc; mkdir d; cd d; echo x > f; cd ..; cat d/f; ls
 *     $ mltests
 *
 * Why free. ix's mini-xxx twin an original program; its tiny-xxx keep
 * what is fundamental and drop the rest by what it costs. A kernel
 * seems to ask for a twin, xv6's or 9pi's, for two reasons: it is not
 * a leaf (its system calls are a contract with every program above it,
 * so a new interface means a new userland), and a reference answers
 * the hard questions (what wait returns when, what a dead pipe's
 * reader sees), which has been mini-9pi's and mini-xv6's first
 * debugging tool. But xv6 is tiny for C: locks, a kernel stack per
 * process, an on-disk file system. In ML other roads are shorter, so
 * this one keeps the concepts and chooses each one's how:
 *
 *   concept                    kept how                              why cheap here
 *   user and kernel modes,     a trap returns from k_run; the call   the machine has one way in
 *   system calls               a match on its number                 and one way out
 *   preemptive scheduling      round robin on the timer              a list, the ran one moved last
 *   protection                 tiny-machine's window, relocating:    no page tables to build
 *                              a partition of 1 MB a process
 *   processes                  fork, exec, exit, wait                with a window, fork copies a
 *                                                                    partition: one k_copy
 *   blocking                   a closure per waiting process, the    no kernel stack per process,
 *                              call's rest, retried by the scheduler no swtch, no sleep, no locks
 *   files and directories      a tree of ML values in the heap       no disk format, no mkfs, no
 *                                                                    buffer cache, no log
 *   console, pipes             other kinds of open file              pipes make a shell a shell
 *
 * Dropped: the disk (the files come in the boot image, after the
 * kernel, and live in memory: what a program writes is lost at the
 * halt), pages, several cores, users and permissions, signals (no
 * kill: a fault kills). The system calls are this kernel's own (its
 * programs are in TinyKernel/user/, and tiny-os t6's cat, echo, ls, wc,
 * mkdir and rm run unchanged, as they use only calls in common).
 *
 * Where it sits: ix's Kernel row (README), its tiny program, as mini-9pi
 * is its mini one; not a version of tiny-os (v0, v6, t6, on the same
 * machine, in assembly and C). TinyKernel/ holds the rest: entry.tm,
 * runtime.c, the user programs, the Makefile.
 *
 * The toolchain, all ix's, and its bridge between ML and the machine,
 * small where mini-9pi's and mini-xv6's (kernel/lib/: ocaml-light's C
 * runtime, gcc, boot code, a C glue) cannot be:
 * - tiny-ml -tm: the stack machine's second back end (TinyML.ml);
 * - the runtime: TinyML_core.c, shared with every tiny-ml program, and
 *   runtime.c, the kernel's memory and ten functions of bytes (peek,
 *   poke, a string from memory and to it);
 * - entry.tm, a page of assembly: k_run (the process run until its next
 *   trap: the kernel calls a process as a function, as a hypervisor's
 *   KVM_RUN runs a guest), the trap's entry, the timer, the window.
 * No new primitive in the compiler: the machine is reached through
 * externals, functions of C or of assembly.
 *
 * How it runs. The toplevel reads the files the image carries, makes
 * the first process (/sh, the console its 0, 1 and 2), and enters
 * [schedule], a loop that never returns: run a process until it traps,
 * handle the trap, choose again. A process is its slot (a partition,
 * and a frame of 17 words where entry.tm saves its registers), its pid,
 * its state, its parent, its descriptors and its current directory. A
 * system call that must wait (a read of an empty pipe, a wait) leaves
 * its process Waiting with the rest of the call as a closure; the
 * scheduler calls it when it looks for a process to run, and the
 * process is ready again when the closure could finish. So there is no
 * wakeup to forget (the lost-wakeup bug of sleep and wakeup) and no
 * channel: waiting is on a condition, as Brinch Hansen's await and
 * Plan 9's sleep(r, cond), paid for by a retry per round.
 *
 * The test: make check in TinyKernel/, mltests (fork, exec, wait's statuses,
 * pipes and their end, files, directories and "..", a fault killed,
 * preemption) and a script through the shell, against check.expected.
 *
 * Exercises, each cheap in this design:
 * - the files saved: the tree written at the halt to a disk (-d), read
 *   at the boot instead of the image's (Marshal's idea, by hand);
 * - a waiting process's closure kept with what it waits for, retried
 *   only when that changes (a wakeup, again, but typed);
 * - kill(pid), a signal's simplest form: the process ended at its next
 *   trap;
 * - copy-on-write fork: the partition shared until one side writes,
 *   with pages (tiny-machine's Sv32), the reason pages came;
 * - the kernel's own heap measured: its live words after each
 *   collection, printed at the halt.
 *
 * References (from memory): P. Brinch Hansen, "Structured
 * Multiprogramming" (CACM 1972), await; R. Pike et al., "The Use of
 * Name Spaces in Plan 9" (1993), and Plan 9's sleep and wakeup; D. M.
 * Ritchie and K. Thompson, "The UNIX Time-Sharing System" (CACM 1974),
 * fork, exec, pipes; R. Draves et al., "Using Continuations to
 * Implement Thread Management and Communication in Operating Systems"
 * (SOSP 1991); A. Kivity et al., "kvm: the Linux Virtual Machine
 * Monitor" (OLS 2007), a guest run by a call that returns at its exit;
 * G. Hunt and J. Larus, "Singularity: Rethinking the Software Stack"
 * (2007), a kernel in a safe, collected language; A. Madhavapeddy et
 * al., "Unikernels" (ASPLOS 2013), MirageOS, an OCaml kernel; P.
 * Denning, "Virtual Memory" (Computing Surveys 1970), partitions before
 * pages. *)

(*****************************************************************************)
(* The machine: entry.tm's and runtime.c's functions *)
(*****************************************************************************)

external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_window : int -> int -> unit = "k_window"
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external peekb : int -> int = "peekb"
external pokeb : int -> int -> unit = "pokeb"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"

(* the memory (runtime.c's): the frames below the heap, then the
 * partitions; the devices at the top *)
let part = 0x100000
let nslots = 10
let base slot = 0x500000 + (slot * part)
let frame slot = 0x1c0000 + (slot * 68)
let cons_out = 0xfffff0
let halt_dev = 0xfffff4
let cons_in = 0xfffff8

(* a trap's causes (TinyMachine.ml's), the timer's period *)
let c_sys = 1
let c_intr = 4
let tick = 20000

let puts s = for i = 0 to String.length s - 1 do pokeb cons_out (Char.code s.[i]) done
let halt status = poke halt_dev status

(*****************************************************************************)
(* The files: a tree of ML values *)
(*****************************************************************************)

(* a directory is a list of names in the order they were made; the
 * console is a node too, /console *)
type node = Dir of (string * node) list ref | Data of string ref | Tty

(* a pipe: the bytes written not yet read (512 at most), its readers'
 * and its writers' descriptors (a read of an empty pipe with no writer
 * left is its end) *)
type pipe = Pipe of string ref * int ref * int ref

(* an open file: a node (its offset, whether it is written), a pipe's
 * end, the console. The collector frees them; only pipes count their
 * ends, as a reader must learn that no writer is left *)
type file = Open of node * int ref * bool | Reader of pipe | Writer of pipe | Console

let root = Dir (ref [])

let rec assoc_opt x l = match l with [] -> None | (k, v) :: r -> if k = x then Some v else assoc_opt x r

(* a path's names from the root: the current directory's first unless
 * it starts with /, "." dropped, ".." the name before it removed (by
 * the text, as Plan 9's cleanname: no ".." in a directory) *)
let names cwd path =
  let rec split i j acc =
    if j = String.length path then List.rev (String.sub path i (j - i) :: acc)
    else if path.[j] = '/' then split (j + 1) (j + 1) (String.sub path i (j - i) :: acc)
    else split i (j + 1) acc in
  let start = if String.length path > 0 && path.[0] = '/' then [] else List.rev cwd in
  List.rev (List.fold_left (fun acc n ->
    if n = "" || n = "." then acc else if n = ".." then (match acc with [] -> [] | _ :: r -> r) else n :: acc)
    start (split 0 0 []))

let rec walk node ns =
  match ns, node with
  | [], _ -> Some node
  | n :: rest, Dir d -> (match assoc_opt n !d with Some c -> walk c rest | None -> None)
  | _ -> None

(* the directory a path's last name is in, and that name *)
let dir_of ns =
  match List.rev ns with
  | [] -> None
  | last :: r -> (match walk root (List.rev r) with Some (Dir d) -> Some (d, last) | _ -> None)

(* a directory read as a file: an entry of 32 bytes per name, t6's (its
 * name in 20, its type, a first block of 0, its size), which ls reads *)
let word n =
  String.make 1 (Char.chr (n land 255)) ^ String.make 1 (Char.chr ((n lsr 8) land 255))
  ^ String.make 1 (Char.chr ((n lsr 16) land 255)) ^ String.make 1 (Char.chr ((n lsr 24) land 255))

let contents node =
  match node with
  | Data d -> !d
  | Tty -> ""
  | Dir d ->
      List.fold_left (fun acc (name, n) ->
        let t, size = match n with Dir _ -> 1, 0 | Data d -> 2, String.length !d | Tty -> 3, 0 in
        acc ^ name ^ String.make (20 - String.length name) '\000' ^ word t ^ word 0 ^ word size) "" !d

(* the files the image carries after the kernel (TinyKernel/Makefile's): a
 * name, a line; its size, a line; its bytes; an empty name at the end *)
let rec load a =
  let rec line a acc = let c = peekb a in if c = 10 then acc, a + 1 else line (a + 1) (acc ^ String.make 1 (Char.chr c)) in
  let name, a = line a "" in
  if name <> "" then begin
    let size, a = line a "" in
    let n = ref 0 in
    for i = 0 to String.length size - 1 do n := (!n * 10) + Char.code size.[i] - 48 done;
    (match root with Dir d -> d := !d @ [ name, Data (ref (k_string a !n)) ] | _ -> ());
    load (a + !n)
  end

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* ready to run; waiting, the rest of its system call (true when it
 * could finish); ended, its status kept for its parent's wait *)
type state = Ready | Waiting of (unit -> bool) | Zombie of int

(* its slot (its partition and its frame), its pid, its state, its
 * parent's pid (0: none), its descriptors, its current directory *)
type proc = Proc of int * int * state ref * int ref * (int * file) list ref * string list ref

let slot (Proc (s, _, _, _, _, _)) = s
let pid (Proc (_, p, _, _, _, _)) = p
let state (Proc (_, _, s, _, _, _)) = s
let parent (Proc (_, _, _, p, _, _)) = p
let fds (Proc (_, _, _, _, f, _)) = f
let cwd (Proc (_, _, _, _, _, c)) = c

(* the processes, in the order the scheduler goes through them *)
let procs = ref []
let next_pid = ref 1

(* a register of its frame (r1..r15, the pc as 16), as entry.tm saved it *)
let reg p k = peek (frame (slot p) + (4 * k))
let set_reg p k v = poke (frame (slot p) + (4 * k)) v

(* a user's address, n bytes long, as the kernel reaches it; Bad if it
 * leaves the partition *)
exception Bad
let user p va n = if va < 0 || n < 0 || va + n > part then raise Bad else base (slot p) + va

(* a string of the user's, 64 bytes at most *)
let ustr p va =
  let rec go i acc = if i >= 64 then raise Bad else let c = peekb (user p (va + i) 1) in if c = 0 then acc else go (i + 1) (acc ^ String.make 1 (Char.chr c)) in
  go 0 ""

let free_slot () =
  let rec go s = if s >= nslots then raise Bad else if List.exists (fun p -> slot p = s) !procs then go (s + 1) else s in
  go 0

(* a descriptor's file; the lowest free descriptor (8 a process) *)
let fd p k = match assoc_opt k !(fds p) with Some f -> f | None -> raise Bad
let fdalloc p f =
  let rec go k = if k >= 8 then raise Bad else if List.exists (fun (j, _) -> j = k) !(fds p) then go (k + 1) else k in
  let k = go 0 in
  fds p := !(fds p) @ [ k, f ];
  k

(* a file's one more or one less descriptor (only a pipe counts) *)
let share f = match f with Reader (Pipe (_, r, _)) -> incr r | Writer (Pipe (_, _, w)) -> incr w | _ -> ()
let drop f = match f with Reader (Pipe (_, r, _)) -> decr r | Writer (Pipe (_, _, w)) -> decr w | _ -> ()

(*****************************************************************************)
(* Reads and writes: Some n done, None must wait *)
(*****************************************************************************)

(* the console's input, typed and not yet read, and its end *)
let typed = ref ""
let typed_end = ref false

let read f a n =
  match f with
  | Console ->
      let t = !typed in
      if t = "" then (if !typed_end then Some 0 else None)
      else begin
        (* up to a line's end *)
        let rec upto i = if i >= String.length t || i >= n then i else if t.[i] = '\n' then i + 1 else upto (i + 1) in
        let k = upto 0 in
        k_blit t 0 a k;
        typed := String.sub t k (String.length t - k);
        Some k
      end
  | Reader (Pipe (buf, _, writers)) ->
      if !buf = "" then (if !writers = 0 then Some 0 else None)
      else begin
        let k = min n (String.length !buf) in
        k_blit !buf 0 a k;
        buf := String.sub !buf k (String.length !buf - k);
        Some k
      end
  | Writer _ -> Some (-1)
  | Open (node, off, _) ->
      let s = contents node in
      let k = max 0 (min n (String.length s - !off)) in
      k_blit s !off a k;
      off := !off + k;
      Some k

let write f a n =
  match f with
  | Console -> k_console a n; Some n
  | Writer (Pipe (buf, readers, _)) ->
      if !readers = 0 then Some (-1)
      else if String.length !buf = 512 then None
      else (let k = min n (512 - String.length !buf) in buf := !buf ^ k_string a k; Some k)
  | Open (Data d, off, true) ->
      let old = !d and o = !off in
      let o = min o (String.length old) in
      let rest = if o + n < String.length old then String.sub old (o + n) (String.length old - o - n) else "" in
      d := String.sub old 0 o ^ k_string a n ^ rest;
      off := o + n;
      Some n
  | _ -> Some (-1)

(*****************************************************************************)
(* The system calls *)
(*****************************************************************************)

(* a call that may wait: tried now, and until it finishes by the
 * scheduler, the process Waiting meanwhile *)
let block p attempt = if not (attempt ()) then state p := Waiting attempt

let result p v = set_reg p 1 v

let sys_rw p rw =
  let f = fd p (reg p 1) and n = reg p 3 in
  let a = user p (reg p 2) n in
  block p (fun () -> match rw f a n with Some k -> result p k; true | None -> false)

(* its descriptors closed, its children orphans (their zombies freed);
 * its status for its parent, or its slot free. The first process's
 * end is the machine's *)
let rec exit_proc p status =
  List.iter (fun (_, f) -> drop f) !(fds p);
  fds p := [];
  List.iter (fun q ->
    if !(parent q) = pid p then begin
      parent q := 0;
      match !(state q) with Zombie _ -> release q | _ -> ()
    end) !procs;
  if pid p = 1 then halt status;
  if !(parent p) = 0 then release p else state p := Zombie status

and release q = procs := List.filter (fun r -> pid r <> pid q) !procs

(* fork: a new slot, the partition and the frame copied (the child's r1
 * 0), the descriptors shared *)
let sys_fork p =
  let s = free_slot () in
  let q = Proc (s, !next_pid, ref Ready, ref (pid p), ref !(fds p), ref !(cwd p)) in
  incr next_pid;
  k_copy (base s) (base (slot p)) part;
  k_copy (frame s) (frame (slot p)) 68;
  List.iter (fun (_, f) -> share f) !(fds p);
  procs := !procs @ [ q ];
  set_reg q 1 0;
  result p (pid q)

(* a program in p's partition, from 0; its arguments as tiny-cpu leaves
 * them (the strings at the top, then argc, argv and argv's pointers:
 * start.tm's); every register 0 but sp *)
let load_prog p prog argv =
  let b = base (slot p) in
  k_zero b part;
  k_blit prog 0 b (String.length prog);
  let top = ref part and ptrs = ref [] in
  List.iter (fun s ->
    top := (!top - String.length s - 1) land lnot 3;
    k_blit s 0 (b + !top) (String.length s);
    ptrs := !ptrs @ [ !top ]) argv;
  let sp = (!top - ((List.length argv + 3) * 4)) land lnot 7 in
  poke (b + sp) (List.length argv);
  poke (b + sp + 4) (sp + 8);
  ignore (List.fold_left (fun at a -> poke at a; at + 4) (b + sp + 8) !ptrs);
  k_zero (frame (slot p)) 68;
  set_reg p 14 sp

(* exec(path, argv): its program's text, its arguments (16 at most),
 * all read before the partition is changed, so a failed exec returns *)
let sys_exec p =
  let prog = match walk root (names !(cwd p) (ustr p (reg p 1))) with Some (Data d) -> !d | _ -> raise Bad in
  let rec args i acc =
    if i >= 16 then raise Bad
    else let a = peek (user p (reg p 2 + (4 * i)) 4) in if a = 0 then List.rev acc else args (i + 1) (ustr p a :: acc) in
  let argv = args 0 [] in
  if String.length prog > part - 0x10000 then raise Bad;
  load_prog p prog argv

(* wait(&status): a child's end, the child freed; -1 without children *)
let sys_wait p =
  let a = reg p 1 in
  if a <> 0 then ignore (user p a 4);
  block p (fun () ->
    let kids = List.filter (fun q -> !(parent q) = pid p) !procs in
    match kids, List.filter (fun q -> match !(state q) with Zombie _ -> true | _ -> false) kids with
    | [], _ -> result p (-1); true
    | _, [] -> false
    | _, q :: _ ->
        (match !(state q) with Zombie s -> if a <> 0 then poke (user p a 4) s | _ -> ());
        release q;
        result p (pid q);
        true)

let o_create = 0x200
let o_trunc = 0x400

let sys_open p =
  let ns = names !(cwd p) (ustr p (reg p 1)) and mode = reg p 2 in
  let writes = mode land 3 <> 0 in
  let node =
    match walk root ns, dir_of ns with
    | Some n, _ -> n
    | None, Some (d, last) when mode land o_create <> 0 && String.length last < 20 ->
        let n = Data (ref "") in d := !d @ [ last, n ]; n
    | _ -> raise Bad in
  (match node with Dir _ when writes -> raise Bad | Data d when mode land o_trunc <> 0 -> d := "" | _ -> ());
  result p (fdalloc p (match node with Tty -> Console | _ -> Open (node, ref 0, writes)))

let sys_close p =
  let k = reg p 1 in
  drop (fd p k);
  fds p := List.filter (fun (j, _) -> j <> k) !(fds p);
  result p 0

let sys_pipe p =
  let a = user p (reg p 1) 8 in
  let pi = Pipe (ref "", ref 1, ref 1) in
  let r = fdalloc p (Reader pi) in
  let w = fdalloc p (Writer pi) in
  poke a r;
  poke (a + 4) w;
  result p 0

let sys_dup p = let f = fd p (reg p 1) in share f; result p (fdalloc p f)

let sys_mkdir p =
  let ns = names !(cwd p) (ustr p (reg p 1)) in
  match walk root ns, dir_of ns with
  | None, Some (d, last) when String.length last < 20 -> d := !d @ [ last, Dir (ref []) ]; result p 0
  | _ -> raise Bad

(* a name removed; a directory only if empty *)
let sys_unlink p =
  match dir_of (names !(cwd p) (ustr p (reg p 1))) with
  | Some (d, last) ->
      (match assoc_opt last !d with
       | Some (Dir e) when !e <> [] -> raise Bad
       | Some _ -> d := List.filter (fun (n, _) -> n <> last) !d; result p 0
       | None -> raise Bad)
  | None -> raise Bad

let sys_chdir p =
  let ns = names !(cwd p) (ustr p (reg p 1)) in
  match walk root ns with Some (Dir _) -> cwd p := ns; result p 0 | _ -> raise Bad

(* by their numbers, the machine's sys n: exit, write and read first,
 * tiny-cpu's own (libc's) *)
let syscall p =
  try
    match k_tval () with
    | 0 -> exit_proc p (reg p 1)
    | 1 -> sys_rw p write
    | 2 -> sys_rw p read
    | 3 -> sys_fork p
    | 4 -> sys_exec p
    | 5 -> sys_wait p
    | 6 -> result p (pid p)
    | 7 -> sys_open p
    | 8 -> sys_close p
    | 9 -> sys_pipe p
    | 10 -> sys_dup p
    | 11 -> sys_mkdir p
    | 12 -> sys_unlink p
    | 13 -> sys_chdir p
    | _ -> result p (-1)
  with Bad -> result p (-1)

(*****************************************************************************)
(* The scheduler: round robin, preemptive *)
(*****************************************************************************)

(* the interrupts' sources: the timer re-armed (its time is up), the
 * console's bytes taken; whether the timer's *)
let interrupts sources =
  if sources land 2 <> 0 then begin
    let rec take () =
      let c = peek cons_in in
      if c = -2 then typed_end := true
      else if c <> -1 then (typed := !typed ^ String.make 1 (Char.chr c); take ()) in
    take ()
  end;
  if sources land 1 <> 0 then (k_timer tick; true) else false

(* the first process that can run: ready, or waiting and its call now
 * finished *)
let rec runnable l =
  match l with
  | [] -> None
  | p :: rest ->
      (match !(state p) with
       | Ready -> Some p
       | Waiting attempt -> if attempt () then (state p := Ready; Some p) else runnable rest
       | Zombie _ -> runnable rest)

(* the loop: a process run until it traps, the trap handled; the same
 * process again unless its time is up or it cannot go on (then it goes
 * last); none to run, an interrupt waited for *)
let rec schedule () =
  match runnable !procs with
  | Some p -> run p
  | None -> ignore (k_run 0); ignore (interrupts (k_tval ())); schedule ()

and run p =
  k_window (base (slot p)) part;
  let cause = k_run (frame (slot p)) in
  let timer =
    if cause = c_sys then (syscall p; false)
    else if cause = c_intr then interrupts (k_tval ())
    else begin
      puts ("ml: " ^ string_of_int (pid p) ^ ": trap " ^ string_of_int cause ^ " at " ^ string_of_int (reg p 16) ^ ", "
            ^ string_of_int (k_tval ()) ^ ": killed\n");
      exit_proc p (-1);
      false
    end in
  let alive = List.exists (fun q -> pid q = pid p) !procs in
  if alive && (not timer) && (match !(state p) with Ready -> true | _ -> false) then run p
  else begin
    (* last in the round *)
    if alive then procs := List.filter (fun q -> pid q <> pid p) !procs @ [ p ];
    schedule ()
  end

(*****************************************************************************)
(* The boot *)
(*****************************************************************************)

let () =
  k_init ();
  k_timer tick;
  load (k_end ());
  (match root with Dir d -> d := !d @ [ "console", Tty ] | _ -> ());
  puts ("tiny-kernel: TinyKernel.ml, " ^ string_of_int nslots ^ " partitions of " ^ string_of_int (part / 1024) ^ " KB\n");
  (* the first process: /sh, the console its 0, 1 and 2 *)
  let p = Proc (0, 1, ref Ready, ref 0, ref [ 0, Console; 1, Console; 2, Console ], ref []) in
  incr next_pid;
  procs := [ p ];
  (match walk root [ "sh" ] with Some (Data d) -> load_prog p !d [ "sh" ] | _ -> puts "no /sh\n"; halt 1);
  schedule ()
