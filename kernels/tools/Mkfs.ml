(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkfs: an image of xv6's file system with files in it (xv6's
 * mkfs.c; the format and the code are ../9pi/filesystems/lib_xv6fs's,
 * which mini-9pi's kernel reads and writes it with: Kfs), for an SD
 * card's second partition (mini-mkcard -fs). The usage: [help]. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let help = {|usage: mini-mkfs [-m megabytes] [-b blocksize] out name=file|directory/...
An image of xv6's file system (with ix's larger files: lib_xv6fs), its files
the ones named; a name with / makes the directories on its way, and a name
that ends with / is a directory, empty.
  mini-mkfs fs.img readme=README.md bin/hello=hello usr/pad/ tmp/
                              32 MB, blocks of 1024 bytes: /readme, /bin/hello,
                              and two empty directories, /usr/pad and /tmp
  mini-mkfs -m 8 -b 512 fs.img ...
                              8 MB, blocks of 512 bytes
  mini-mkcard -fs fs.img card.img ...
                              the image as a card's second partition
A name is 14 characters at most (xv6's).
|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let megabytes = ref 32 and bsize = ref 1024 in
  let rec options = function
    | "-m" :: n :: rest when int_of_string_opt n <> None -> megabytes := int_of_string n; options rest
    | "-b" :: n :: rest when int_of_string_opt n <> None -> bsize := int_of_string n; options rest
    | rest -> rest in
  match options (List.tl (Array.to_list argv)) with
  | args when List.mem "-h" args || List.mem "--help" args -> Console.print caps help; 0
  | out :: pairs -> (
      (* the device is memory: the image, written at the end *)
      let size = !megabytes * 1024 * 1024 in
      let disk = Bytes.make size '\000' in
      let read at n = if at >= size then "" else Bytes.sub_string disk at (min n (size - at)) in
      let write at s = Bytes.blit_string s 0 disk at (String.length s) in
      try
        let t = Xv6fs.format read write (size / !bsize) !bsize 200 in
        (* a directory of a directory: found, or made *)
        let down dir name = match Xv6fs.lookup t dir name with Some i -> i | None -> Xv6fs.create t dir name Xv6fs.Dir in
        let names s = List.filter (fun n -> n <> "") (String.split_on_char '/' s) in
        List.iter (fun pair ->
          match String.index_opt pair '=' with
          | None when pair <> "" && pair.[String.length pair - 1] = '/' -> ignore (List.fold_left down Xv6fs.root (names pair))
          | None -> failwith (pair ^ ": not name=file, nor directory/")
          | Some k ->
              let data = FS.read caps (Fpath.v (String.sub pair (k + 1) (String.length pair - k - 1))) in
              (* the directories on the way, then the file *)
              let rec place dir = function
                | [ name ] -> Xv6fs.write t (Xv6fs.create t dir name Xv6fs.File) 0 data
                | name :: more -> place (down dir name) more
                | [] -> failwith (pair ^ ": no name") in
              place Xv6fs.root (names (String.sub pair 0 k))) pairs;
        FS.write caps (Fpath.v out) (Bytes.to_string disk);
        0
      with Sys_error m | Failure m -> Console.eprint caps ("mini-mkfs: " ^ m ^ "\n"); 1)
  | _ -> Console.eprint caps "usage: mini-mkfs [-m megabytes] [-b blocksize] out name=file|directory/...   (-h: how)\n"; 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-mkfs"; CapStdlib.exit caps (main caps (CapSys.argv caps)))
