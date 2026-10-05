(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The syntax tree of rc, as the parser builds it and the evaluator
 * walks it. Its printer is Show_ast. (No Ast.mli: the module is its
 * types.) *)

type word =
  | Word of string * bool           (* its text, and whether it was quoted *)
  | Dollar of word                  (* $x *)
  | Count of word                   (* $#x *)
  | Join of word                    (* dollar-quote x: the list joined *)
  | Sub of word * word list         (* $x(1 2) *)
  | Paren of word list              (* (a b c) *)
  | Concat of word * word           (* a^b, or a free caret *)
  | Backquote of word option * cmd  (* `{cmd}, `sep{cmd} *)
  | Pipefd of side * cmd            (* <{cmd}, >{cmd} *)

and redir =
  | Open of rkind * int * word      (* >f >>f <f <>f, on an fd *)
  | Here of int * heredoc           (* <<tag *)
  | Dup of int * int                (* >[a=b]: fd a becomes a copy of fd b *)
  | Close of int                    (* >[a=] *)

and rkind = Write | Append | Read | RdWr

(* a here document's body is read after its line, so the parser fills
 * it in later *)
and heredoc = { tag : string; expand : bool; mutable body : string }

(* <{cmd}: we read what cmd writes; >{cmd}: we write what it reads *)
and side = Reads | Writes

and cmd =
  | Empty
  | Simple of word list
  | Redirect of redir * cmd         (* applied, then the command *)
  | Seq of cmd * cmd
  | Async of cmd                    (* cmd & *)
  | And of cmd * cmd
  | Or of cmd * cmd
  | Not of cmd
  | Pipe of int * int * cmd * cmd   (* |[a=b]: the left's fd a to the right's b *)
  | Brace of cmd
  | Subshell of cmd                 (* @ cmd *)
  | If of cmd * cmd
  | IfNot of cmd
  | While of cmd * cmd
  | For of word * word list option * cmd   (* None: for(x), over $* *)
  | Switch of word * cmd
  | Match of word * word list       (* ~ subject patterns *)
  | Fn of word list * cmd option    (* None: delete *)
  | Assign of word * word * cmd option     (* x=v, or x=v cmd *)
