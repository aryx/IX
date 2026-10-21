(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCPU.mli *)

let usage = "usage: tiny-cpu [-l | -prof file] image [args...]"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A CPU of our own (TinyMachineCPU), an image run as a program, three system
calls the host's (r1-r3 the arguments, r1 the answer): sys 0, exit r1; sys 1,
write r3 bytes at r2 to r1 (1, 2); sys 2, read up to r3 bytes to r2. The image
is tiny-linker's (the memory's first bytes: the CPU starts at 0). In
tiny/tests/TinyCPU_tests/, for example:
  tiny-assembler hello.tm && tiny-linker -o hello hello.o
  tiny-cpu hello                the image run: Hello, world
  echo hello | tiny-cpu upper                      HELLO
  tiny-cpu -l hello             the listing: 0:  11100001  addi r1, r0, 1 ...
  tiny-cpu -prof p hello        run, and each instruction counted by its
                                address into p, for tiny-prof
|}

type caps = < Cap.stdin; Cap.stdout; Cap.stderr >

exception Exit of int
exception Usage

let syscall (caps : < caps; .. >) (m : TinyMachineCPU.machine) n =
  let r = m.r and addr = TinyMachineCPU.addr in
  match n with
  | 0 -> raise (Exit (r.(1) land 0xff))
  | 1 ->
      let s = String.init r.(3) (fun i -> Bytes.get m.mem (addr (r.(2) + i))) in
      if r.(1) = 2 then Console.eprint caps s
      else (Console.print caps s; flush stdout);
      r.(1) <- r.(3)
  | 2 ->
      let (_ : < Cap.stdin; .. >) = caps in
      let b = Bytes.create r.(3) in
      let k = try input stdin b 0 r.(3) with Sys_error _ -> 0 in
      Bytes.iteri
        (fun i c -> if i < k then Bytes.set m.mem (addr (r.(2) + i)) c) b;
      r.(1) <- k
  | n -> TinyMachineCPU.error "unknown system call %d" n

(* [prof]: a profile counted meanwhile (-prof), the program's alone *)
let interpret caps prof image args =
  let env = TinyMachineCPU.plain ~sys:(syscall caps) in
  let env =
    match prof with
    | Some p -> TinyMachineCPU.profiled env p (fun _ -> 0, 0)
    | None -> env
  in
  let m : TinyMachineCPU.machine = TinyMachineCPU.boot image in
  (* the strings from the top down, then argv's array and nil, argv,
   * and argc at sp *)
  let top, addrs = List.fold_left (fun (top, addrs) a ->
    let top = top - String.length a - 1 in
    Bytes.blit_string (a ^ "\000") 0 m.mem top (String.length a + 1);
    top, top :: addrs) (!TinyMachineCPU.memsize, []) args in
  let n = List.length args in
  let sp = (top - (4 * (n + 3))) land lnot 7 in
  let put a v = TinyMachineCPU.store m TinyMachineISA.W a v in
  put sp n;
  put (sp + 4) (sp + 8);
  List.iteri (fun k s -> put (sp + 8 + (4 * k)) s) (List.rev addrs);
  put (sp + 8 + (4 * n)) 0;
  m.r.(TinyMachineISA.sp) <- sp;
  try while true do TinyMachineCPU.step env m done; 0 with Exit n -> n

let main (caps : < caps; Cap.argv; Cap.open_in; Cap.open_out; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  let image f = TinyMachineCPU.image f (FS.read caps (Fpath.v f)) in
  try
    match args with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | [ "-l"; f ] ->
        Console.print caps
          (TinyMachineCPU.listing ~show:(fun _ -> None) ~origin:0 (image f));
        0
    | "-prof" :: out :: f :: rest ->
        let p = TinyMachineCPU.profile () in
        let status = interpret caps (Some p) (image f) (f :: rest) in
        FS.write caps (Fpath.v out) (TinyMachineCPU.profile_lines p);
        status
    | f :: rest when f.[0] <> '-' -> interpret caps None (image f) (f :: rest)
    | _ -> raise Usage
  with
  | Usage -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  | TinyMachineISA.Error e | Sys_error e ->
      Console.eprint caps ("tiny-cpu: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
