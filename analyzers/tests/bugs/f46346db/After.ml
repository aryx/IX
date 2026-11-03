(* f46346db, the fix: a loop along a level, a call for a bracket's inside
 * (as deep as the brackets are nested: reported, a "may") *)
type raw = Open of char | Close of char | T of string
type component = Token of string | Block of char * component list

let closer (c : char) : char = match c with '(' -> ')' | '[' -> ']' | _ -> '}'

let rec components (toks : raw list) (stop : char option) : component list * raw list =
  let rec go acc toks =
    match toks with
    | [] -> (List.rev acc, [])
    | Close c :: rest when Some c = stop -> (List.rev acc, rest)
    | Close c :: rest -> go (Token (String.make 1 c) :: acc) rest
    | Open c :: rest ->
        let inside, rest = components rest (Some (closer c)) in
        go (Block (c, inside) :: acc) rest
    | T t :: rest -> go (Token t :: acc) rest
  in
  go [] toks

let () = ignore (components [ T "a"; Open '{'; T "b"; Close '}' ] None)
