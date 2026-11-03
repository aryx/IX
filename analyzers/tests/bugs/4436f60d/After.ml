(* 4436f60d: the page refused ends the process, by a note; guard is
 * not reached. Its look-alikes: a try that gives back what it caught
 * (cleanup, then raise e), and one whose handler answers *)
exception Error of string

let eintr = "interrupted"

let page (addr : int) : bool =
  if addr > 4096 then raise (Error "virtual memory allocation failed") else true

let panic (s : string) : unit = print_string s; failwith s

let guard (where : string) (f : unit -> unit) : unit =
  try f () with e -> panic ("an exception in " ^ where ^ ": " ^ Printexc.to_string e)

let fault (addr : int) : unit =
  guard "a fault" (fun () ->
    let refused = ref "" in
    let resolved =
      try page addr with
      | Error e when e = eintr -> true
      | Error e -> refused := e; false in
    if resolved then print_string "resolved"
    else if !refused <> "" then print_string ("note: " ^ !refused))

let cleanup (addr : int) : unit =
  try ignore (page addr) with e -> print_string "cleanup"; raise e

let answers (addr : int) : unit =
  try ignore (page addr) with e -> print_string ("no: " ^ Printexc.to_string e)

let () = Callback.register "fault" fault
let () = Callback.register "cleanup" cleanup
let () = Callback.register "answers" answers

(* git's proto_die: one exception made another, the rest raised again *)
exception Die of string

let convert (e : exn) : unit =
  match e with Error m -> raise (Die m) | e -> raise e

let send (addr : int) : unit =
  try ignore (page addr) with e -> convert e

let () = Callback.register "send" send
