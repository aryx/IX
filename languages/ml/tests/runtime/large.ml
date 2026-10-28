(* Large blocks of no pointers (bytes, float arrays), which the runtime
 * makes outside its halves (gc.c's large): kept ones read back after
 * collections, many made and dropped (their memory given back: run
 * with /usr/bin/time, the program stays small), small blocks between *)

let mb = 1024 * 1024

let () =
  let kept = Bytes.make (5 * mb) 'k' in
  let floats = Float.Array.make 700_000 1.5 in
  let small = ref [] in
  for i = 1 to 60 do
    let b = Bytes.make (5 * mb) (Char.chr (65 + i mod 26)) in
    Bytes.set b (i * 1000) '!';
    small := List.init 1000 (fun j -> j * i) :: !small;
    if List.length !small > 5 then small := [];
    if i mod 20 = 0 then begin
      Gc.compact ();
      Printf.printf "%d %c %c %d\n" i (Bytes.get b 0) (Bytes.get b (i * 1000)) (Bytes.length b)
    end
  done;
  Float.Array.set floats 699_999 2.5;
  Gc.compact ();
  Printf.printf "%c %c %d %g %g\n" (Bytes.get kept 0) (Bytes.get kept (5 * mb - 1))
    (Bytes.length kept) (Float.Array.get floats 0) (Float.Array.get floats 699_999);
  let s = Bytes.to_string kept in
  Gc.compact ();
  Printf.printf "%d %b\n" (String.length s) (String.equal s (Bytes.to_string kept))
