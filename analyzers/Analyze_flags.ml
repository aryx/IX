(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-analyze's command line, what Analyze reads and the others act on:
 * Analyze_one one program by its files, Analyze_build programs by their
 * build, Analyze_merge several programs' runs *)

(* what mini-analyze may do: read the program and the rules, write a
 * merge's files, run itself and dune *)
type caps =
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr;
    Cap.exec; Cap.wait >

(* the question asked; the last flag given *)
type analysis =
  | Calls  (* no flag: the calls through a pointer or a variable *)
  | Dead
  | Caps
  | Exn
  | Bugs

type t = {
  mutable analysis : analysis;
  (* the program: by its files, the C and ML given (and a manifest's
   * own, Analyze_build's) *)
  mutable files : string list;
  (* or by its build: tiny-ld's manifests, dune's executables, directories
   * of either; a program's name, a directory's (build, tiny/TinyShell) *)
  mutable manifests : string list;
  mutable exes : string list;
  mutable dirs : string list;
  names : (string, string) Hashtbl.t;
  mutable project : string;  (* -project, "" none: found *)
  (* the command line's flags, not its programs nor files: the runs of a
   * merge given them again *)
  mutable args : string list;
  (* ix's tree mini-analyze is from, its executable's: its rules and its
   * lib_core when not said; "." when it is the current directory *)
  mutable home : string;
  mutable rules : string;  (* -r, else home's analyzers/datalog *)
  mutable lib : string;  (* -L, "" none: found, else home's lib_core *)
  mutable incs : string list;  (* -I *)
  mutable defs : string list;  (* -D *)
  mutable roots : string list;  (* -root *)
  mutable start : string;  (* -start *)
  mutable context : string;  (* -context, "" none: by the analysis *)
  mutable library : bool;  (* -library *)
  mutable summary : string;  (* -summary's file, "" none *)
  mutable program : string;  (* -program, "" none *)
  mutable facts : bool;  (* -facts *)
  mutable flow : bool;  (* -flow *)
  mutable answers : bool;  (* -flow-answers *)
  mutable fingerprint : bool;
}
