(* a file read back: the runtime's input, which copies what the channel's
 * buffer (4096 bytes) has at once, in pieces of every size around it,
 * with input_char and input_line between them *)

let file = "input_test.tmp"

(* n bytes, each its place's: a piece read wrong is seen *)
let make (n : int) : string = String.init n (fun (i : int) -> Char.chr (32 + ((i * 7) mod 90)))

let write (s : string) : unit =
  let oc = open_out_bin file in
  output_string oc s;
  close_out oc

(* the file read by [input] in pieces of [piece] bytes *)
let read_by (piece : int) : string =
  let ic = open_in_bin file in
  let b = Buffer.create 1024 and buf = Bytes.create (piece + 3) in
  let rec go () =
    (* (at offset 3 in the bytes: an offset is honoured) *)
    let n = input ic buf 3 piece in
    if n > 0 then begin
      Buffer.add_subbytes b buf 3 n;
      go ()
    end in
  go ();
  close_in ic;
  Buffer.contents b

let () =
  List.iter
    (fun (size : int) ->
      let s = make size in
      write s;
      List.iter
        (fun (piece : int) ->
          let got = read_by piece in
          if got <> s then Printf.printf "size %d piece %d: WRONG (%d bytes)\n" size piece (String.length got))
        [ 1; 3; 100; 4095; 4096; 4097; 10000 ];
      Printf.printf "size %d: read back\n" size)
    [ 0; 1; 4095; 4096; 4097; 12289 ];
  (* input_char, input and input_line, one after the other *)
  write "abc\ndefgh\nij";
  let ic = open_in_bin file in
  let c = input_char ic in
  let buf = Bytes.create 4 in
  let n = input ic buf 0 4 in
  let l = input_line ic in
  let rest = input_line ic in
  Printf.printf "%c %d %S %S %S\n" c n (Bytes.sub_string buf 0 n) l rest;
  (try ignore (input_char ic); print_endline "no end" with End_of_file -> print_endline "end of file");
  Printf.printf "input at the end: %d\n" (input ic buf 0 4);
  close_in ic;
  Sys.remove file
