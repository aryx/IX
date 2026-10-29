(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-5i [-t] [-s] [-y] [-prof file] program [args...]
An ARM program run as its system runs it: a Linux ELF, arm32 or arm64, or a
Plan 9 a.out (5i's); its output and exit status are the program's. A script
is run by the host (as binfmt would). For example:
  mini-asm -m 7 ~/goken/tests/s/hello_arch/hello_linux_arm64.s
  mini-ld -m 7 -E _start -o hello hello_linux_arm64.7      an arm64 ELF, by ix
  mini-5i hello          Hello, world
  mini-5i -t hello       each instruction on stderr: its address, disassembled
  mini-5i -s hello       the instructions counted, the time, the speed
  mini-5i -y hello       each system call: its number, arguments and result
  mini-5i -prof p hello  each instruction's address counted, written to p
                         at the end, a line "pc count" each (hexadecimal
                         pc, mini-qemu's -prof's lines): mini-prof's
  mini-asm -m 5 ~/goken/tests/s/hello_arch/hello_linux_arm.s
  mini-ld -m 5 -E _start -o hello hello_linux_arm.5
  mini-5i hello          the same on arm32
Not glibc's programs (gcc's): their SIMD and more are beyond its subset.
|}

let main (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.fork; Cap.wait; Cap.chdir; Cap.kill; Cap.exec; Cap.env; .. >) =
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | [] -> Console.eprint caps "usage: mini-5i [-t] [-s] [-y] [-prof file] program [args...]   (-h: how)\n"; 2
  | [ ("-h" | "--help") ] -> Console.print caps help; 0
  | args ->
      (* its own options: before the program's name. What is after is the
       * program's (ls -s, tail -t: taken for ours once, wherever they were) *)
      let prof = ref None in
      let rec split own = function
        | ("-t" | "-s" | "-y") as a :: rest -> split (a :: own) rest
        | "-prof" :: f :: rest -> prof := Some f; split own rest
        | rest -> own, rest in
      let own, args = split [] args in
      (* -prof: every instruction's address counted (mini-qemu's Prof
       * takes one in 1024: a kernel runs for minutes; a program here,
       * all of them, exact and the same at each run) *)
      let counts : (int, int ref) Hashtbl.t = Hashtbl.create 65536 in
      let count (a : int) : unit =
        match Hashtbl.find_opt counts a with Some n -> incr n | None -> Hashtbl.add counts a (ref 1) in
      let write_prof () =
        Option.iter
          (fun (f : string) ->
            FS.with_open_out caps
              (fun (chan : Chan.o) ->
                Hashtbl.iter (fun (pc : int) (n : int ref) -> output_string chan.oc (Printf.sprintf "%x %d\n" pc !n)) counts)
              (Fpath.v f))
          !prof in
      let trace = List.mem "-t" own and stats_on = List.mem "-s" own in
      if List.mem "-y" own then (Linux.log_calls := true; Plan9.log_calls := true);
      let host = Host.create (caps :> Host.caps) in
      let stats = { Cpu.instructions = 0 } in
      let t0 = Unix.gettimeofday () in
      let report () =
        flush stdout;
        write_prof ();
        if stats_on then
          let dt = Unix.gettimeofday () -. t0 in
          Console.eprint caps (Printf.sprintf "mini-5i: %d instructions, %.3f s, %.1f MIPS\n" stats.instructions dt
                                 (float stats.instructions /. dt /. 1e6)) in
      (* -prof, -s: a run stopped by SIGTERM (a program that never ends,
       * or one too long) still writes its profile and its count; a
       * handler the program sets later is Host's *)
      if !prof <> None || stats_on then
        Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> report (); exit 143));
      let tr =
        match (trace, !prof) with
        | true, _ -> Some (fun a i -> count a; Console.eprint caps (Printf.sprintf "%8x\t%s\n" a (Show_arm32.print ~addr:a i)))
        | false, Some _ -> Some (fun a (_ : Arm32_isa.t) -> count a)
        | false, None -> None in
      (* a program run; an execve of another restarts here *)
      let rec run prog argv env =
        let file = try FS.read caps (Fpath.v prog) with Sys_error m -> Console.eprint caps ("mini-5i: " ^ m ^ "\n"); exit 127 in
        match (try Some (Elf.parse file) with Elf.Bad _ -> None) with
        | None when Plan9.parse file <> None -> (
            (* a Plan 9 a.out: 5i's personality *)
            let aout = Option.get (Plan9.parse file) in
            let mem = Memory.create () in
            let proc, entry, sp, tos = Plan9.load host mem aout file argv env in
            let st = Arm32.create mem in
            st.r.(13) <- sp;
            st.r.(0) <- tos;
            (* the VFP on, as 9pi gives it to a program that uses it
             * (mini-ml's floats: plan_rio.md); 5i has none *)
            st.vfp_ok <- true;
            st.fpexc <- 1 lsl 30;
            try Cpu.run32 ~trace:tr st ~pc:entry ~svc:(fun st _ -> Plan9.syscall proc st)
                  ~signal:(fun st pc -> Plan9.deliver proc st ~pc) stats; 0 with
            | Linux.Exit code -> report (); code
            | Linux.Exec (path, argv, env) -> run path argv env
            | Arm32.Unimplemented (w, a) ->
                Console.eprint caps (Printf.sprintf "mini-5i: unimplemented instruction %08x at %x in %s\n" (Bits.unsigned32 w) a prog); report (); 134
            | Memory.Fault a ->
                Console.eprint caps (Printf.sprintf "mini-5i: segmentation fault at %s in %s\n" (Bits.to_hex32 a) prog);
                (* the stack walked, by the program's tables (mini-ld -g's:
                 * plan_debugger.md, stage 3) *)
                (match Symbols.read file with
                 | Some t ->
                     let load a = try let w = Memory.load32 mem a in Some ((w lsr 16) land 0xffff, w land 0xffff) with Memory.Fault _ -> None in
                     Console.eprint caps ("mini-5i: trace: " ^ Frames.show (Frames.walk t load (!Cpu.fault_pc, st.r.(13), st.r.(14))) ^ "\n")
                 | None -> ());
                report (); 139)
        | Some ({ machine = Arm; _ } as elf) -> (
            let mem = Memory.create () in
            let proc, entry, sp = Linux.load host mem elf file argv env in
            let st = Arm32.create mem in
            st.r.(13) <- sp;
            (* claude: the VFP on, as Linux gives it to a hard-float program *)
            st.vfp_ok <- true;
            st.fpexc <- 1 lsl 30;
            try Cpu.run32 ~trace:tr st ~pc:entry ~svc:(fun st _ -> Linux.syscall32 proc st)
                  ~signal:(fun st pc -> Linux.deliver proc st ~pc) stats; 0 with
            | Linux.Exit code -> report (); code
            | Linux.Exec (path, argv, env) -> run path argv env
            | Arm32.Unimplemented (w, a) ->
                Console.eprint caps (Printf.sprintf "mini-5i: unimplemented instruction %08x at %x in %s\n" (Bits.unsigned32 w) a prog); report (); 134
            | Memory.Fault a ->
                Console.eprint caps (Printf.sprintf "mini-5i: segmentation fault at %s in %s\n" (Bits.to_hex32 a) prog); report (); 139)
        | Some ({ machine = Aarch64; _ } as elf) -> (
            let mem = Memory.create () in
            let proc, entry, sp = Linux.load host mem elf file argv env in
            let st = Arm64.create mem in
            Arm64.set_sp st Arm64_isa.X 31 (Arm64.of_address sp);
            let tr =
              match (trace, !prof) with
              | true, _ -> Some (fun a i -> count a; Console.eprint caps (Printf.sprintf "%8x\t%s\n" a (Show_arm64.print ~addr:a i)))
              | false, Some _ -> Some (fun a (_ : Arm64_isa.t) -> count a)
              | false, None -> None in
            try Cpu.run64 ~trace:tr st ~pc:entry ~svc:(fun st _ -> Linux.syscall64 proc st)
                  ~signal:(fun st pc -> Linux.deliver64 proc st ~pc) stats; 0 with
            | Linux.Exit code -> report (); code
            | Linux.Exec (path, argv, env) -> run path argv env
            | Arm64.Unimplemented (w, a) ->
                Console.eprint caps (Printf.sprintf "mini-5i: unimplemented instruction %08x at %x in %s\n" (Bits.unsigned32 w) a prog); report (); 134
            | Memory.Fault a ->
                Console.eprint caps (Printf.sprintf "mini-5i: segmentation fault at %s in %s\n" (Bits.to_hex32 a) prog); report (); 139)
        | _ ->
            (* not an ARM program: the host runs it, as binfmt would *)
            flush_all ();
            (try CapUnix.execve caps prog (Array.of_list argv) (Array.of_list env) with Unix.Unix_error (e, _, _) ->
               Console.eprint caps (Printf.sprintf "mini-5i: %s: %s\n" prog (Unix.error_message e)));
            127 in
      run (List.hd args) args (Array.to_list (Unix.environment ()))
