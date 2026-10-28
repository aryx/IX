(* a loop's index arithmetic: a product of two matrices kept flat in
 * arrays (row i at i * n), as a picture's rows and a mesh's vertices
 * are; i * n the same at each turn of the loops inside (Licm), and
 * c's index computed for its read and its write (Cse) *)
let n = 48

let () =
  let a = Array.init (n * n) (fun (i : int) -> (i * 7) land 15) in
  let b = Array.init (n * n) (fun (i : int) -> (i * 13) land 15) in
  let c = Array.make (n * n) 0 in
  for _round = 1 to 4 do
    for i = 0 to n - 1 do
      for j = 0 to n - 1 do
        for k = 0 to n - 1 do
          let p = a.((i * n) + k) * b.((k * n) + j) in
          c.((i * n) + j) <- (c.((i * n) + j) + p) land 0xffffff
        done
      done
    done
  done;
  let sum = ref 0 in
  Array.iter (fun (x : int) -> sum := (!sum * 31 + x) land 0xffffff) c;
  print_int !sum;
  print_newline ()
