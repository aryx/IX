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


(* Array operations *)

external length : 'a array -> int = "%array_length"
external get: 'a array -> int -> 'a = "%array_safe_get"
external set: 'a array -> int -> 'a -> unit = "%array_safe_set"
external unsafe_get: 'a array -> int -> 'a = "%array_unsafe_get"
external unsafe_set: 'a array -> int -> 'a -> unit = "%array_unsafe_set"
external make: int -> 'a -> 'a array = "make_vect"
external create: int -> 'a -> 'a array = "make_vect"

let init l f =
  if l = 0 then [||] else
   let res = create l (f 0) in
   for i = 1 to pred l do
     unsafe_set res i (f i)
   done;
   res 

let make_matrix sx sy init =
  let res = create sx [||] in
  for x = 0 to pred sx do
    unsafe_set res x (create sy init)
  done;
  res


let copy a =
  let l = length a in
  if l = 0 then [||] else begin
    let res = create l (unsafe_get a 0) in
    for i = 1 to pred l do
      unsafe_set res i (unsafe_get a i)
    done;
    res
  end

let append a1 a2 =
  let l1 = length a1 and l2 = length a2 in
  if l1 = 0 & l2 = 0 then [||] else begin
    let r = create (l1 + l2) (unsafe_get (if l1 > 0 then a1 else a2) 0) in
    for i = 0 to l1 - 1 do unsafe_set r i (unsafe_get a1 i) done;  
    for i = 0 to l2 - 1 do unsafe_set r (i + l1) (unsafe_get a2 i) done;  
    r
  end

let concat_aux init al =
  let size = List.fold_left (fun sz a -> sz + length a) 0 al in
  let res = create size init in
  let pos = ref 0 in
  List.iter
    (fun a ->
      for i = 0 to length a - 1 do
        unsafe_set res !pos (unsafe_get a i);
        incr pos
      done)
    al;
  res

let concat al =
  let rec find_init = function
      [] -> [||]
    | a :: rem ->
        if length a > 0 then concat_aux (unsafe_get a 0) al else find_init rem
  in find_init al

let sub a ofs len =
  if ofs < 0 or len < 0 or ofs + len > length a then invalid_arg "Array.sub"
  else if len = 0 then [||]
  else begin
    let r = create len (unsafe_get a ofs) in
    for i = 1 to len - 1 do unsafe_set r i (unsafe_get a (ofs + i)) done;
    r
  end

let fill a ofs len v =
  if ofs < 0 or len < 0 or ofs + len > length a
  then invalid_arg "Array.fill"
  else for i = ofs to ofs + len - 1 do unsafe_set a i v done

let blit a1 ofs1 a2 ofs2 len =
  if len < 0 or ofs1 < 0 or ofs1 + len > length a1
             or ofs2 < 0 or ofs2 + len > length a2
  then invalid_arg "Array.blit"
  else if ofs1 < ofs2 then
    (* Top-down copy *)
    for i = len - 1 downto 0 do
      unsafe_set a2 (ofs2 + i) (unsafe_get a1 (ofs1 + i))
    done
  else
    (* Bottom-up copy *)
    for i = 0 to len - 1 do
      unsafe_set a2 (ofs2 + i) (unsafe_get a1 (ofs1 + i))
    done

let iter f a =
  for i = 0 to length a - 1 do f(unsafe_get a i) done

let map f a =
  let l = length a in
  if l = 0 then [||] else begin
    let r = create l (f(unsafe_get a 0)) in
    for i = 1 to l - 1 do
      unsafe_set r i (f(unsafe_get a i))
    done;
    r
  end

let iteri f a =
  for i = 0 to length a - 1 do f i (unsafe_get a i) done

let mapi f a =
  let l = length a in
  if l = 0 then [||] else begin
    let r = create l (f 0 (unsafe_get a 0)) in
    for i = 1 to l - 1 do
      unsafe_set r i (f i (unsafe_get a i))
    done;
    r
  end

let to_list a =
  let rec tolist i res =
    if i < 0 then res else tolist (i - 1) (unsafe_get a i :: res) in
  tolist (length a - 1) []

let of_list = function
    [] -> [||]
  | hd::tl ->
      let a = create (List.length tl + 1) hd in
      let rec fill i = function
          [] -> a
        | hd::tl -> unsafe_set a i hd; fill (i+1) tl in
      fill 1 tl

let fold_left f x a =
  let r = ref x in
  for i = 0 to length a - 1 do
    r := f !r (unsafe_get a i)
  done;
  !r

let fold_right f a x =
  let r = ref x in
  for i = length a - 1 downto 0 do
    r := f (unsafe_get a i) !r
  done;
  !r

(* ix: OCaml's later functions, those ix's programs use *)

let to_seq a =
  let rec aux i () =
    if i < length a
    then
      let x = unsafe_get a i in
      Seq.Cons (x, aux (i+1))
    else Seq.Nil
  in
  aux 0

let exists p a = let rec go i = i < length a && (p (unsafe_get a i) || go (i + 1)) in go 0
let for_all p a = let rec go i = i = length a || (p (unsafe_get a i) && go (i + 1)) in go 0
let for_all2 p a b =
  if length a <> length b then invalid_arg "Array.for_all2";
  let rec go i = i = length a || (p (unsafe_get a i) (unsafe_get b i) && go (i + 1)) in go 0
let mem x a = exists (fun y -> compare x y = 0) a

let find_opt p a =
  let rec go i = if i = length a then None else let x = unsafe_get a i in if p x then Some x else go (i + 1) in
  go 0

(* in place, by List's sort: a merge sort, which keeps equal elements in
 * their order *)
let stable_sort cmp a = List.iteri (fun i x -> unsafe_set a i x) (List.stable_sort cmp (to_list a))
let sort = stable_sort
