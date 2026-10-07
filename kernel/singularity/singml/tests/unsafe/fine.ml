(* What mini-singml -safe lets through: a module of its own, the
 * standard library's that compute, Sip. *)
module Counter = struct
  let n = ref 0
  let next () : int = incr n; !n
end
let () =
  let b = Sip.alloc 16 in
  Sip.write b 0 (Printf.sprintf "%d" (Counter.next () + List.length [ 1; 2 ]));
  Sip.free b
