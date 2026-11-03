(* eb5378a5^, editors/turbopascal/hosts/draw/Window.ml: a Some made in the
 * test is never the one kept, so every tick painted the whole screen *)
let loop (view : int -> string) (next : int -> int) (over : int -> bool) =
  let model = ref 0 and drawn = ref None in
  while not (over !model) do
    if !drawn != Some !model then begin
      print_string (view !model);
      drawn := Some !model
    end;
    model := next !model
  done
