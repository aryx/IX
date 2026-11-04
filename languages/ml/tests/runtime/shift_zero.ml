(* shifts by a constant, 0 among them: ARM reads an encoded LSR #0 or
 * ASR #0 as a shift by 32, so mini-ld writes LSL #0 (Arm's shift_kind).
 * A local function called with its shift a constant, inlined as
 * Record.put_varint32's (mini-chidb's every record wrong on arm, its
 * last byte 0), and each shift by a literal, against a shift by a
 * variable *)

let bytes v =
  let b = Bytes.make 4 '.' in
  let at i shift more =
    Bytes.set b i (Char.chr (((v lsr shift) land 0x7f) lor if more then 0x80 else 0)) in
  at 0 21 true; at 1 14 true; at 2 7 true; at 3 0 false;
  Bytes.iter (fun c -> print_int (Char.code c); print_char ' ') b

let () =
  let ks = [| 0; 1; 7; 29 |] in
  List.iter (fun (x : int) ->
    bytes x;
    let v = [ x lsr 0; x asr 0; x lsl 0; x lsr 1; x asr 1; x lsl 1; x lsr 7; x asr 7; x lsl 7; x lsr 29; x asr 29 ] in
    let w = [ x lsr ks.(0); x asr ks.(0); x lsl ks.(0); x lsr ks.(1); x asr ks.(1); x lsl ks.(1);
              x lsr ks.(2); x asr ks.(2); x lsl ks.(2); x lsr ks.(3); x asr ks.(3) ] in
    print_string (if v = w then "same " else "DIFFERENT ");
    print_int ((x lsr 0) land 0xffff); print_char ' ';
    print_int ((x asr 0) land 0xffff); print_newline ())
    [ 0; 1; 23; -1; -23; 0x7f; 0x3fff; 1000001; -1000001; 1073741823; -1073741824 ]
