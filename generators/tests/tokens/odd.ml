(* what ix's own sources have little of: each kind of token at its edges *)
# 12 "other.ml"
let x = 3l + 4L - 0x1fL * 0b101 / 0o17 +. 1.5e-3 -. 2. ** 1_000
  # 40 "again.ml" trailing
let s = "a\"b\\c\n\065\x41 \
         continued" ^ {|raw "q" |x} |} ^ {id|with |} and |x} inside|id} ^ {| a
two lines |}
let c = [ 'a'; '\''; '\\'; '\n'; '\065'; '\x41'; ' ' ]
let f ~lab ~other:y ?(z = 1) = lab ! y := !z; [| x |] ; [%bits "0101"] ; x.[0] <- 'c'
type t = { a : int; mutable b : 'a list } [@@deriving show] [@@unboxed] [@inline] [@@@warning "-32 ]"]
let ( |>> ) a b = a >>= b <|> a && b || not a != b <> a == b $ a @ b ^ a :: b :> c
(* a (* nested "string *) with" *) comment {|quoted *) |} 'c' '"' '\'' '\065' *) let after = 1
let _ = a.b.(c) <- ..  ;; ~- ~ ! ? ?? |] -. - -> <- :=
