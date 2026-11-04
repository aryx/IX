(* 282b689b^, lib_terminal/hosts/draw/Window_draw.ml and mini-emacs's
 * Top_window: the screen painted when the model is another value than the
 * one shown (m != !model), a model of any program's ('model); mini-emacs's
 * was its top window, one record a key changes in place, never another:
 * nothing painted after the first screen *)
let run (update : string -> 'model -> 'model) (view : 'model -> string)
    (init : 'model) (keys : string list) : unit =
  let model = ref init and drawn : 'model option ref = ref None in
  let paint () =
    if (match !drawn with Some m -> m != !model | None -> true) then begin
      print_string (view !model);
      drawn := Some !model
    end in
  List.iter (fun k -> model := update k !model; paint ()) keys

type window = { mutable text : string; mutable cursor : int }

let update (key : string) (w : window) : window =
  w.text <- w.text ^ key; w.cursor <- w.cursor + 1; w

let () = run update (fun w -> w.text) { text = ""; cursor = 0 } [ "a"; "b" ]
