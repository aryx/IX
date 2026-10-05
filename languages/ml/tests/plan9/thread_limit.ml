(* mini-ml's threads (lib_core/concurrency): no more than 256 at once (the
 * runtime's STACKS): the next Thread.create raises Failure; a thread that
 * ended leaves its place. Not OCaml's: its threads have no such limit
 * (run.sh 7, or OS=plan9 run.sh 5). *)

let () =
  let hold = Event.new_channel () in
  let n = ref 0 in
  (try for _i = 1 to 300 do ignore (Thread.create (fun () -> Event.sync (Event.receive hold)) ()); incr n done
   with Failure m -> Printf.printf "after %d threads: Failure %s\n" !n m);
  (* the first ones let go: there is room again *)
  for _i = 1 to 10 do Event.sync (Event.send hold ()) done;
  Thread.yield ();
  ignore (Thread.create (fun () -> print_string "one more, after ten ended\n") ());
  Thread.yield ()
