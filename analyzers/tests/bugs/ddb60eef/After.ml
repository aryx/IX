(* ddb60eef: until one of the events is performed, as OCaml's Event; and
 * a wait in a loop of a recursive function *)
type behavior = { poll : unit -> bool; suspend : unit -> unit; result : unit -> int }

let masterlock = Mutex.create ()

let basic_sync (genev : (int ref -> Condition.t -> behavior) array) : int =
  let performed = ref (-1) in
  let condition = Condition.create () in
  let bev = Array.map (fun g -> g performed condition) genev in
  Mutex.lock masterlock;
  if not (Array.exists (fun b -> b.poll ()) bev) then begin
    Array.iter (fun b -> b.suspend ()) bev;
    while !performed < 0 do Condition.wait condition masterlock done
  end;
  Mutex.unlock masterlock;
  bev.(!performed).result ()

let rec take (q : int Queue.t) (c : Condition.t) : int =
  if Queue.is_empty q then (Condition.wait c masterlock; take q c) else Queue.take q

let () =
  let ev (performed : int ref) (_c : Condition.t) : behavior =
    { poll = (fun () -> false); suspend = (fun () -> ());
      result = (fun () -> !performed) } in
  print_int (basic_sync [| ev |]);
  print_int (take (Queue.create ()) (Condition.create ()))
