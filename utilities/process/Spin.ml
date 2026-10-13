(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-spin: do several cores give several times the work? Not one of
 * Plan 9's programs. n processes do the same work at once, each on a
 * core if the machine has them, and the time all of them took is
 * said, to set beside one's: with cores that do not get in each
 * other's way, spin 4 takes the time of spin 1; with one thing that
 * all share, four times. The kinds of work are the things that may
 * be shared (the help below): nothing, the machine's memory, the
 * program's collector, the kernel.
 *
 * Written when mini-9pi first ran processes on the Pi 2's four cores
 * (docs/plans/plan_multicore.md): two games had each about half of
 * one's frames a second, stats (apps/misc) showed every core busy,
 * and the question was what they waited for, the kernel's one lock or
 * the board's memory. An emulator answers for the lock and not for
 * the memory: QEMU's four cores are four threads of a host whose
 * memory is not the board's.
 *
 * history:
 * The measure is as old as machines with two processors: run one
 * copy, run n, divide. Amdahl's argument (1967) is its reading: what
 * n copies cannot do at once bounds what n processors give, whatever
 * n. A kernel with one lock (Linux 2.0's "big kernel lock", 1996;
 * mini-9pi's) is the plain case: programs that compute scale, programs
 * that ask the kernel much do not. *)

type caps = < Cap.fork; Cap.wait; Cap.stdout; Cap.stderr >

let help = {|usage: spin [n [kind]]: n processes (1) each do the same work at once; the time all took
  ints    a loop on integers: no memory but a few words, nothing asked of the kernel (the default)
  mem     16 MB walked six times, read and written: the machine's memory
  alloc   small blocks made and dropped: the program's collector, and the memory
  sys     the time asked of the kernel, over and over: the kernel
spin 4 as fast as spin 1: the cores do not wait for each other in that work.
|}

let ints () =
  let x = ref 1 in
  for i = 1 to 40000000 do x := (!x * 1103515245 + i) land 0xfffffff done;
  !x

(* (a byte of each line of the cache: 64 bytes apart) *)
let mem () =
  let n = 16 * 1024 * 1024 in
  let b = Bytes.make n 'a' in
  let x = ref 0 in
  for _pass = 1 to 6 do
    let i = ref 0 in
    while !i < n do
      Bytes.unsafe_set b !i (Char.unsafe_chr ((Char.code (Bytes.unsafe_get b !i) + 1) land 255));
      x := !x + Char.code (Bytes.unsafe_get b !i);
      i := !i + 64
    done
  done;
  !x

(* (a pair and a float each turn, as a game's frame makes them; one in
 * a thousand kept a while) *)
let alloc () =
  let keep = ref [] and x = ref 0 in
  for i = 1 to 3000000 do
    let p = (i, float_of_int i *. 0.5) in
    if i land 1023 = 0 then keep := p :: (match !keep with a :: b :: _ -> [ a; b ] | l -> l);
    x := !x + fst p
  done;
  !x + List.length !keep

let sys () =
  let x = ref 0 in
  for _i = 1 to 200000 do x := !x + (int_of_float (Unix.gettimeofday ()) land 1) done;
  !x

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let args = List.tl (Array.to_list argv) in
  let n = match args with a :: _ -> int_of_string_opt a | [] -> Some 1 in
  let kind = match args with _ :: k :: _ -> k | _ -> "ints" in
  let work = match kind with "ints" -> Some ints | "mem" -> Some mem | "alloc" -> Some alloc | "sys" -> Some sys | _ -> None in
  match n, work with
  | Some n, Some work when n >= 1 && n <= 64 && List.length args <= 2 ->
      let t0 = Unix.gettimeofday () in
      let pids = List.init n (fun _ -> match CapUnix.fork caps () with 0 -> ignore (work ()); Unix._exit 0 | pid -> pid) in
      List.iter (fun pid ->
        let rec wait () = match CapUnix.waitpid caps [] pid with _ -> () | exception Unix.Unix_error (Unix.EINTR, _, _) -> wait () in
        wait ()) pids;
      Console.print caps (Printf.sprintf "spin %d %s: %.2f s\n" n kind (Unix.gettimeofday () -. t0));
      Exit.OK
  | _ -> Console.eprint caps help; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
