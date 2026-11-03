(* 021c562b^, kernels/9pi/devices/sys/Devmnt.ml's rpc: wait called itself
 * in a handler, no tail call by mini-ml (a try a function of its own):
 * 48 bytes of the 16 KB kernel stack for each reply on the connection *)
type m = { mutable replies : (int * string) list; mutable reading : bool }

let sleep (_ : m) : unit = ()
let read (m : m) : unit = m.replies <- (0, "reply") :: m.replies

let rpc (m : m) (tag : int) : string =
  let rec wait () =
    try
      let r = List.assoc tag m.replies in
      m.replies <- List.filter (fun (t, _) -> t <> tag) m.replies;
      r
    with Not_found ->
      if m.reading then begin sleep m; wait () end
      else begin m.reading <- true; read m; m.reading <- false; wait () end in
  wait ()

let () = print_string (rpc { replies = []; reading = false } 0)
