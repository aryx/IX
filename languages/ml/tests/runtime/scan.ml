(* the collector's scan (gc.c's scan_copies; scan_arm.s, scan_arm64.s):
 * a block's fields after one that is a large block (marked in a major
 * collection, a call of C's from the scan) copied too; a block shared,
 * copied once; a deep list (the scan chasing next) *)
type r = {
  name : string;
  big : string;
  list : int list;
  table : (int * string) array;
}

let make (k : int) : r =
  { name = "r" ^ string_of_int k;
    big = String.make 3_000_000 (Char.chr (65 + k));
    list = List.init 1000 (fun (i : int) -> i * k);
    table = Array.init 5000 (fun (i : int) -> (i, string_of_int (i + k))) }

let () =
  let rs = ref [] in
  for k = 0 to 3 do
    rs := make k :: !rs;
    (* garbage, for the majors *)
    for _i = 1 to 20 do ignore (Bytes.create 1_000_000) done;
    Gc.full_major ()
  done;
  let shared = List.init 100 (fun (i : int) -> i) in
  let pair = (shared, shared) in
  Gc.full_major ();
  List.iter (fun (r : r) ->
    Printf.printf "%s %c %d %d %s\n" r.name r.big.[2_999_999]
      (List.length r.list) (List.fold_left ( + ) 0 r.list)
      (snd r.table.(4999))) (List.rev !rs);
  Printf.printf "%b %d\n" (fst pair == snd pair)
    (List.fold_left ( + ) 0 (fst pair))
