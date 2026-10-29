(* [@tailcall] and [@@tailrec] where they hold (Annotations.mli): OCaml
 * reads [@tailcall] as its own and ignores [@@tailrec]; mini-ml checks
 * both. A loop of a million turns, two functions calling each other,
 * a local loop over a list. *)
let rec sum i acc = if i = 0 then acc else sum (i - 1) (acc + i) [@@tailrec]

let rec even n = if n = 0 then true else (odd [@tailcall]) (n - 1)
and odd n = if n = 0 then false else (even [@tailcall]) (n - 1)

let count l =
  let rec go l n = match l with [] -> n | _ :: t -> go t (n + 1) [@@tailrec] in
  go l 0

let () =
  Printf.printf "%d\n" (sum 1000000 0);
  Printf.printf "%b %b\n" (even 100000) (odd 7);
  Printf.printf "%d\n" (count [ 1; 2; 3 ])
