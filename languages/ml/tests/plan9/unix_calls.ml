(* Plan 9's Unix (lib_core/system/plan9), under mini-5i: a note to
 * oneself and its handler, a pipe and a child, its status, the kernel's
 * words for an error (OS=plan9 ../run.sh 5) *)

let () =
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> print_string "interrupt handled\n"));
  Printf.printf "pid ok: %b\n" (Unix.getpid () > 0);
  Unix.kill (Unix.getpid ()) Sys.sigint;
  print_string "after\n";
  let r, w = Unix.pipe ~cloexec:false () in
  (match Unix.fork () with
   | 0 -> Unix.close r; ignore (Unix.write_substring w "from the child\n" 0 15); Unix._exit 7
   | pid ->
       Unix.close w;
       let b = Bytes.create 64 in
       let n = Unix.read r b 0 64 in
       print_string (Bytes.sub_string b 0 n);
       (match Unix.waitpid [] pid with
        | p, Unix.WEXITED n -> Printf.printf "child %b exited %d\n" (p = pid) n
        | _ -> print_string "other\n"));
  (try ignore (Unix.openfile "/nonexistent/x" [ Unix.O_RDONLY ] 0) with
   | Unix.Unix_error (Unix.ENOENT, fn, arg) -> Printf.printf "ENOENT %s %s: %s\n" fn arg (Unix.error_message Unix.ENOENT));
  (try ignore (Unix.wait ()) with Unix.Unix_error (Unix.ECHILD, _, _) -> print_string "no child\n");
  Printf.printf "%b %b\n" ((Unix.stat "/tmp").Unix.st_kind = Unix.S_DIR) (Sys.time () >= 0.0)
