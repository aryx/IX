(* eb5378a5, the fix: the model itself compared *)
let loop (view : int -> string) (next : int -> int) (over : int -> bool) =
  let model = ref 0 and drawn = ref None in
  while not (over !model) do
    if (match !drawn with Some m -> m != !model | None -> true) then begin
      print_string (view !model);
      drawn := Some !model
    end;
    model := next !model
  done

(* look-alikes: [] and a constant constructor are no blocks; a string
 * compared by = *)
let empty (l : int list) = l == []
let none (o : int option) = o != None
let same (s : string) = s = "abc"
