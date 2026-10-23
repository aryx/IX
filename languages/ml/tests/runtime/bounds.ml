(* a string's byte read and written by the checked accessors (s.[i],
 * Bytes.set), inline since Lower's strings_in_place: every length
 * against every padding of the last word (0 to 7 bytes), the index
 * just inside and just outside, negative too *)

let try_get s i = try Char.code s.[i] with Invalid_argument _ -> -1
let try_set b i = try Bytes.set b i 'x'; 1 with Invalid_argument _ -> -1

let () =
  for n = 0 to 17 do
    let s = String.init n (fun i -> Char.chr (97 + i)) in
    let b = Bytes.make n 'a' in
    let g = List.map (try_get s) [ -1; 0; n - 1; n; n + 1; max_int ] in
    let p = List.map (try_set b) [ -1; 0; n; n - 1; min_int ] in
    print_int n; print_string ":";
    List.iter (fun x -> print_string " "; print_int x) (g @ p);
    print_string " "; print_endline (Bytes.to_string b)
  done
