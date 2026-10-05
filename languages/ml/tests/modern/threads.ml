(* packages: threads.posix *)
(* Threads and channels (lib_core/concurrency: Thread, Mutex, Condition,
 * Event), the same program with OCaml's threads, which are preemptive,
 * and mini-ml's, which are not: what it prints depends on neither *)

let () =
  (* a rendezvous: each send waits for its receive *)
  let ping = Event.new_channel () and pong = Event.new_channel () in
  let doubler = Thread.create (fun n -> for _i = 1 to n do Event.sync (Event.send pong (2 * Event.sync (Event.receive ping))) done) 3 in
  for i = 1 to 3 do
    Event.sync (Event.send ping i);
    Printf.printf "%d " (Event.sync (Event.receive pong))
  done;
  Thread.join doubler;
  print_newline ();

  (* twenty threads, one channel: every message once *)
  let ch = Event.new_channel () in
  let workers = List.init 20 (fun k -> Thread.create (fun k -> for i = 1 to 5 do Event.sync (Event.send ch (k * 10 + i)) done) k) in
  let got = List.init 100 (fun _ -> Event.sync (Event.receive ch)) in
  List.iter Thread.join workers;
  Printf.printf "%d messages, their sum %d, %d different\n" (List.length got) (List.fold_left ( + ) 0 got)
    (List.length (List.sort_uniq compare got));

  (* a choice between two channels, a result wrapped, a poll *)
  let a = Event.new_channel () and b = Event.new_channel () in
  ignore (Thread.create (fun () -> Event.sync (Event.send a "from a")) ());
  ignore (Thread.create (fun () -> Event.sync (Event.send b 7)) ());
  let one () = Event.select [ Event.receive a; Event.wrap (Event.receive b) (fun n -> "from b: " ^ string_of_int n) ] in
  let first = one () in
  let second = one () in
  print_endline (String.concat ", " (List.sort compare [ first; second ]));
  Printf.printf "%b %d\n" (Event.poll (Event.receive a) = None) (Event.sync (Event.always 42));

  (* a mutex and a condition: a queue of one place *)
  let m = Mutex.create () and full = Condition.create () and empty = Condition.create () and slot = ref None in
  let put v = Mutex.lock m; while !slot <> None do Condition.wait empty m done; slot := Some v; Condition.signal full; Mutex.unlock m in
  let take () =
    Mutex.lock m;
    while !slot = None do Condition.wait full m done;
    let v = Option.get !slot in
    slot := None; Condition.signal empty; Mutex.unlock m; v in
  let consumer = Thread.create (fun () -> let total = ref 0 in for _i = 1 to 50 do total := !total + take () done; Printf.printf "taken: %d\n" !total) () in
  for i = 1 to 50 do put i done;
  Thread.join consumer;

  (* threads that end, and their numbers used again: 200 of them, more than there are at once *)
  let count = ref 0 in
  for _i = 1 to 200 do Thread.join (Thread.create (fun () -> incr count; Thread.yield ()) ()) done;
  Printf.printf "%d threads ended; the first is %d\n" !count (Thread.id (Thread.self ()))
