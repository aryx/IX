(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-asm [-m 5|7] [-o out] [-data name=file]... [file.s]
Plan 9's assembler, 5a (-m 5: arm, the default) or 7a (-m 7: arm64): a .s
file in Plan 9's syntax to its object, file.5 or file.7 (-o: another name), for
mini-ld. With goken's hello (~/goken/tests/s/hello_arch/), for example:
  mini-asm -m 5 hello_linux_arm.s                      hello_linux_arm.5
  mini-ld -m 5 -E _start -o hello hello_linux_arm.5    an ELF (-H2: Plan 9's)
  mini-5i hello                                        Hello, world
  mini-asm -m 7 hello_linux_arm64.s                    the same on arm64
The syntax, the source first: TEXT _start(SB), $0 (a function, its frame);
MOVW $1, R0; SWI $0; GLOBL msg(SB), $13; DATA msg+0(SB)/8, $"Hello, w".
An error names the file and the line: file.s:3: ...; an unknown instruction,
at the link (mini-ld: file.s:3: unknown opcode FOO), which encodes them.
-data name=file: the file's bytes as name's data, one DATA of them all and its
GLOBL, after the .s file's items (a kernel's disk and font: no DATA line
per word, which made a 7 MB disk 73 MB of text):
  mini-asm -m 5 -data fs_image=fs.img -data font=font1.bin -o images.5 sizes.s
|}

let usage = "usage: mini-asm [-m 5|7] [-o out] [-data name=file]... [file.s]   (-h: how)"

(* -data's items: the bytes one DATA, a string of their length (the
 * linker copies it as it does a DATA's $"text"), and their GLOBL *)
let data_items (caps : < caps; .. >) (datas : (string * string) list) : (Asm.item * int) list =
  List.concat_map (fun (name, file) ->
    let bytes = FS.read caps (Fpath.v file) in
    let n : Asm.name = { sym = name; static = false } in
    let size = String.length bytes in
    [ (Asm.Data (n, 0L, size, Asm.Str bytes), 0); (Asm.Globl (n, 0, Int64.of_int size), 0) ])
    datas

let main (caps : < caps; .. >) (argv : string array) : int =
  let arch = ref Asm.Arm and out = ref "" and files = ref [] and datas = ref [] in
  let data (s : string) =
    match String.index_opt s '=' with
    | Some i -> datas := (String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1)) :: !datas
    | None -> raise (Arg.Bad ("-data " ^ s ^ ": name=file")) in
  let options = [
    "-m", Arg.String (function "5" -> arch := Asm.Arm | "7" -> arch := Asm.Arm64 | m -> raise (Arg.Bad ("-m " ^ m ^ ": 5 or 7"))), " 5|7: arm or arm64";
    "-o", Arg.Set_string out, " out: the object's name";
    "-data", Arg.String data, " name=file: the file's bytes as name's data";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage; List.map FS.path !files with
  | exception Arg.Help _ -> Console.print caps help; 0
  | exception Arg.Bad m -> eprint caps m; 1
  | [] when !datas <> [] && !out <> "" ->
      let obj : Asm.obj = { arch = !arch; file = Fpath.v !out; items = [||]; history = []; acid = [] } in
      (match data_items caps (List.rev !datas) with
       | items -> Asm.save caps (Fpath.v !out) { obj with items = Array.of_list items }; 0
       | exception Sys_error m -> eprint caps (m ^ "\n"); 1)
  | [ Ok file ] -> (
      match Parser_asm.parse caps !arch file (FS.read caps file) with
      | obj ->
          let ext = match !arch with Asm.Arm -> ".5" | Asm.Arm64 -> ".7" in
          let out = if !out <> "" then Fpath.v !out else Fpath.set_ext ext (Fpath.base file) in
          (* (after the file's: a branch's Target is an index of its items) *)
          let items = Array.append obj.items (Array.of_list (data_items caps (List.rev !datas))) in
          Asm.save caps out { obj with items };
          0
      | exception Parser_asm.Error (l, m) -> eprint caps (Printf.sprintf "%s:%d: %s\n" (Fpath.to_string file) l m); 1
      | exception Sys_error m -> eprint caps (m ^ "\n"); 1)
  | [ Error m ] -> eprint caps ("mini-asm: " ^ m ^ "\n"); 1
  | _ -> eprint caps (usage ^ "\n"); 1
