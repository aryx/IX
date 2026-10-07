(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* tiny-arm: TinyLibArm's CPU run as Linux runs a user program; its
 * usage and examples: [help], what tiny-arm -h prints.
 *
 * The program is an executable, TinyAssembler's: its segments copied
 * where they say, the stack as execve leaves it, the entry jumped to.
 * The operating system is four calls, read, write, exit and getpid, as
 * Linux numbers them on arm64 (x8): what the test programs of TinyC
 * and TinyML make, goken's libc included. So the same file runs here,
 * on the real CPU and under mini-5i, and the three are compared.
 * TinyMachinePi runs the same CPU with the Pi 4's devices, where an
 * svc is an exception taken.
 *
 * What is dropped: the environment (envp is empty), and every other
 * call (a file opened, memory asked for): an error naming its number. *)

let usage = "usage: tiny-arm program [args...]"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
An ARM CPU (arm64) run as Linux runs a program: an executable of
tiny-assembler's loaded and interpreted; read, write, exit and getpid its
system calls. For example, with libc/*.s as tiny-c -h makes it:
  tiny-c -o fact.s fact.c && tiny-assembler -o fact fact.s libc/*.s
  tiny-arm fact                  fact 10 = 3628800
  ./fact (or mini-5i fact)       the same, on the real CPU (or mini-5i's)
  tiny-arm fact one two          its arguments
An instruction outside the subset stops it, with its word and its address.
|}

(*****************************************************************************)
(* Linux: the system calls, the executable, running *)
(*****************************************************************************)

exception Exit of int

type caps = < Cap.stdin; Cap.stdout; Cap.stderr >

let syscall (caps : < caps; .. >) (m : TinyLibArm.machine) (_ : int) =
  let arg n = Int64.to_int (TinyLibArm.reg m n) in
  let return v = TinyLibArm.set m 0 (Int64.of_int v) in
  match arg 8 with
  | 93 | 94 -> raise (Exit (arg 0 land 0xff))
  | 63 ->
      let (_ : < Cap.stdin; .. >) = caps in
      TinyLibArm.check m (arg 1) (arg 2);
      return (try input stdin m.mem (arg 1) (arg 2) with Sys_error _ -> -5)
  | 64 ->
      TinyLibArm.check m (arg 1) (arg 2);
      let s = Bytes.sub_string m.mem (arg 1) (arg 2) in
      if arg 0 = 2 then Console.eprint caps s else (Console.print caps s; flush stdout);
      return (arg 2)
  | 172 -> return 1                         (* getpid: the one process there is *)
  | n -> TinyLibArm.error "unimplemented system call %d" n

let stack = 8 * 1024 * 1024

(* the ELF's loadable segments copied at their addresses in a memory
 * that ends with the stack; the machine and the entry *)
let load file =
  let u16 a = String.get_uint16_le file a and u32 a = Int32.to_int (String.get_int32_le file a) land 0xffffffff
  and u64 a = Int64.to_int (String.get_int64_le file a) in
  if String.length file < 64 || String.sub file 0 5 <> "\127ELF\002" || u16 18 <> 183 then TinyLibArm.error "not an arm64 ELF executable";
  let segments = List.filter_map (fun i ->
    let p = u64 32 + (i * u16 54) in
    if u32 p = 1 then Some (u64 (p + 8), u64 (p + 16), u64 (p + 32), u64 (p + 40)) else None) (List.init (u16 56) Fun.id) in
  let top = List.fold_left (fun top (_, vaddr, _, memsz) -> max top (vaddr + memsz)) 0 segments in
  let m : TinyLibArm.machine = TinyLibArm.create (((top + 0xfff) land lnot 0xfff) + stack) in
  List.iter (fun (offset, vaddr, filesz, _) -> Bytes.blit_string file offset m.mem vaddr filesz) segments;
  m.pc <- u64 24;
  m

let run caps file args =
  let m = load file in
  (* the stack as Linux's execve leaves it: argc, argv, nil, envp's nil,
   * the auxiliary vector's end *)
  let strs = List.fold_left (fun top s -> let top = top - String.length s - 1 in Bytes.blit_string s 0 m.mem top (String.length s); top) (Bytes.length m.mem) args in
  let ptrs = snd (List.fold_left (fun (a, acc) s -> a + String.length s + 1, a :: acc) (strs, []) (List.rev args)) in
  let sp = (strs - (8 * (List.length args + 5))) land lnot 15 in
  List.iteri (fun i v -> TinyLibArm.store m 3 (sp + (8 * i)) (Int64.of_int v)) (List.length args :: ptrs);
  TinyLibArm.set_sp m 31 (Int64.of_int sp);
  let env = TinyLibArm.plain ~svc:(syscall caps) in
  try while true do TinyLibArm.step env m done; 0 with Exit n -> n

let main (caps : < caps; Cap.argv; Cap.open_in; .. >) =
  try
    match List.tl (Array.to_list (CapSys.argv caps)) with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | file :: _ as args when file.[0] <> '-' -> run caps (FS.read caps (Fpath.v file)) args
    | _ -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  with TinyLibArm.Error e | Sys_error e -> Console.eprint caps ("tiny-arm: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
