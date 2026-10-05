(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The laws a build system must obey (Mokhov, Mitchell and Peyton Jones,
 * "Build Systems a la Carte", 2018), checked on random graphs, one per
 * seed:
 *
 *   correct      after a build, every target is what a clean build
 *                makes
 *   minimal      after a leaf changes, exactly the targets that depend
 *                on it are made again
 *   idempotent   a second build runs nothing
 *   parallel     NPROC=4, jobs ending in a random order, makes the same
 *                files as NPROC=1, and starts no job before its
 *                prerequisites are made
 *)
module U = Testutil_mk

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())
let seeds = List.init 50 (fun i -> i + 1)

let dag seed = U.random_dag seed ~targets:12 ~leaves:5

let check_correct seed (w : U.world) deps =
  deps |> List.iter (fun (t, _) ->
    Alcotest.(check (option string)) (Printf.sprintf "seed %d: %s" seed t)
      (Some (U.expected deps w t)) (U.content w t))

let sorted = List.sort compare

let laws_hashes = [
  t "laws -H: correct, minimal, idempotent, parallel" (fun () ->
    seeds |> List.iter (fun seed ->
      let text, leaves, deps = dag seed in
      let order = Random.State.make [| seed * 11 |] in
      let w = U.world_with ~order:(Some order) ~cutoff:[] ~constant:[] leaves in
      let h = U.hashes w in
      let _ = U.build_with ~nproc:4 ~flags:U.flags ~hashes:(Some h) w (U.mkfile text) "all" in
      check_correct seed w deps;
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: -H idempotent" seed)
        [ "all" ] (U.build_with ~nproc:1 ~flags:U.flags ~hashes:(Some h) w (U.mkfile text) "all");
      let leaf = List.nth leaves (seed mod List.length leaves) in
      U.edit w leaf;
      let ran = U.build_with ~nproc:4 ~flags:U.flags ~hashes:(Some h) w (U.mkfile text) "all" in
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: -H no early start" seed) [] w.violations;
      check_correct seed w deps;
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: -H minimal" seed)
        (sorted ("all" :: U.dependents deps leaf)) (sorted ran)));
  t "laws -H: new times, same contents: nothing to do" (fun () ->
    let text, leaves, _ = dag 3 in
    let w = U.world leaves in
    let h = U.hashes w in
    let _ = U.build_with ~nproc:1 ~flags:U.flags ~hashes:(Some h) w (U.mkfile text) "all" in
    (* a git checkout: every file touched, none changed *)
    let files = Hashtbl.fold (fun f (_, c) acc -> (f, c) :: acc) w.files [] in
    List.iter (fun (f, c) -> Hashtbl.replace w.files f (U.tick w, c)) files;
    Alcotest.(check (list string)) "only the virtual all" [ "all" ] (U.build_with ~nproc:1 ~flags:U.flags ~hashes:(Some h) w (U.mkfile text) "all"));
  t "laws -H: early cutoff without cmp -s" (fun () ->
    let text = "foo.o: config.h\n\tcc\nconfig.h: config.in\n\tgen\n" in
    (* config.in changes, and config.h is regenerated identically *)
    let run ~hashes () =
      let w = U.world_with ~order:None ~cutoff:[] ~constant:[ "config.h" ] [ "config.in" ] in
      let _ = U.build_with ~nproc:1 ~flags:U.flags ~hashes:(Option.map (fun f -> f w) hashes) w (U.mkfile text) "foo.o" in
      U.edit w "config.in";
      w
    in
    let w = run ~hashes:None () in
    Alcotest.(check (list string)) "mtimes: foo.o too" [ "config.h"; "foo.o" ]
      (U.build w (U.mkfile text) "foo.o");
    let h = ref None in
    let w = run ~hashes:(Some (fun w -> let x = U.hashes w in h := Some x; x)) () in
    Alcotest.(check (list string)) "-H: config.h only" [ "config.h" ]
      (U.build_with ~nproc:1 ~flags:U.flags ~hashes:!h w (U.mkfile text) "foo.o"));
]

let laws = [
  t "laws: correct, minimal, idempotent" (fun () ->
    seeds |> List.iter (fun seed ->
      let text, leaves, deps = dag seed in
      let w = U.world leaves in
      let _ = U.build w (U.mkfile text) "all" in
      check_correct seed w deps;
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: idempotent" seed)
        [ "all" ] (U.build w (U.mkfile text) "all");
      let leaf = List.nth leaves (seed mod List.length leaves) in
      U.edit w leaf;
      let ran = U.build w (U.mkfile text) "all" in
      check_correct seed w deps;
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: minimal after %s" seed leaf)
        (sorted ("all" :: U.dependents deps leaf)) (sorted ran)));
  t "laws: parallel = sequential" (fun () ->
    seeds |> List.iter (fun seed ->
      let text, leaves, deps = dag seed in
      let order = Random.State.make [| seed * 7 |] in
      let w = U.world_with ~order:(Some order) ~cutoff:[] ~constant:[] leaves in
      let _ = U.build_with ~nproc:4 ~flags:U.flags ~hashes:None w (U.mkfile text) "all" in
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: no early start" seed) [] w.violations;
      check_correct seed w deps;
      let leaf = List.nth leaves (seed mod List.length leaves) in
      U.edit w leaf;
      let ran = U.build_with ~nproc:4 ~flags:U.flags ~hashes:None w (U.mkfile text) "all" in
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: no early start (2)" seed) [] w.violations;
      check_correct seed w deps;
      Alcotest.(check (list string)) (Printf.sprintf "seed %d: minimal" seed)
        (sorted ("all" :: U.dependents deps leaf)) (sorted ran)));
] @ laws_hashes
