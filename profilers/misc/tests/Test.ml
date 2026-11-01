(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What mini-stats reads in the kernel's files, without a kernel: Sysinfo. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())

let test_cores () =
  let line idle = Printf.sprintf "0 1 0 0 0 0 0 0 %d 0\n" idle in
  Alcotest.(check (list int)) "percent busy, a core a line" [ 75; 0 ] (Sysinfo.cores (line 25 ^ line 100));
  Alcotest.(check (list int)) "nothing" [] (Sysinfo.cores "")

let swap = "512000000 memory\n4096 pagesize\n1000 kernel\n2100/8400 user\n0/0 swap\n7/9 kernel malloc\n"

let test_memory () =
  Alcotest.(check (option int)) "/dev/swap's user line" (Some 25) (Sysinfo.memory swap);
  Alcotest.(check (option int)) "no such line" None (Sysinfo.memory "1 memory\n");
  Alcotest.(check (option int)) "no page at all" None (Sysinfo.memory "0/0 user\n")

let test_counters () =
  Alcotest.(check (option (pair int int))) "the ethernet's" (Some (12, 34))
    (Sysinfo.ether "in: 12\nlink: 1\nout: 34\ncrc errs: 0\n");
  Alcotest.(check (option (pair int int))) "no out" None (Sysinfo.ether "in: 12\n");
  Alcotest.(check (option (pair int int))) "the disk's" (Some (512, 1024))
    (Sysinfo.disk "inquiry x\nio 512 1024\npart dos 8 9\n");
  Alcotest.(check int) "grew" 5 (Sysinfo.grew 10 15);
  Alcotest.(check int) "went back: nothing" 0 (Sysinfo.grew 15 10)

let test_scale () =
  let p = Sysinfo.log_percent 10000 in
  Alcotest.(check int) "nothing is nothing" 0 (p 0);
  Alcotest.(check bool) "a little is seen" true (p 1 > 0);
  Alcotest.(check int) "the top" 100 (p 10000);
  Alcotest.(check int) "past the top" 100 (p 5000000);
  Alcotest.(check bool) "more is higher" true (p 10 < p 100 && p 100 < p 1000 && p 1000 < p 10000);
  Alcotest.(check bool) "within a power too" true (p 200 < p 900);
  Alcotest.(check (list string)) "short" [ "7"; "950"; "12K"; "3M" ] (List.map Sysinfo.short [ 7; 950; 12345; 3000000 ])

let () =
  Testo.interpret_argv ~project_name:"mini-stats"
    (fun _ -> [ t "the cores from /dev/sysstat" test_cores;
                t "the memory from /dev/swap" test_memory;
                t "the ethernet's and the disk's counters" test_counters;
                t "a rate's height on the strip" test_scale ])
