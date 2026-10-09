(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The test suite of editors/emacs/: the text (Unit_text), the keys and
 * the columns (Unit_keymap); the sessions are keys.sh's. From the
 * root: make test. *)

let tests _env = Unit_text.tests @ Unit_keymap.tests

let () = Cap.main (fun (_ : Cap.all_caps) -> Testo.interpret_argv ~project_name:"ix-emacs" tests)
