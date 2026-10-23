(* strings made each way compared by = and <> (the runtime's word
 * equality, which counts on a string's padding being 0), typed as
 * strings and through a polymorphic function, of every length to 20 *)

let file = "string_equal.tmp"

let ways n =
  let s = String.init n (fun i -> Char.chr (97 + i)) in
  let b = Bytes.create n in
  for i = 0 to n - 1 do Bytes.set b i (Char.chr (97 + i)) done;
  let buf = Buffer.create 1 in
  String.iter (Buffer.add_char buf) s;
  let oc = open_out file in
  output_string oc s; output_char oc '\n'; close_out oc;
  let ic = open_in file in
  let read = input_line ic in
  close_in ic;
  let long = String.init (n + 5) (fun i -> Char.chr (97 + (i mod 26))) in
  [ s; Bytes.to_string b; Buffer.contents buf; read; String.sub long 0 n;
    (if n = 0 then "" else String.sub s 0 (n - 1) ^ String.make 1 s.[n - 1]) ]

let poly_eq a b = a = b

let () =
  for n = 0 to 20 do
    let ws = ways n in
    let all = List.for_all (fun a -> List.for_all (fun b -> a = b && not (a <> b) && poly_eq a b) ws) ws in
    let other = String.make n 'z' ^ "!" in
    let none = List.for_all (fun a -> a <> other && not (a = other) && not (poly_eq a other)) ws in
    print_int n; print_string (if all && none then " ok\n" else " DIFFER\n")
  done;
  Sys.remove file
