(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Source's check (sources.sh): the same program with OCaml's threads
 * (dune) and mini-ml's (the mkfile; for Plan 9 too): a pipe's reads as
 * a channel's messages, its end, two sources chosen between, a timer
 * while another source says nothing. *)

let write fd text = ignore (Unix.write_substring fd text 0 (String.length text))

let main (caps : < Cap.fork; Cap.stdout; .. >) =
  let say text = Console.print caps (text ^ "\n") in
  (* a pipe: what is written is a message, then its end *)
  let r, w = Unix.pipe ~cloexec:false () in
  let lines = Source.reader caps r 100 in
  write w "hello";
  say ("got: " ^ Bytes.to_string (Event.sync (Event.receive lines)));
  write w "again";
  say ("got: " ^ Bytes.to_string (Event.sync (Event.receive lines)));
  Unix.close w;
  say (Printf.sprintf "the end: %d bytes" (Bytes.length (Event.sync (Event.receive lines))));

  (* two sources, a thread that chooses; a third thread answers on a channel *)
  let r1, w1 = Unix.pipe ~cloexec:false () and r2, w2 = Unix.pipe ~cloexec:false () in
  let one = Source.reader caps r1 100 and two = Source.reader caps r2 100 in
  let answers = Event.new_channel () in
  ignore (Thread.create (fun () ->
    for _i = 1 to 4 do
      let from, data = Event.select [ Event.wrap (Event.receive one) (fun d -> "one", d); Event.wrap (Event.receive two) (fun d -> "two", d) ] in
      Event.sync (Event.send answers (from ^ ": " ^ Bytes.to_string data))
    done) ());
  List.iter (fun (w, text) -> write w text; say (Event.sync (Event.receive answers))) [ w2, "b"; w1, "a"; w1, "c"; w2, "d" ];

  (* a timer's ticks, while the pipes say nothing *)
  let ticks = Source.timer caps 0.05 in
  let n = ref 0 in
  for _i = 1 to 3 do
    Event.select [ Event.wrap (Event.receive ticks) (fun () -> incr n); Event.wrap (Event.receive one) (fun _ -> ()) ]
  done;
  say (Printf.sprintf "%d ticks" !n);
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
