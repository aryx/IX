(* ddb60eef^, lib_core/concurrency/Event.ml (ocaml-light's): basic_sync
 * waited once on its condition; woken by another thread than the one
 * performing its event (Source's wait), it read bev.(-1), and the thread
 * died of Invalid_argument *)
type behavior = { poll : unit -> bool; suspend : unit -> unit; result : unit -> int }

let masterlock = Mutex.create ()

let basic_sync (genev : (int ref -> Condition.t -> behavior) array) : int =
  let performed = ref (-1) in
  let condition = Condition.create () in
  let bev = Array.map (fun g -> g performed condition) genev in
  Mutex.lock masterlock;
  if not (Array.exists (fun b -> b.poll ()) bev) then begin
    Array.iter (fun b -> b.suspend ()) bev;
    Condition.wait condition masterlock
  end;
  Mutex.unlock masterlock;
  bev.(!performed).result ()

let () =
  let ev (performed : int ref) (c : Condition.t) : behavior =
    { poll = (fun () -> false); suspend = (fun () -> ());
      result = (fun () -> !performed) } in
  print_int (basic_sync [| ev |])
