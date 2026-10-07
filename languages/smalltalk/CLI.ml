(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

module M = St_memory
module I = St_interp

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-smalltalk [-k blue|squeak|mini] [-i image] [-e expression]... [-o image] [-ppm file] [file.st]...   (-h: how)"

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-smalltalk [-k blue|squeak|mini] [-i image] [-e expression]... [-o image] [-ppm file] [file.st]...
Smalltalk-80 from the Blue Book: its compiler, its interpreter over an object
table, and its system, which is Smalltalk's own text (kernel/*.st), compiled at
the start. For example:
  mini-smalltalk -e '3 + 4' -e '100 factorial printString size'     7, then 158
  mini-smalltalk -e '(1 to: 5) inject: 0 into: [:a :b | a + b]'     15
  mini-smalltalk -e 'Transcript show: 3 printString; cr. nil'       3 (the Transcript's), then nil
  mini-smalltalk Mine.st -e 'Mine new answer'                       a file filed in, then used
  mini-smalltalk                                                    a line an expression, its answer printed
  mini-smalltalk -k squeak -o squeak.image                          Squeak's system brought up, and saved
  mini-smalltalk -i squeak.image -e 'EllipseMorph new bounds'       started from the image: no text compiled
  mini-smalltalk -k mini -ppm atoms.ppm -e 'Smalltalk at: #World put: (WorldMorph bouncingAtoms: 50). World doOneCycle'
                                                                    MiniMorphic's world drawn, the Display written
-k: the system. blue (the default): the Blue Book's. squeak: with Squeak's
closures, colour, Morphic, tools and Etoys. mini: with MiniMorphic, Morphic in
one file. -i: the system is an image's, as -o saved it, and -k is not looked at.
The files are filed in, in order (the chunk format: a class's definition, its
methods after "!Class methodsFor: 'category'!", expressions to run), then each
-e is evaluated and its answer printed as "print it" does; with no -e and no
file, the lines read are. Then the Display is written (-ppm: a PPM picture,
whatever its depth) and the image saved (-o). An error is said and the exit is 1.
There is no window here: what a morph draws is seen with -ppm.|}

(* a file's chunks in a running system: its methods compiled into their
 * classes, its expressions (a class's definition is one) evaluated *)
let file_in (vm : I.vm) (file : string) (text : string) : unit =
  let m = I.memory vm in
  let line (pos : int) : int =
    let n = ref 1 in
    String.iteri (fun (i : int) (c : char) -> if i < pos && c = '\n' then incr n) text;
    !n in
  List.iter
    (fun (item : St_chunk.item) ->
      match item with
      | St_chunk.Methods { class_name; meta; category; methods } ->
          let cls = St_boot.class_named m class_name in
          let cls = if meta then M.class_of m cls else cls in
          List.iter
            (fun ((src, pos) : string * int) ->
              try ignore (St_compile.compile_and_install m ~cls ~category ~declare:true src)
              with St_compile.Error (p, msg) -> failwith (Printf.sprintf "%s:%d: %s" file (line (pos + p)) msg))
            methods
      | St_chunk.Doit (src, pos) -> (
          match I.evaluate vm src with
          | Ok _ -> ()
          | Error msg -> failwith (Printf.sprintf "%s:%d: %s" file (line pos) msg)))
    (St_chunk.read text)

(* the Display as a PPM picture (P6), whatever its depth *)
let ppm (vm : I.vm) : string =
  match I.evaluate vm "Display" with
  | Error msg -> failwith ("Display: " ^ msg)
  | Ok display -> (
      match St_colorblt.rgba (I.memory vm) display with
      | None -> failwith "Display is no Form"
      | Some (w, h, rgba) ->
          let b = Buffer.create ((w * h * 3) + 20) in
          Buffer.add_string b (Printf.sprintf "P6\n%d %d\n255\n" w h);
          for i = 0 to (w * h) - 1 do
            Buffer.add_subbytes b rgba (4 * i) 3
          done;
          Buffer.contents b)

let main (caps : < caps; .. >) (argv : string array) : int =
  let kernel = ref "blue" and image = ref "" and save = ref "" and picture = ref "" in
  let exprs = ref [] and files = ref [] in
  let options = [
    "-k", Arg.Set_string kernel, " blue|squeak|mini: the system brought up";
    "-i", Arg.Set_string image, " image: the system is this image's";
    "-o", Arg.Set_string save, " image: the system saved, at the end";
    "-ppm", Arg.Set_string picture, " file: the Display written, at the end";
    "-e", Arg.String (fun (e : string) -> exprs := e :: !exprs), " expression: evaluated, its answer printed";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  (* (the Transcript's end of line is Smalltalk's, a return) *)
  let host : I.host =
    { St_boot.quiet_host with
      transcript = (fun (s : string) -> Console.print caps (String.map (fun (c : char) -> if c = '\r' then '\n' else c) s)) } in
  let print (vm : I.vm) (text : string) : bool =
    match I.evaluate vm text with
    | Ok v -> Console.print caps (I.print_string vm v ^ "\n"); true
    | Error msg -> Console.eprint caps (msg ^ "\n"); false in
  let path (f : string) : Fpath.t = match FS.path f with Ok p -> p | Error msg -> failwith msg in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      try
        let vm =
          if !image <> "" then St_image.load_vm host (FS.read caps (path !image))
          else
            St_boot.boot host
              (match !kernel with
               | "blue" -> St_kernel.files
               | "squeak" -> St_kernel.squeak
               | "mini" -> St_kernel.mini_morphic
               | k -> failwith ("-k " ^ k ^ ": blue, squeak or mini")) in
        List.iter (fun (f : string) -> file_in vm f (FS.read caps (path f))) (List.rev !files);
        let ok = ref true in
        List.iter (fun (e : string) -> if not (print vm e) then ok := false) (List.rev !exprs);
        if !exprs = [] && !files = [] && !save = "" && !picture = "" then begin
          let chan = Console.stdin caps in
          try
            while true do
              let l = input_line chan in
              if String.trim l <> "" && not (print vm l) then ok := false
            done
          with End_of_file -> ()
        end;
        if !picture <> "" then FS.write caps (path !picture) (ppm vm);
        if !save <> "" then FS.write caps (path !save) (St_image.save (I.memory vm));
        if !ok then 0 else 1
      with
      | Failure msg | Sys_error msg | St_boot.Error msg -> Console.eprint caps (msg ^ "\n"); 1
      | St_chunk.Error (pos, msg) -> Console.eprint caps (Printf.sprintf "chunk at %d: %s\n" pos msg); 1)
