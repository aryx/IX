(* f46346db^, browsers/css/Css_syntax.ml: a call for each token of a style
 * sheet, past 62,000 deep on YouTube's, over mini-ml's value stack *)
type raw = Open of char | Close of char | T of string
type component = Token of string | Block of char * component list

let closer (c : char) : char = match c with '(' -> ')' | '[' -> ']' | _ -> '}'

let rec components (toks : raw list) (stop : char option) : component list * raw list =
  match toks with
  | [] -> ([], [])
  | Close c :: rest when Some c = stop -> ([], rest)
  | Close c :: rest ->
      let cs, rest = components rest stop in
      (Token (String.make 1 c) :: cs, rest)
  | Open c :: rest ->
      let inside, rest = components rest (Some (closer c)) in
      let cs, rest = components rest stop in
      (Block (c, inside) :: cs, rest)
  | T t :: rest ->
      let cs, rest = components rest stop in
      (Token t :: cs, rest)

let () = ignore (components [ T "a"; Open '{'; T "b"; Close '}' ] None)
