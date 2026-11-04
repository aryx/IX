(* 282b689b: the model a box made again after a key, the window in it
 * changed in place but not compared; and identity meant, a function that
 * knows its windows ("another one"), quiet *)
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
type box = { top : window }

let update (key : string) (b : box) : box =
  b.top.text <- b.top.text ^ key; b.top.cursor <- b.top.cursor + 1;
  { top = b.top }

let front : window list ref = ref []
let raise_ (w : window) : unit =
  (match !front with old :: _ when old != w -> print_string old.text | _ -> ());
  front := w :: List.filter (fun x -> x != w) !front

let () =
  run update (fun b -> b.top.text) { top = { text = ""; cursor = 0 } } [ "a"; "b" ];
  raise_ { text = "x"; cursor = 0 }
