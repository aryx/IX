(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLLink.mli *)

module Tree = TinyMLTree
module Machine = TinyMLMachine
module Compile = TinyMLCompile
module M = TinyLibMachine

(* ml_init, each unit's init in their order, in a handler that prints
 * an uncaught exception; the curry functions the units need; the
 * globals' tables one after the other, ml_globals, and their count,
 * ml_nglobals (what runtime/ml.c scans) *)
let compile_start (units : (string * int) list) (needed : int list) =
  Tree.unit_name := "ml";
  Compile.start_fun 1 1;
  let handler = Machine.label () in
  Compile.emit (Machine.TryEnter (0, handler));
  List.iter (fun (u, _) ->
      Compile.emit (Machine.Imm (Machine.tagged 0));
      Compile.emit (Machine.Call (Machine.Direct (u ^ ".init"), 0, false));
      Compile.emit Machine.Drop)
    units;
  Compile.emit (Machine.TryExit 0);
  Compile.emit (Machine.Imm (Machine.tagged 0));
  Compile.emit Machine.Ret;
  Compile.emit (Machine.Label handler);
  Compile.emit (Machine.Catch 0);
  Compile.emit (Machine.CallC ("ml_uncaught", 1));
  Compile.emit Machine.Ret;
  Compile.finish_fun "ml_init" 0;
  List.iter (fun n -> for k = 0 to n - 1 do Compile.curry_fun n k done)
    (List.sort_uniq compare needed);
  let total = List.fold_left (fun t (_, n) -> t + n) 0 units in
  Machine.words "ml_nglobals" [ Machine.DNum (Int32.of_int total) ];
  Machine.add_data
    ([ M.Piece; M.Label "ml_globals" ]
     @ List.concat_map (fun (u, n) ->
         [ M.Label (u ^ ".globals"); M.Space (4 * n) ]) units
     @ (if total = 0 then [ M.Space 4 ] else []))
