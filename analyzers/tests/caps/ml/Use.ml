(* mini-analyze -caps: what goes around the capabilities, and what only looks
 * like it *)

(* no capability: by the library, directly by the channel *)
let log s = print_string s
let named () = output_string stdout "x"
let printed n = Printf.printf "%d\n" n
let opened f = open_in f
let environment () = Sys.getenv "HOME"
let bye () = exit 0

(* through a gate: nothing *)
let say caps s = Console.print caps s
let contents caps f = FS.read caps f
let leave caps = CapStdlib.exit caps 0

(* the right capability: none needed; a closure in it keeps it; a type by
 * another name, and a group, are the same. But each names print_string
 * itself, around Console's print: said (around) *)
type stdout_caps = < Cap.stdout; .. >
type both = < stdout_caps; Cap.stderr >
let held (_ : < Cap.stdout; .. >) s = print_string s
let by_alias (_ : stdout_caps) s = print_string s
let later x (_caps : < Cap.stdout; .. >) = fun () -> print_string x
let grouped (_ : < Cap.console; .. >) s = print_string s

(* the wrong one *)
let wrong (_ : < Cap.stdout; .. >) f = Unix.openfile f [ Unix.O_RDONLY ] 0
let wrong_closure (_ : < Cap.stderr; .. >) = fun () -> print_string "w"
let half (_ : both) f = prerr_string "h"; open_in f

(* one it does not need; not said if it lets the capability go *)
let excess (_ : < Cap.fork; Cap.stdout; .. >) s = print_string s
let through (caps : < Cap.open_in; .. >) f = FS.read caps f
type holder = { held_caps : < Cap.fork; .. > }
let keeps (caps : < Cap.fork; .. >) = { held_caps = caps }
let gives (caps : < Cap.fork; .. >) k = k caps

(* a record's capabilities are held, its fields' records' too; not said as
 * unneeded: the record is given for what else it has *)
type env = { env_caps : < Cap.stdout; Cap.fork; .. >; name : string }
type outer = { inner : env; depth : int }
let in_record (e : env) = print_string e.name
let in_inner (o : outer) = print_string o.inner.name
let record_wrong (e : env) f = open_in f

(* a closure is judged by itself; who calls List.iter is not, though another
 * gives it a closure that prints *)
let lambda l = List.iter (fun s -> print_string s) l
let passed l = List.iter print_int l
let found l = List.find_opt Sys.file_exists l
let not_found l = List.find_opt (fun s -> s = "") l
let innocent l = List.iter ignore l

(* one of the program's own helpers: its caller is not blamed for it *)
let helper () = print_newline ()
let caller () = helper ()

(* a channel handed in is a descriptor: no authority asked for *)
let write oc s = output_string oc s
let on_fd fd b = Unix.read fd b 0 1
let opens_fd f = Unix.openfile f [ Unix.O_RDONLY ] 0

(* never called: dead, not an ambient use; named all the same (around: what
 * is written, as a Semgrep rule reads it) *)
let unused () = print_string "dead"

let () =
  Cap.main (fun caps ->
    log "a"; named (); printed 1; ignore (opened "f"); ignore (environment ());
    say caps "b"; ignore (contents caps (Fpath.v "f"));
    held caps "c"; by_alias caps "i"; later "j" caps (); lambda [ "d" ]; innocent [ "e" ]; caller ();
    passed [ 1 ]; ignore (found [ "g" ]); ignore (not_found [ "h" ]);
    write (Console.stdout caps) "f";
    grouped caps "l"; ignore (wrong caps "m"); wrong_closure caps (); ignore (half caps "n");
    let e = { env_caps = caps; name = "q" } in
    in_record e; in_inner { inner = e; depth = 1 }; ignore (record_wrong e "r");
    excess caps "o"; ignore (through caps (Fpath.v "p")); ignore (keeps caps); gives caps ignore;
    ignore (on_fd (opens_fd "k") (Bytes.create 1));
    bye (); leave caps)

(* every capability held: what it asks for is said, the set its type could
 * name (old: nothing said, Cap.all_caps < > in lib_core's Cap.mli); not
 * of the function Cap.main is given *)
let all (caps : Cap.all_caps) f = Console.print caps (FS.read caps f)
let () = Cap.main (fun (caps : Cap.all_caps) -> all caps "x")
