(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

type 'a t = 'a option = None | Some of 'a

let none = None
let some v = Some v
let value o default = match o with Some v -> v | None -> default
let get = function Some v -> v | None -> invalid_arg "option is None"
let bind o f = match o with None -> None | Some v -> f v
let map f o = match o with None -> None | Some v -> Some (f v)
(* claude: real OCaml only added Option's let* / let+ much later (5.5,
   as a nested Syntax submodule alongside a new "product" function) --
   not backported here since we don't target OCaml 5; the one-liner
   would just be "let ( let* ) o f = bind o f" / "let ( let+ ) o f =
   map f o" if wanted *)
(* let fold ~none ~some = function Some v -> some v | None -> none *)
let iter f = function Some v -> f v | None -> ()
let is_some = function None -> false | Some _ -> true



(* let to_result ~none = function None -> Error none | Some v -> Ok v *)
let to_list = function None -> [] | Some v -> [v]
(* let to_seq = function None -> Seq.empty | Some v -> Seq.return v *)
