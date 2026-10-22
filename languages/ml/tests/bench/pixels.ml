(* a loop over bytes: mini-doom's to_rgba (games/fps/doom/Doom.ml), a
 * picture of a byte a pixel made four bytes a pixel by its palette *)
let w = 320 and h = 200

let () =
  let src = Bytes.init (w * h) (fun (i : int) -> Char.chr (i * 7 land 255)) in
  let pal = Bytes.init 1024 (fun (i : int) -> Char.chr (i * 13 land 255)) in
  let dst = Bytes.create (w * h * 4) in
  let k = ref 1 in
  for _frame = 1 to 4 do
    for y = 0 to h - 1 do
      let o = ref (y * w * 4) in
      for x = 0 to w - 1 do
        let c = 4 * Char.code (Bytes.unsafe_get src ((y * w) + x)) in
        let r = Bytes.unsafe_get pal c and g = Bytes.unsafe_get pal (c + 1) and b = Bytes.unsafe_get pal (c + 2) in
        for _n = 1 to !k do
          let i = !o in
          Bytes.unsafe_set dst i r;
          Bytes.unsafe_set dst (i + 1) g;
          Bytes.unsafe_set dst (i + 2) b;
          Bytes.unsafe_set dst (i + 3) '\255';
          o := i + 4
        done
      done
    done
  done;
  let sum = ref 0 in
  Bytes.iter (fun (c : char) -> sum := (!sum * 31 + Char.code c) land 0xffffff) dst;
  print_int !sum;
  print_newline ()
