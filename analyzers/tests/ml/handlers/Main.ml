(* the program: what reaches Events's functions *)
let () =
  Events.register { Events.name = "beep"; on_key = Events.beep };
  Events.register { Events.name = "echo"; on_key = (fun (k : int) -> Events.log (k * 2)) };
  Events.dispatch 1;
  Events.twice Events.log 3;
  print_int !Events.beeps
