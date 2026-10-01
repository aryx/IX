(* a format's later conversions: %ld an int32, %Ld an int64 (with the
 * flags and the bases of %d), %S and %C as the constant is written *)

let () =
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
  Printf.printf "%d%%%ld%%\n" 50 50l
