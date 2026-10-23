(* strings compared by the runtime (compare's word at a time, then its
 * bytes): equal, a prefix, a difference in each byte of the first words
 * and after them, of every length to 20 *)

let s n = String.init n (fun i -> Char.chr (97 + i))
let set t i c = let b = Bytes.of_string t in Bytes.set b i c; Bytes.to_string b

let () =
  for n = 0 to 20 do
    let a = s n in
    let line = ref [ compare a (s n); compare a (s (n + 1)); compare (s (n + 1)) a; compare a a ] in
    for i = 0 to n - 1 do
      line := compare (set a i 'A') a :: compare a (set a i '~') :: !line
    done;
    print_int n; print_string ":";
    List.iter (fun x -> print_string " "; print_int x) (List.rev !line);
    print_string (if a = s n && a <> set (s (n + 1)) n 'z' && [ a ] = [ s n ] then " eq\n" else " NE\n")
  done
