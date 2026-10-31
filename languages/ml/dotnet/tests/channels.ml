(* the runtime unit's channels (lib_core/dotnet/Runtime.ml): Pervasives'
 * externals of C, named here as Pervasives names them: the console's
 * streams, a file written, read, sought, appended to, sys_open's
 * errors; bytes, a byte[]; sys_exit *)

external open_descriptor_out : int -> out_channel = "caml_open_descriptor"
external open_descriptor_in : int -> in_channel = "caml_open_descriptor"
external open_desc : string -> open_flag list -> int -> int = "sys_open"
external flush : out_channel -> unit = "caml_flush"
external unsafe_output : out_channel -> string -> int -> int -> unit = "caml_output"
external output_char : out_channel -> char -> unit = "caml_output_char"
external output_byte : out_channel -> int -> unit = "caml_output_char"
external output_binary_int : out_channel -> int -> unit = "caml_output_int"
external pos_out : out_channel -> int = "caml_pos_out"
external close_out_channel : out_channel -> unit = "caml_close_channel"
external input_char_or : in_channel -> int = "ml_input_char"
external input_or : in_channel -> bytes -> int -> int -> int = "caml_input"
external scan_line_or : in_channel -> int = "caml_input_scan_line"
external input_binary_int : in_channel -> int = "caml_input_int"
external seek_in : in_channel -> int -> unit = "caml_seek_in"
external pos_in : in_channel -> int = "caml_pos_in"
external in_channel_length : in_channel -> int = "caml_channel_size"
external close_in : in_channel -> unit = "caml_close_channel"
external string_create : int -> bytes = "create_string"
external string_blit : string -> int -> bytes -> int -> int -> unit = "blit_string"
external bts : bytes -> string = "%identity"
external stb : string -> bytes = "%identity"
external bytes_length : bytes -> int = "%string_length"
external bget : bytes -> int -> char = "%string_safe_get"
external bset : bytes -> int -> char -> unit = "%string_safe_set"
external sys_exit : int -> 'a = "sys_exit"

let out = open_descriptor_out 1
let output_string (oc : out_channel) (s : string) = unsafe_output oc s 0 (String.length s)
let say (s : string) = output_string out s; output_char out '\n'
let say_int (n : int) = say (string_of_int n)

(* Pervasives' input_line, over scan_line and input *)
let rec input_line (ic : in_channel) : string =
  let n = scan_line_or ic in
  if n = 0 then raise End_of_file
  else if n > 0 then begin
    let s = string_create (n - 1) in
    ignore (input_or ic s 0 (n - 1));
    ignore (input_char_or ic);
    bts s
  end else begin
    let s = string_create (- n) in
    ignore (input_or ic s 0 (- n));
    try bts s ^ input_line ic with End_of_file -> bts s
  end

let close_out (oc : out_channel) = flush oc; close_out_channel oc

let () =
  (* the console *)
  output_string out "hello, "; output_char out 'w'; output_byte out 111;
  say "rld";
  (* bytes *)
  let b = string_create 5 in
  string_blit "abcde" 0 b 0 5;
  bset b 0 'A';
  say (bts b); say_int (bytes_length b); output_char out (bget b 4); output_char out '\n';
  let b2 = stb "xyz" in bset b2 1 'Y'; say (bts b2);
  (* a file written *)
  let fd = open_desc "channels.tmp" [ Open_wronly; Open_creat; Open_trunc ] 0o666 in
  let oc = open_descriptor_out fd in
  output_string oc "first line\nsecond line\n";
  output_binary_int oc (-5); output_binary_int oc 300;
  output_string oc "no newline";
  say_int (pos_out oc);
  close_out oc;
  (* read *)
  let ic = open_descriptor_in (open_desc "channels.tmp" [ Open_rdonly ] 0) in
  say_int (in_channel_length ic);
  say (input_line ic); say (input_line ic);
  say_int (input_binary_int ic); say_int (input_binary_int ic);
  say_int (pos_in ic);
  say (input_line ic);
  (try ignore (input_line ic); say "no end?" with End_of_file -> say "End_of_file");
  say_int (input_char_or ic);
  seek_in ic 6; say (input_line ic);
  close_in ic;
  (* appended *)
  let oc = open_descriptor_out (open_desc "channels.tmp" [ Open_wronly; Open_append ] 0) in
  output_string oc "\nappended\n"; close_out oc;
  let ic = open_descriptor_in (open_desc "channels.tmp" [ Open_rdonly ] 0) in
  say_int (in_channel_length ic);
  seek_in ic 31; say (input_line ic); say (input_line ic);
  close_in ic;
  (* sys_open's errors: Sys_error, the name *)
  (try ignore (open_desc "not-there.tmp" [ Open_rdonly ] 0) with Sys_error m -> say ("Sys_error " ^ m));
  (try ignore (open_desc "channels.tmp" [ Open_wronly; Open_creat; Open_excl ] 0o666) with Sys_error m -> say ("Sys_error " ^ m));
  (* the standard input (channels.in), a line longer than the buffer *)
  let ic = open_descriptor_in 0 in
  say (input_line ic);
  say_int (String.length (input_line ic));
  say (input_line ic);
  (try ignore (input_line ic) with End_of_file -> say "End_of_file");
  flush out;
  sys_exit 0;
  say "not reached"; flush out
