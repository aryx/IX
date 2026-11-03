(* 4436f60d^, kernels/9pi/init/Main.ml's fault, called by C: a page
 * refused (Fault's Error, no memory left) went to guard, whose handler
 * panics: one program asking too much stopped the machine *)
exception Error of string

let eintr = "interrupted"

let page (addr : int) : bool =
  if addr > 4096 then raise (Error "virtual memory allocation failed") else true

let panic (s : string) : unit = print_string s; failwith s

let guard (where : string) (f : unit -> unit) : unit =
  try f () with e -> panic ("an exception in " ^ where ^ ": " ^ Printexc.to_string e)

let fault (addr : int) : unit =
  guard "a fault" (fun () ->
    let resolved = try page addr with Error e when e = eintr -> true in
    if resolved then print_string "resolved")

let () = Callback.register "fault" fault
