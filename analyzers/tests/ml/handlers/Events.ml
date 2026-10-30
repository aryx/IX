(* handlers kept in a record and a list, called through variables *)
type handler = { name : string; on_key : int -> unit }

let beeps : int ref = ref 0

let beep (_ : int) : unit = incr beeps

let log (k : int) : unit = print_int k

let handlers : handler list ref = ref []

let register (h : handler) : unit = handlers := h :: !handlers

let dispatch (k : int) : unit =
  List.iter (fun (h : handler) -> h.on_key k) !handlers

let twice (f : int -> unit) (k : int) : unit = f k; f k

let unused (k : int) : int = k + 1
