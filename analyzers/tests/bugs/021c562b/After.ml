(* 021c562b, the fix: List.assoc_opt, the calls of wait out of the try *)
type m = { mutable replies : (int * string) list; mutable reading : bool }

let sleep (_ : m) : unit = ()
let read (m : m) : unit = m.replies <- (0, "reply") :: m.replies

let rpc (m : m) (tag : int) : string =
  let rec wait () =
    match List.assoc_opt tag m.replies with
    | Some r ->
        m.replies <- List.filter (fun (t, _) -> t <> tag) m.replies;
        r
    | None ->
      if m.reading then begin sleep m; wait () end
      else begin m.reading <- true; read m; m.reading <- false; wait () end in
  wait ()

let () = print_string (rpc { replies = []; reading = false } 0)

(* look-alikes: a loop by && (a tail call since 2fe7e116), a try around
 * no recursion *)
let rec all (p : char -> bool) (s : string) (i : int) : bool = i >= String.length s || (p s.[i] && all p s (i + 1))
let first (l : int list) : int = try List.hd l with Failure _ -> 0
let () = if all (fun c -> c <> ' ') "ab" 0 then print_int (first [ 1 ])
