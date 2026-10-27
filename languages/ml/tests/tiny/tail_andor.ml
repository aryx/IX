(* a call on the right of && and of || is a tail call: a loop of a
 * million (is_utf_8's in browsers/html, a frame a character, overflowed
 * mini-ml's stack on a page of 1.3 MB); deeper than tiny-cpu's stack
 * of 32K values and mini-ml's of 8 MB. old: ten million, 34 s a run
 * under tiny-cpu, over the test's 60 on GitHub's four cores *)
let rec all_even n = n = 0 || (n mod 2 = 0 || n mod 2 = 1) && all_even (n - 1)
let rec any_big n = n > 0 && (n = 7 || any_big (n - 1))
let () =
  print_string (if all_even 1000000 then "true" else "false"); print_newline ();
  print_string (if any_big 1000000 then "true" else "false"); print_newline ();
  print_string (if any_big 5 then "true" else "false"); print_newline ()
