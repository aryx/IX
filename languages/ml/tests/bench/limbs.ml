(* a loop over arrays of integers: lib_crypto's Montgomery product
 * (Bignum.redc_mul_simple), limbs of 14 bits, which fit arm's 31-bit
 * integers, 256 bits of them *)
let base_bits = 14
let mask = (1 lsl base_bits) - 1
let n = 19

let redc (m : int array) (minv : int) (a : int array) (b : int array) (t : int array) : unit =
  Array.fill t 0 (n + 2) 0;
  for i = 0 to n - 1 do
    let c = ref 0 in
    let ai = a.(i) in
    for j = 0 to n - 1 do
      let x = t.(j) + (ai * b.(j)) + !c in
      t.(j) <- x land mask;
      c := x lsr base_bits
    done;
    let x = t.(n) + !c in
    t.(n) <- x land mask;
    t.(n + 1) <- t.(n + 1) + (x lsr base_bits);
    let u = t.(0) * minv land mask in
    let x = t.(0) + (u * m.(0)) in
    let c = ref (x lsr base_bits) in
    for j = 1 to n - 1 do
      let x = t.(j) + (u * m.(j)) + !c in
      t.(j - 1) <- x land mask;
      c := x lsr base_bits
    done;
    let x = t.(n) + !c in
    t.(n - 1) <- x land mask;
    t.(n) <- t.(n + 1) + (x lsr base_bits);
    t.(n + 1) <- 0
  done

let () =
  let m = Array.init n (fun (i : int) -> if i = 0 then 0x2a1b else (i * 977) land mask) in
  let a = Array.init n (fun (i : int) -> (i * 4099) land mask) in
  let b = Array.init n (fun (i : int) -> (i * 8191 + 5) land mask) in
  let t = Array.make (n + 2) 0 in
  for _k = 1 to 400 do
    redc m 0x1234 a b t;
    Array.blit t 0 a 0 n
  done;
  print_int (Array.fold_left (fun (s : int) (x : int) -> (s * 31 + x) land 0xffffff) 0 a);
  print_newline ()
