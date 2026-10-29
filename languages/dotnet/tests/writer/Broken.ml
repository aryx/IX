(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Assemblies the verifier must refuse (plan_dotnet.md, stage 7), each
 * of its methods broken in one way, written by hand with the writer,
 * and one right. Broken file.dll writes them; tests/run.sh checks
 * what mini-dotnet -verify says of each (writer/broken.verify). *)

module S = Signature

let make () : string =
  let w = Writer.create "broken" in
  let runtime = Writer.assembly_ref w "System.Runtime" in
  let console = Writer.type_ref w (Writer.assembly_ref w "System.Console") "System" "Console" in
  let obj = Writer.type_ref w runtime "System" "Object" in
  let stat ps r = { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps } in
  let wi = Writer.member_ref w console "WriteLine" (stat [ S.I4 ] S.Void) in
  let cls = Writer.type_def w "" "Broken" 0x00100001 obj in
  let meth name ret code =
    let m = Writer.method_def w cls name 0x0096 (stat [] ret) in
    Writer.set_body w m [] code [];
    m in
  let s = Writer.user_string w "a" in
  let main = meth "Right" S.Void Il.[| Ldc_i4 1l; Ldc_i4 2l; Binop Add; Call wi; Ret |] in
  ignore (meth "AddIntAndString" S.Void Il.[| Ldc_i4 1l; Ldstr s; Binop Add; Pop; Ret |]);
  (* (one path pushes a value the other does not, and they join) *)
  ignore (meth "DeeperOnOneBranch" S.Void Il.[| Ldc_i4 0l; Brtrue 3; Ldc_i4 1l; Ret |]);
  ignore (meth "ValueLeftAtRet" S.Void Il.[| Ldc_i4 7l; Ret |]);
  ignore (meth "StringForInt" S.Void Il.[| Ldstr s; Call wi; Ret |]);
  ignore (meth "BranchOnFloat" S.Void Il.[| Ldc_r 1.5; Brtrue 2; Ret |]);
  ignore (meth "EmptyStack" S.Void Il.[| Pop; Ret |]);
  ignore (meth "FallsOffTheEnd" S.Void Il.[| Nop |]);
  ignore (meth "ReturnsNothing" S.I4 Il.[| Ret |]);
  Writer.set_entry_point w main;
  Writer.write w

let () =
  Cap.main (fun (caps : < Cap.open_out; Cap.argv; .. >) ->
      let argv = CapSys.argv caps in
      match FS.path argv.(1) with
      | Ok p -> FS.write caps p (make ())
      | Error e -> failwith e)
