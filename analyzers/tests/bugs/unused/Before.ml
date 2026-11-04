(* A7, a teaching exercise: OCaml's warning 27 by rules (bugs/unused.dl).
 * Plan 9's Udp.ask as of 70b6b2bf^, its timeout not kept, said meant
 * (_seconds): quiet; the same without the _: reported; a pair whose
 * second part is not read: reported *)
let ask (address : string) (port : int) (packet : string) (_seconds : float) : string =
  address ^ string_of_int port ^ packet

let ask_unsaid (address : string) (port : int) (packet : string) (seconds : float) : string =
  address ^ string_of_int port ^ packet

let first ((a, b) : int * int) : int = a

let () = print_string (ask "h" 1 "p" 2. ^ ask_unsaid "h" 1 "p" 2. ^ string_of_int (first (1, 2)))
