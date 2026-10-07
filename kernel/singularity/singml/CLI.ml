(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-singml [-o dir] Name.contract
mini-singularity's contracts (kernel/singularity): a contract's declaration to
its module in OCaml, Name.ml and Name.mli (-o: in that directory), written
over lib/Contract and lib/Sip, for mini-ml to compile. For example:
  mini-singml -o out contracts/Intro.contract     out/Intro.ml, out/Intro.mli: 1 message, 2 states
A declaration is in OCaml's syntax, read by mini-ml's parser:
  type request = Ping of int | Text of Sip.block * int    the messages: a type's
  type reply = Ready | Pong of int | Thanks               are all one end's
  let rec start = send Ready; serve                       the states, the first
  and serve = function                                    the start, said from the
    | Ping _ -> send Pong; serve                          exporting end (the server's):
    | Text _ -> send Thanks; serve                        a message received, or sent
A state: function | M _ -> s | ... (one of them received), send M; s (sent),
s1 || s2 (one or the other sent), a state's name, or () (nothing more). A
message's arguments: an int at most, and a Sip.block or another contract's end
(Pong.imp) at most. The module has the contract's value (the kernel checks each
message against it), the types imp and exp, and Imp and Exp, each with an
operation a message it sends (Imp.ping e 3), receive, of_endpoint, endpoint and
close: a message of the other end's, or with a wrong argument, does not compile.
An error names the file and the line: Intro.contract:3: ...
|}

let usage = "usage: mini-singml [-o dir] Name.contract   (-h: how)"

(* a declaration's tree: mini-ml's, of a structure *)
let parse (file : string) (text : string) : (Ast.structure, string) result =
  let lexbuf = Lexing.from_string text in
  let where () = Printf.sprintf "%s:%d" file lexbuf.lex_curr_p.pos_lnum in
  try Ok (Parser.implementation Lexer.token lexbuf) with
  | Parser.Error | Parsing.Parse_error -> Error (where () ^ ": syntax error")
  | Lexer.Error m -> Error (where () ^ ": " ^ m)

let main (caps : < caps; .. >) (argv : string array) : int =
  let dir = ref "" and files = ref [] in
  let options = [
    "-o", Arg.Set_string dir, " dir: where the module is written";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage; List.map FS.path !files with
  | exception Arg.Help _ -> Console.print caps help; 0
  | exception Arg.Bad m -> Console.eprint caps m; 1
  | [ Ok file ] -> (
      let source = Fpath.to_string file in
      let name = Fpath.to_string (Fpath.base (Fpath.rem_ext file)) in
      match parse source (FS.read caps file) with
      | Error m -> Console.eprint caps (m ^ "\n"); 1
      | exception Sys_error m -> Console.eprint caps (m ^ "\n"); 1
      | Ok tree -> (
          match Description.read name tree with
          | exception Description.Error (l, m) -> Console.eprint caps (Printf.sprintf "%s:%d: %s\n" source l m); 1
          | c ->
              let out (ext : string) : Fpath.t =
                let f = Fpath.v (name ^ ext) in
                if !dir = "" then Fpath.append (Fpath.parent file) f else Fpath.append (Fpath.v !dir) f in
              FS.write caps (out ".ml") (Output.ml source c);
              FS.write caps (out ".mli") (Output.mli source c);
              let count (n : int) (what : string) : string = Printf.sprintf "%d %s%s" n what (if n = 1 then "" else "s") in
              Console.print caps (Printf.sprintf "%s, %s: %s, %s\n" (Fpath.to_string (out ".ml")) (Fpath.to_string (out ".mli"))
                (count (Array.length c.messages) "message") (count (Array.length c.states) "state"));
              0))
  | [ Error m ] -> Console.eprint caps ("mini-singml: " ^ m ^ "\n"); 1
  | _ -> Console.eprint caps (usage ^ "\n"); 1
