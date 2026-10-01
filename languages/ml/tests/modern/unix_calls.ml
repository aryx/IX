(* packages: unix *)
(* Unix: mini-ml's own (lib_core/system, system calls from OCaml)
 * against OCaml's: files, directories, processes, time *)

let dir = "/tmp/mini-ml-unix-test"
let ( / ) = Filename.concat
let errors f = try ignore (f ()); "no error" with Unix.Unix_error (e, fn, arg) -> Printf.sprintf "%s: %s (%s)" fn (Unix.error_message e) arg
let kind (k : Unix.file_kind) = match k with S_REG -> "reg" | S_DIR -> "dir" | S_LNK -> "lnk" | S_CHR -> "chr" | S_FIFO -> "fifo" | _ -> "other"
let names d = let h = Unix.opendir d in let rec go acc = match Unix.readdir h with n -> go (n :: acc) | exception End_of_file -> Unix.closedir h; List.sort compare acc in go []
let read_all fd = let b = Bytes.create 64 and all = Buffer.create 64 in let rec go () = let n = Unix.read fd b 0 64 in if n > 0 then (Buffer.add_subbytes all b 0 n; go ()) in go (); Buffer.contents all

let () =
  (* directories *)
  ignore (Sys.command ("rm -rf " ^ dir));
  Unix.mkdir dir 0o755;
  Unix.mkdir (dir / "sub") 0o700;
  print_endline (errors (fun () -> Unix.mkdir dir 0o755));
  print_endline (errors (fun () -> Unix.rmdir (dir / "none")));

  (* a file written, read back by pieces, sought *)
  let f = dir / "data" in
  let fd = Unix.openfile f [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_TRUNC ] 0o640 in
  Printf.printf "%d %d\n" (Unix.write_substring fd "hello, world\n" 0 13) (Unix.write fd (Bytes.of_string "xxsecond linexx") 2 11);
  Printf.printf "%d %d\n" (Unix.lseek fd 0 Unix.SEEK_CUR) (Unix.lseek fd 7 Unix.SEEK_SET);
  let b = Bytes.make 10 '.' in
  let n = Unix.read fd b 2 5 in
  Printf.printf "%d %s %d\n" n (Bytes.to_string b) (Unix.lseek fd (-4) Unix.SEEK_END);
  Printf.printf "%s|%Ld\n" (read_all fd) (Unix.LargeFile.lseek fd 0L Unix.SEEK_END);
  let st = Unix.fstat fd in
  Printf.printf "%s %o %d %d %b %b\n" (kind st.st_kind) st.st_perm st.st_size st.st_nlink (st.st_mtime > 1.7e9) (Unix.isatty fd);
  Unix.ftruncate fd 5;
  Unix.fchmod fd 0o600;
  Printf.printf "%Ld %o\n" (Unix.LargeFile.fstat fd).st_size (Unix.stat f).st_perm;
  Printf.printf "%b\n" (Unix.readlink (Printf.sprintf "/proc/self/fd/%d" (Obj.magic fd : int)) = f);
  Unix.close fd;
  print_endline (errors (fun () -> Unix.close fd));
  print_endline (errors (fun () -> Unix.openfile (dir / "none") [ Unix.O_RDONLY ] 0));
  print_endline (errors (fun () -> Unix.openfile f [ Unix.O_CREAT; Unix.O_EXCL; Unix.O_RDWR ] 0o600));

  (* names, kinds, permissions *)
  Printf.printf "%s %s %s\n" (kind (Unix.stat dir).st_kind) (kind (Unix.lstat (dir / "sub")).st_kind) (kind (Unix.LargeFile.lstat "/dev/null").st_kind);
  Unix.rename f (dir / "renamed");
  Unix.chmod (dir / "renamed") 0o400;
  print_endline (String.concat " " (names dir));
  Printf.printf "%s | %s | %s\n" (errors (fun () -> Unix.access (dir / "renamed") [ Unix.R_OK ])) (errors (fun () -> Unix.access (dir / "gone") [ Unix.R_OK; Unix.W_OK ]))
    (errors (fun () -> Unix.stat f));
  Unix.utimes (dir / "renamed") 1000000000.0 1234567890.5;
  let st = Unix.stat (dir / "renamed") in
  Printf.printf "%.1f %.1f\n" st.st_atime st.st_mtime;
  Unix.chdir dir;
  Printf.printf "%b %b %b\n" (Unix.getcwd () = Unix.realpath ".") (Unix.realpath "sub/../renamed" = Unix.realpath dir / "renamed") (Sys.file_exists "renamed");
  Unix.unlink "renamed";
  Unix.rmdir "sub";
  print_endline (String.concat " " (names "."));

  (* a pipe, a child, its status *)
  flush stdout;
  let r, w = Unix.pipe ~cloexec:false () in
  (match Unix.fork () with
   | 0 -> Unix.close r; ignore (Unix.write_substring w "from the child" 0 14); Unix._exit 7
   | pid ->
       Unix.close w;
       let ic = Unix.in_channel_of_descr r in
       let line = input_line ic in
       let p, st = Unix.waitpid [] pid in
       Printf.printf "%s %b %s\n" line (p = pid && pid <> Unix.getpid ()) (match st with WEXITED n -> string_of_int n | _ -> "?"));
  (* a program run, its output on a pipe: dup2, execv *)
  flush stdout;
  let r, w = Unix.pipe ~cloexec:true () in
  (match Unix.fork () with
   | 0 -> Unix.dup2 w Unix.stdout; (try Unix.execv "/bin/echo" [| "echo"; "run by"; "execv" |] with Unix.Unix_error _ -> Unix._exit 127)
   | _ -> Unix.close w; let out = read_all r in let _, st = Unix.wait () in Printf.printf "%s%s\n" out (match st with WEXITED 0 -> "ok" | _ -> "?"));
  flush stdout;
  (match Unix.fork () with
   | 0 -> Unix.execve "/bin/sh" [| "sh"; "-c"; "echo $GREETING; kill -TERM $$" |] [| "GREETING=an environment" |]
   | pid -> let _, st = Unix.waitpid [] pid in Printf.printf "%b\n" (st = WSIGNALED Sys.sigterm));
  flush stdout;
  (match Unix.fork () with
   | 0 -> Unix.sleepf 5.0; Unix._exit 0
   | pid ->
       let p0, _ = Unix.waitpid [ Unix.WNOHANG ] pid in
       Unix.kill pid Sys.sigkill;
       let _, st = Unix.waitpid [] pid in
       Printf.printf "%d %b %s\n" p0 (st = WSIGNALED Sys.sigkill) (errors (fun () -> Unix.wait ())));
  print_endline (errors (fun () -> Unix.execv "/no/such/program" [| "x" |]));
  let d = Unix.dup ~cloexec:false Unix.stdout in
  ignore (Unix.write_substring d "through a dup\n" 0 14);
  Unix.close d;

  (* time, the environment *)
  let t0 = Unix.gettimeofday () in
  Unix.sleepf 0.05;
  let t1 = Unix.gettimeofday () in
  Printf.printf "%b %b %b\n" (t0 > 1.7e9) (t1 -. t0 >= 0.05 && t1 -. t0 < 2.0) (Unix.time () <= t1 +. 1.0);
  List.iter (fun t ->
    let tm = Unix.gmtime t in
    Printf.printf "%04d-%02d-%02d %02d:%02d:%02d wday %d yday %d\n" (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec tm.tm_wday tm.tm_yday)
    [ 0.0; 1234567890.5; 951782400.0; 1709164799.0; 1735689600.0; -86401.0; 4102444800.0 ];
  let env = Unix.environment () in
  Printf.printf "%b %b %b\n" (Array.exists (fun v -> String.length v > 5 && String.sub v 0 5 = "HOME=") env) (Unix.gethostname () <> "")
    (Array.for_all (fun v -> String.contains v '=') env);
  Unix.chdir "/";
  Unix.rmdir dir;
  Printf.printf "%b\n" (Sys.file_exists dir)
