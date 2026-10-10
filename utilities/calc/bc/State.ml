(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What bc's grammar keeps while it compiles (bc.y's globals), and where
 * its dc commands go.
 *
 * A function, an if's body and a loop are dc macros kept in registers:
 * a function f in the register of f's rank (<6>), a body in a register
 * taken in turn from 128 (<128>, <129>...). A break is a Q that leaves
 * as many macros as were entered since the loop: lev counts them. *)

(* the dc commands compiled: printed (bc -c), or run *)
let emit : (string -> unit) ref = ref print_string

(* -s: a statement that is an expression is not printed *)
let silent = ref false

(* the next register for a body, and where a statement's start again
 * (those of a function stay taken) *)
let crs = ref 128
let rcrs = ref 128

(* how many macros are entered where we are; those entered at each
 * loop or if around it *)
let lev = ref 0
let bstack = Array.make 10 0
let bindx = ref 0

(* a function's parameters and locals: saved before its body, restored after *)
let pre = ref ""
let post = ref ""

(* the input's name and line, for an error *)
let file = ref "stdin"
let line = ref 0

(* bc's exit: a q for dc, then the end *)
exception Quit

let output s =
  !emit (s ^ "\n");
  crs := !rcrs

(* a body kept in its register *)
let conout body register =
  !emit ("[" ^ body ^ "]s" ^ register ^ "\n");
  decr lev

let error msg =
  !emit (Printf.sprintf "c[%s:%d %s]pc\n" !file (!line + 1) msg);
  crs := !rcrs;
  bindx := 0;
  lev := 0

let number n = " " ^ string_of_int n

(* a function's register, an array's: the letter's rank, from 1 and from 221 *)
let func letter = Printf.sprintf "<%d>" (Char.code letter.[0] - 96)
let array letter = Printf.sprintf "<%d>" (Char.code letter.[0] + 124)

(* a parameter (given), a local (0): saved on its register's stack *)
let parameter s = pre := "S" ^ s ^ !pre; post := !post ^ "L" ^ s ^ "s."
let local s = pre := "0S" ^ s ^ !pre; post := !post ^ "L" ^ s ^ "s."
