(* division and remainder by a constant power of two (shifts, Emit's),
 * against a division by a variable: negatives, round toward 0 *)

let () =
  let ds = [| 2; 4; 8; 64; 2; 1 |] in
  List.iter (fun (x : int) ->
    let v = [ x / 2; x mod 2; x / 4; x mod 4; x / 8; x mod 8; x / 64; x mod 64 ] in
    let w = [ x / ds.(0); x mod ds.(0); x / ds.(1); x mod ds.(1); x / ds.(2); x mod ds.(2); x / ds.(3); x mod ds.(3) ] in
    List.iter (fun r -> print_int r; print_char ' ') v;
    print_endline (if v = w then "same" else "DIFFERENT"))
    [ 0; 1; -1; 2; -2; 3; -3; 7; -7; 8; -8; 63; -63; 64; -64; 65; -65; 1000001; -1000001; 1073741823; -1073741824 ]
