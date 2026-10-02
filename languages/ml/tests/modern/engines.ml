(* shadow: lib_core/parsing *)
(* Lexing's and Parsing's engines (mini-lex's and mini-yacc's run time)
 * on tables made by hand: numbers added, e: e + NUM | NUM. By OCaml
 * with lib_core's two modules in the stdlib's place, then by mini-ml *)
let pack l = String.concat "" (List.map (fun n -> String.init 2 (fun i -> Char.chr ((n lsr (8 * i)) land 255))) l)
type token = NUM of int | PLUS | EOF

(* states: 0 start, 1 digits, 2 spaces, 3 a plus, 4 the end *)
let lex : Lexing.tables =
  let row f = List.init 257 f in
  let digit c = c >= 48 && c <= 57 in
  { trans = pack (List.concat [
      row (fun c -> if digit c then 2 else if c = 32 || c = 10 then 3 else if c = 43 then 4 else if c = 256 then 5 else 0);
      row (fun c -> if digit c then 2 else 0); row (fun c -> if c = 32 || c = 10 then 3 else 0); row (fun _ -> 0); row (fun _ -> 0) ]);
    accept = pack [ 0; 1; 2; 3; 4 ] }

let rec token lexbuf =
  match Lexing.engine lex 0 lexbuf with
  | 0 -> NUM (int_of_string (Lexing.lexeme lexbuf))
  | 1 -> if String.contains (Lexing.lexeme lexbuf) '\n' then Lexing.new_line lexbuf; token lexbuf
  | 2 -> PLUS
  | _ -> EOF

let trace = Buffer.create 64
let yacc : Parsing.tables =
  let shift s = 2 + (2 * s) and reduce r = 3 + (2 * r) in
  { nterms = 3; nnonterms = 2;
    actions = pack [ shift 1; 0; 0;  0; 0; 0;  0; shift 4; shift 3;  0; 0; 0;  shift 6; 0; 0;  0; 0; 0;  0; 0; 0 ];
    defaults = pack [ 0; reduce 2; 0; reduce 0; 0; 1; reduce 1 ];
    gotos = pack [ 3; 6;  0; 0;  0; 0;  0; 0;  0; 0;  0; 0;  0; 0 ];
    lhs = pack [ 1; 0; 0 ]; len = pack [ 2; 3; 1 ];
    reduce = [|
      (fun () -> Parsing.value 1);
      (fun () ->
        let p = Parsing.symbol_start_pos () and q = Parsing.rhs_start_pos 3 in
        Buffer.add_string trace (Printf.sprintf "[%d-%d, $3 at %d:%d]" p.pos_cnum (Parsing.symbol_end ()) q.pos_lnum (q.pos_cnum - q.pos_bol));
        Obj.repr ((Obj.obj (Parsing.value 1) : int) + (Obj.obj (Parsing.value 3) : int)));
      (fun () -> Parsing.value 1) |] }

let parse lexbuf : int =
  Obj.obj (Parsing.run yacc 0 ~number:(function NUM _ -> 0 | PLUS -> 1 | EOF -> 2) ~semantic:(function NUM n -> Obj.repr n | _ -> Obj.repr ()) token lexbuf)

let () =
  let show s = Buffer.clear trace; match parse (Lexing.from_string s) with
    | n -> Printf.printf "%d %s\n" n (Buffer.contents trace)
    | exception Parsing.Parse_error -> print_endline "syntax error"
    | exception Failure m -> print_endline m in
  List.iter show [ "1"; "1 + 2"; "10+20 +\n 300"; "1 +"; "+ 1"; "1 2"; "1 + x"; "" ];
  (* by pieces of 3 characters, a token across two *)
  let text = "123 + 4567 + 89" and at = ref 0 in
  let lexbuf = Lexing.from_function (fun buf n -> let k = min (min n 3) (String.length text - !at) in Bytes.blit_string text !at buf 0 k; at := !at + k; k) in
  Buffer.clear trace;
  let n = parse lexbuf in
  Printf.printf "%d %s %d\n" n (Buffer.contents trace) (Lexing.lexeme_end lexbuf)
