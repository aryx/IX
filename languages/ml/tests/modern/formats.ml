(* a format's later conversions: %ld an int32, %Ld an int64 (with the
 * flags and the bases of %d), %S and %C as the constant is written *)

(* format4: what the function gives in the end is not the printers' *)
exception Bad of string
let error : ('a, unit, string, 'b) format4 -> 'a = fun fmt -> Printf.ksprintf (fun s -> raise (Bad s)) fmt
let log (fmt : ('a, unit, string, int) format4) : 'a = Printf.ksprintf String.length fmt

let () =
  Printf.printf "%d %s\n" (log "%s=%d" "len" 42) (try (if true then error "bad %d at %s" 7 "here" else "ok") with Bad s -> s);
  Printf.printf "%b\n" (try (error "no %c" 'x' : bool) with Bad s -> s = "no x");
  Printf.printf "%ld %ld %lx %lX %lo %lu\n" 42l (-42l) 0xdeadbeefl 0xdeadbeefl 8l (-1l);
  Printf.printf "%Ld %Ld %Lx %LX %Lo %Lu\n" 42L (-42L) 0xdeadbeefcafeL 0xdeadbeefcafeL 8L (-1L);
  Printf.printf "[%8ld] [%-8ld] [%08lx] [%016Lx] [%+Ld] [%20Ld]\n" 42l 42l 0xbeefl 0x1234_5678_9abc_def0L 7L Int64.min_int;
  Printf.printf "%s %d %Ld %s %ld %c\n" "mixed" 1 2L "and" 3l 'c';
  print_endline (Printf.sprintf "MOV\t$%Ld, R%d" 0x7fff_ffff_ffffL 3);
  Printf.printf "%S %S %S\n" "plain" "a \"quoted\"\tone\n" "";
  Printf.printf "%C %C %C %C\n" 'a' '\n' '\'' '\000';
  let b = Buffer.create 16 in
  Printf.bprintf b "%Lx/%lx/%S/%C" 255L 255l "s" 'c';
  print_endline (Buffer.contents b);
  (* %h: a float in hexadecimal *)
  List.iter (fun f -> Printf.printf "%h " f) [ 0.0; -0.0; 1.0; -1.5; 3.0; 0.1; 1e300; 5e-324; 2.2250738585072014e-308; infinity; neg_infinity; 255.0; 0.75 ];
  print_newline ();
  (* a format with some of its arguments is a function as another: used
   * twice, its text is there twice; and nothing is written before the
   * last argument *)
  print_endline (String.concat "," (List.map (Printf.sprintf "R%d") [ 4; 5; 6 ]));
  let reg = Printf.sprintf "%s[%d]" "r" in
  print_endline (reg 1 ^ reg 2);
  let show = Printf.ksprintf (fun s -> "<" ^ s ^ ">") "n=%d s=%s" 7 in
  print_endline (show "a" ^ show "b");
  let later = Printf.printf "first %d, " 1 in
  print_string "[before] ";
  later; print_newline ();
  let p = Printf.printf "(%d %s) " in
  p 1 "x"; p 2 "y"; print_newline ();
  let bb = Buffer.create 8 in
  let add = Printf.bprintf bb "<%d>" in
  add 1; add 2; print_endline (Buffer.contents bb);
  Printf.printf "%d%%%ld%%\n" 50 50l
