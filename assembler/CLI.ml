(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-asm -m 5|7 [-o out] file.s
Plan 9's assembler, 5a (-m 5: arm) or 7a (-m 7: arm64): a .s file in Plan 9's
syntax to its object, file.5 or file.7 (-o: another name), for mini-ld. With
goken's hello (~/goken/tests/s/hello_arch/), for example:
  mini-asm -m 5 hello_linux_arm.s                      hello_linux_arm.5
  mini-ld -m 5 -E _start -o hello hello_linux_arm.5    an ELF (-H2: Plan 9's)
  mini-5i hello                                        Hello, world
  mini-asm -m 7 hello_linux_arm64.s                    the same on arm64
The syntax, the source first: TEXT _start(SB), $0 (a function, its frame);
MOVW $1, R0; SWI $0; GLOBL msg(SB), $13; DATA msg+0(SB)/8, $"Hello, w".
An error names the file and the line: file.s:3: ...; an unknown instruction,
at the link (mini-ld: file.s:3: unknown opcode FOO), which encodes them.
|}

let usage = "usage: mini-asm -m 5|7 [-o out] file.s   (-h: how)"

let main (caps : < caps; .. >) (argv : string array) : int =
  let arch = ref Asm.Arm and out = ref "" and files = ref [] in
  let options = [
    "-m", Arg.String (function "5" -> arch := Asm.Arm | "7" -> arch := Asm.Arm64 | m -> raise (Arg.Bad ("-m " ^ m ^ ": 5 or 7"))), " 5|7: arm or arm64";
    "-o", Arg.Set_string out, " out: the object's name";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage; List.map FS.path !files with
  | exception Arg.Help _ -> Console.print caps help; 0
  | exception Arg.Bad m -> eprint caps m; 1
  | [ Ok file ] -> (
      match Parser_asm.parse caps !arch file (FS.read caps file) with
      | obj ->
          let ext = match !arch with Asm.Arm -> ".5" | Asm.Arm64 -> ".7" in
          let out = if !out <> "" then Fpath.v !out else Fpath.set_ext ext (Fpath.base file) in
          Asm.save caps out obj;
          0
      | exception Parser_asm.Error (l, m) -> eprint caps (Printf.sprintf "%s:%d: %s\n" (Fpath.to_string file) l m); 1
      | exception Sys_error m -> eprint caps (m ^ "\n"); 1)
  | [ Error m ] -> eprint caps ("mini-asm: " ^ m ^ "\n"); 1
  | _ -> eprint caps (usage ^ "\n"); 1
