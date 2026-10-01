(* packages: fpath,caps *)
(* Fpath and Cap: mini-ml's own (lib_core/system) against the libraries' *)

let show p = Fpath.to_string p

let () =
  let paths = [ "a"; "a/b"; "a/b/"; "/"; "/a"; "/a/b.c"; "a//b"; "./x.tar.gz"; "a.d/b"; "a/.hidden"; "a/b.c/"; "."; ".."; "../x"; "dir/file.ml" ] in
  List.iter (fun s ->
    let p = Fpath.v s in
    Printf.printf "%-12s base %-8s parent %-7s rem %-10s set %-13s has %b %b | %s %s\n" (show p) (show (Fpath.base p)) (show (Fpath.parent p))
      (show (Fpath.rem_ext p)) (show (Fpath.set_ext ".o" p)) (Fpath.has_ext ".c" p) (Fpath.has_ext "gz" p)
      (show Fpath.(p / "seg")) (show (Fpath.append p (Fpath.v "q/r")))) paths;
  Printf.printf "%s %s %s %s\n" (show Fpath.(v "git" / "refs" / "heads")) (show (Fpath.append (Fpath.v "a") (Fpath.v "/abs")))
    (show Fpath.(v "a/" // v "b/")) (show (Fpath.set_ext "5" (Fpath.base (Fpath.v "src/prog.c"))));
  Printf.printf "%b %b\n" (try ignore (Fpath.v ""); false with Invalid_argument _ -> true)
    (try ignore (Fpath.add_seg (Fpath.v "a") "b/c"); false with Invalid_argument _ -> true);
  Format.printf "%a@." Fpath.pp (Fpath.v "printed/path")

(* capabilities: passed, and written in the types (here not checked) *)
let args (caps : < Cap.argv; .. >) = Array.length (CapSys.argv caps) - Array.length Sys.argv
let run (caps : < Cap.stdout; Cap.argv; Cap.env; .. >) = Printf.printf "%d %b\n" (args caps) (CapSys.getenv caps "HOME" <> ""); 3
let () = Cap.main (fun (caps : Cap.all_caps) -> CapStdlib.exit caps (run caps))
