(* Hashtbl as OCaml's: a table filled by replace grows (lib_core's did
 * not: 100,000 keys were minutes), a key is compared by compare (a nan
 * is found and removed), replace keeps one binding and add hides one *)

let () =
  let n = 100000 in
  let t : (int array, int) Hashtbl.t = Hashtbl.create 61 in
  for i = 0 to n - 1 do Hashtbl.replace t [| i; i / 7 |] i done;
  for i = 0 to n - 1 do if i mod 3 = 0 then Hashtbl.replace t [| i; i / 7 |] (- i) done;
  let sum = ref 0 in
  for i = 0 to n - 1 do sum := !sum + Hashtbl.find t [| i; i / 7 |] done;
  Printf.printf "%d keys, sum %d\n" (Hashtbl.length t) !sum;
  Printf.printf "absent: %b %b\n" (Hashtbl.mem t [| n; 0 |]) (Hashtbl.find_opt t [| 0; 1 |] = None);
  Printf.printf "in time: %b\n" (Sys.time () < 20.0);
  let total = Hashtbl.fold (fun (_ : int array) (v : int) (acc : int) -> acc + v) t 0 in
  Printf.printf "fold %b\n" (total = !sum)

let () =
  let t : (float, string) Hashtbl.t = Hashtbl.create 7 in
  Hashtbl.add t nan "nan";
  Hashtbl.add t 1.5 "one";
  Printf.printf "nan: %b %s %d\n" (Hashtbl.mem t nan) (Hashtbl.find t nan) (List.length (Hashtbl.find_all t nan));
  Hashtbl.replace t nan "again";
  Printf.printf "replaced: %s, %d bindings\n" (Hashtbl.find t nan) (Hashtbl.length t);
  Hashtbl.remove t nan;
  Printf.printf "removed: %b, %d bindings\n" (Hashtbl.mem t nan) (Hashtbl.length t)

let () =
  let t : (string, int) Hashtbl.t = Hashtbl.create 1 in
  Hashtbl.add t "a" 1;
  Hashtbl.add t "a" 2;
  Hashtbl.replace t "a" 3;
  Printf.printf "a: %d, all %s\n" (Hashtbl.find t "a")
    (String.concat " " (List.map string_of_int (Hashtbl.find_all t "a")));
  Hashtbl.remove t "a";
  Printf.printf "a: %d\n" (Hashtbl.find t "a");
  Hashtbl.remove t "a";
  Printf.printf "a: %b\n" (Hashtbl.mem t "a")
