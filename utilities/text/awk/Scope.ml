(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* What the grammar and the lexer tell each other while a program is
 * read (awkgram.y's globals): inside a function a parameter's name is
 * its number, a return is allowed, a next is not; break and continue
 * want a loop around them. *)

(* the function being read: its name and its parameters *)
let function_name : string option ref = ref None
let in_function = ref false
let params : string list ref = ref []

(* how many loops are around what is being read *)
let loops = ref 0

(* BEGIN's and END's statements, as they are met *)
let begins : Ast.stmt list ref = ref []
let ends : Ast.stmt list ref = ref []

(* the offset where the rule that an action refuses ends (None: the
 * lexer's last token), for the error's context *)
let error_end : int option ref = ref None

(* a parameter's number, from 0 *)
let param name =
  let rec find k = function [] -> None | p :: rest -> if p = name then Some k else find (k + 1) rest in
  find 0 !params
