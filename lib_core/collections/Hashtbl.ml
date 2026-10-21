(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)


(* Hash tables *)

external hash_param : int -> int -> 'a -> int = "hash_univ_param" "noalloc"

let hash x = hash_param 10 100 x

(* We do dynamic hashing, and resize the table and rehash the elements
   when it holds more than twice as many as its buckets.
   ix: by its number of entries, as OCaml's (4.00 on), never past the
   largest array. It was ocaml-light's, a table resized whenever a
   bucket was longer than [max_len], which then doubled: keys of one
   hash (Hacker News's comments, 13,852 of a page's 27,841 elements in
   mini-netscape's tables of elements) doubled its array again and
   again, 4 million words and past the most a block holds on 32 bits
   ("index out of bounds"), out of memory first on mini-9pi.
   old: { mutable max_len: int; mutable data: ... },
   if bucket_too_long h.max_len bucket then resize hash h *)

type ('a, 'b) t =
  { mutable size: int;                        (* the entries *)
    mutable data: ('a, 'b) bucketlist array } (* the buckets *)

and ('a, 'b) bucketlist =
    Empty
  | Cons of 'a * 'b * ('a, 'b) bucketlist

let create initial_size =
  if initial_size <= 0 then invalid_arg "hashtbl__new" else
  { size = 0; data = Array.create initial_size Empty }

let clear h =
  h.size <- 0;
  for i = 0 to Array.length h.data - 1 do
    h.data.(i) <- Empty
  done

let copy h = { size = h.size; data = Array.copy h.data }

let length h = h.size

let resize hashfun tbl =
  let odata = tbl.data in
  let osize = Array.length odata in
  let nsize = 2 * osize + 1 in
  if nsize < Sys.max_array_length then begin
    let ndata = Array.create nsize Empty in
    let rec insert_bucket = function
        Empty -> ()
      | Cons(key, data, rest) ->
          insert_bucket rest; (* preserve original order of elements *)
          let nidx = (hashfun key) mod nsize in
          ndata.(nidx) <- Cons(key, data, ndata.(nidx)) in
    for i = 0 to osize - 1 do
      insert_bucket odata.(i)
    done;
    tbl.data <- ndata
  end

(* more than twice as many entries as buckets *)
let grown tbl = if tbl.size > 2 * Array.length tbl.data then resize hash tbl

let add h key info =
  let i = (hash_param 10 100 key) mod (Array.length h.data) in
  let bucket = Cons(key, info, h.data.(i)) in
  h.data.(i) <- bucket;
  h.size <- h.size + 1;
  grown h

(* ix: a key is compared by compare, as OCaml's and as mem and replace
 * below (they were by =: a nan put was never found nor removed) *)
let remove h key =
  let rec remove_bucket = function
      Empty ->
        Empty
    | Cons(k, i, next) ->
        if compare k key = 0 then (h.size <- h.size - 1; next) else Cons(k, i, remove_bucket next) in
  let i = (hash_param 10 100 key) mod (Array.length h.data) in
  h.data.(i) <- remove_bucket h.data.(i)

let find h key =
  match h.data.((hash_param 10 100 key) mod (Array.length h.data)) with
    Empty -> raise Not_found
  | Cons(k1, d1, rest1) ->
      if compare key k1 = 0 then d1 else
      match rest1 with
        Empty -> raise Not_found
      | Cons(k2, d2, rest2) ->
          if compare key k2 = 0 then d2 else
          match rest2 with
            Empty -> raise Not_found
          | Cons(k3, d3, rest3) ->
              if compare key k3 = 0 then d3 else begin
                let rec find = function
                    Empty ->
                      raise Not_found
                  | Cons(k, d, rest) ->
                      if compare key k = 0 then d else find rest
                in find rest3
              end

let find_all h key =
  let rec find_in_bucket = function
    Empty ->
      []
  | Cons(k, d, rest) ->
      if compare k key = 0 then d :: find_in_bucket rest else find_in_bucket rest in
  find_in_bucket h.data.((hash_param 10 100 key) mod (Array.length h.data))

let iter f h =
  let rec do_bucket = function
      Empty ->
        ()
    | Cons(k, d, rest) ->
        f k d; do_bucket rest in
  let d = h.data in
  for i = 0 to Array.length d - 1 do
    do_bucket d.(i)
  done


(* ported from 3.12 *)
let mem h key =
  let rec mem_in_bucket = function
  | Empty ->
      false
  | Cons(k, d, rest) ->
      compare k key = 0 || mem_in_bucket rest in
  mem_in_bucket h.data.((hash key) mod (Array.length h.data))

let fold f h init =
  let rec do_bucket b accu =
    match b with
      Empty ->
        accu
    | Cons(k, d, rest) ->
        do_bucket rest (f k d accu) in
  let d = h.data in
  let accu = ref init in
  for i = 0 to Array.length d - 1 do
    accu := do_bucket d.(i) !accu
  done;
  !accu


let replace h key info =
  let rec replace_bucket = function
      Empty ->
        raise Not_found
    | Cons(k, i, next) ->
        if compare k key = 0
        then Cons(k, info, next)
        else Cons(k, i, replace_bucket next) in
  let i = (hash key) mod (Array.length h.data) in
  let l = h.data.(i) in
  try
    h.data.(i) <- replace_bucket l
  with Not_found ->
    (* ix: a new key grows the table as add does (it did not: a table
     * filled by replace kept its first size, its buckets long lists) *)
    let bucket = Cons(key, info, l) in
    h.data.(i) <- bucket;
    h.size <- h.size + 1;
    grown h

let find_opt h key =
  let rec find_in_bucket = function
      Empty -> None
    | Cons(k, d, rest) ->
        if compare k key = 0 then Some d else find_in_bucket rest in
  find_in_bucket h.data.((hash key) mod (Array.length h.data))

(* ix: OCaml's later functions, those ix's programs use *)

let reset = clear

let filter_map_inplace f h =
  let rec do_bucket = function
      Empty ->
        Empty
    | Cons(k, d, rest) ->
        match f k d with
          None -> h.size <- h.size - 1; do_bucket rest
        | Some d -> Cons(k, d, do_bucket rest) in
  for i = 0 to Array.length h.data - 1 do
    h.data.(i) <- do_bucket h.data.(i)
  done
