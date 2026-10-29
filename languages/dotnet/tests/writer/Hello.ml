(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The writer's first program, by hand: a class, a field, a loop, a
 * call into the library, a try and its finally. Hello file.dll writes
 * it; tests/run.sh runs it by mini-dotnet and, when there is an SDK,
 * by Microsoft's dotnet. *)

module S = Signature

let make () : string =
  let w = Writer.create "hello" in
  let runtime = Writer.assembly_ref w "System.Runtime" in
  let console = Writer.type_ref w (Writer.assembly_ref w "System.Console") "System" "Console" in
  let obj = Writer.type_ref w runtime "System" "Object" in
  let exn = Writer.type_ref w runtime "System" "Exception" in
  let stat ps r = { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps } in
  let wl = Writer.member_ref w console "WriteLine" (stat [ S.String ] S.Void) in
  let wi = Writer.member_ref w console "WriteLine" (stat [ S.I4 ] S.Void) in
  let exn_ctor = Writer.member_ref w exn ".ctor" { (stat [ S.String ] S.Void) with has_this = true } in
  let get_message = Writer.member_ref w exn "get_Message" { (stat [] S.String) with has_this = true } in
  (* class Hello { static int count; static void Main() {...} } *)
  let hello = Writer.type_def w "" "Hello" 0x00100001 obj in
  let count = Writer.field_def w hello "count" 0x0011 S.I4 in
  let main = Writer.method_def w hello "Main" 0x0096 (stat [] S.Void) in
  (* count = 0; for (i = 0; i < 3; i++) count += i;  WriteLine("hello, world"); WriteLine(count);
   * try { throw new Exception("boom") } catch (Exception e) { WriteLine(e.Message) }
   * finally { WriteLine("finally") } *)
  let code = Il.[|
    (* 0 *) Ldc_i4 0l; (* 1 *) Stloc 0;
    (* 2 *) Br 11;
    (* 3 *) Ldsfld count; (* 4 *) Ldloc 0; (* 5 *) Binop Add; (* 6 *) Stsfld count;
    (* 7 *) Ldloc 0; (* 8 *) Ldc_i4 1l; (* 9 *) Binop Add; (* 10 *) Stloc 0;
    (* 11 *) Ldloc 0; (* 12 *) Ldc_i4 3l; (* 13 *) Bcmp (Lt, false, 3);
    (* 14 *) Ldstr (Writer.user_string w "hello, world"); (* 15 *) Call wl;
    (* 16 *) Ldsfld count; (* 17 *) Call wi;
    (* 18 *) Ldstr (Writer.user_string w "boom"); (* 19 *) Newobj exn_ctor; (* 20 *) Throw;
    (* 21 *) Callvirt get_message; (* 22 *) Call wl; (* 23 *) Leave 27;
    (* 24 *) Ldstr (Writer.user_string w "finally"); (* 25 *) Call wl; (* 26 *) Endfinally;
    (* 27 *) Ret;
  |] in
  let clauses = Writer.[
      { kind = 0; try_start = 18; try_end = 21; handler_start = 21; handler_end = 24; catch = exn };
      { kind = 2; try_start = 18; try_end = 24; handler_start = 24; handler_end = 27; catch = 0 } ] in
  Writer.set_body w main [ S.I4 ] code clauses;
  Writer.set_entry_point w main;
  Writer.write w

let () =
  Cap.main (fun (caps : < Cap.open_out; Cap.argv; .. >) ->
      let argv = CapSys.argv caps in
      match FS.path argv.(1) with
      | Ok p -> FS.write caps p (make ())
      | Error e -> failwith e)
