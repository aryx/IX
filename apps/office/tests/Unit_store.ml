(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* A document saved and opened again: the platforms' Store (a
 * directory's files, through the capabilities), and File_menu's Save
 * over it. The directory is one made for the test, named in
 * $PLAYGROUND_STORE, two levels below one that is there: the store
 * makes it. *)

let t = Testo.create

let fresh () =
  let d = Filename.concat (Filename.get_temp_dir_name ()) (Printf.sprintf "ix-store-%d-%d" (Unix.getpid ()) (Random.bits ())) in
  Unix.mkdir d 0o755;
  let dir = Filename.concat (Filename.concat d "not") "yet" in
  Unix.putenv "PLAYGROUND_STORE" dir;
  dir

let test_store (caps : File_menu.caps) () =
  let dir = fresh () in
  Alcotest.(check string) "the directory the environment says" dir (Store.dir caps);
  Alcotest.(check (list string)) "nothing yet, and no directory" [] (Store.stored caps);
  Alcotest.(check (option string)) "nothing to fetch" None (Store.fetch caps "a.office");
  let bytes = "office 1\n\000\001\255 bytes\nof any kind" in
  Store.store caps "b.office" "second";
  Store.store caps "a.office" bytes;
  Alcotest.(check (list string)) "listed, in order" [ "a.office"; "b.office" ] (Store.stored caps);
  Alcotest.(check (option string)) "the same bytes" (Some bytes) (Store.fetch caps "a.office");
  Store.store caps "a.office" "over it";
  Alcotest.(check (option string)) "stored over what was there" (Some "over it") (Store.fetch caps "a.office");
  (* a name is never a path *)
  Store.store caps "../up/there" "x";
  Store.store caps ".hidden" "y";
  Alcotest.(check (list string)) "in the directory, under names of its own" [ "_.._up_there"; "_.hidden"; "a.office"; "b.office" ] (Store.stored caps);
  Alcotest.(check bool) "and nowhere else" false (Sys.file_exists (Filename.concat (Filename.dirname dir) "up"))

let kind : File_menu.kind = { magic = "points 1"; extension = ".points" }

let test_save_as (caps : File_menu.caps) () =
  let _ = fresh () in
  let data = [ (1., 2., "a"); (-3.5, 0., "b\nc") ] in
  let current () = data in
  let c = Playground.initial_computer in
  let keys typed keys = { c with keyboard = { c.keyboard with typed; keys = Set_.of_list keys } } in
  (* Save, of a document with no name yet: the dialog *)
  let m, _ = File_menu.command caps kind ~current "Save" File_menu.start in
  Alcotest.(check bool) "it asks for a name" true (File_menu.busy m);
  let m, _ = File_menu.dialog caps kind (keys "notes" []) ~current m in
  let m, _ = File_menu.dialog caps kind (keys "" [ "Enter" ]) ~current m in
  Alcotest.(check bool) "the dialog is gone" false (File_menu.busy m);
  Alcotest.(check string) "the document has its name" "notes.points" (File_menu.title m);
  Alcotest.(check (list string)) "and is in the store" [ "notes.points" ] (Store.stored caps);
  let read : (float * float * string) list option =
    match Store.fetch caps "notes.points" with Some s -> Saved.of_string ~magic:kind.magic s | None -> None
  in
  Alcotest.(check bool) "its value read back" true (read = Some data);
  (* Save again: at once, to the same name *)
  let m, _ = File_menu.command caps kind ~current:(fun () -> []) "Save" m in
  Alcotest.(check bool) "no dialog" false (File_menu.busy m);
  let read : (float * float * string) list option =
    match Store.fetch caps "notes.points" with Some s -> Saved.of_string ~magic:kind.magic s | None -> None
  in
  Alcotest.(check bool) "written over" true (read = Some []);
  (* Open: the documents of this kind only *)
  Store.store caps "other.sheet" "sheet 1\n";
  let m, _ = File_menu.command caps kind ~current "Open..." m in
  Alcotest.(check bool) "the dialog" true (File_menu.busy m);
  let m, _ = File_menu.dialog caps kind (keys "" [ "Escape" ]) ~current m in
  Alcotest.(check bool) "Escape closes it" false (File_menu.busy m)

let tests (caps : File_menu.caps) =
  [ t "documents stored, listed and fetched" (test_store caps); t "Save asks for a name once, then writes" (test_save_as caps) ]
