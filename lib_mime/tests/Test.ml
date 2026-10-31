(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* lib_mime's tests: each kind from the repository's own sample files,
 * or from its magic where there is no sample; the rules *)

let check = Alcotest.(check string)

let samples =
  [ ("lib_graphics/pdf/tests/data/shapes.pdf", "application/pdf");
    ("browsers/netscape/tests/pages/colors.png", "image/png");
    ("browsers/netscape/tests/pages/noise.gif", "image/gif");
    ("browsers/netscape/tests/pages/photo.jpg", "image/jpeg");
    ("games/fps/quake/data/sound/buttons/airbut1.wav", "audio/wav");
    ("lib_audio/tests/data/bell.mp2", "audio/mpeg");
    ("lib_audio/tests/data/lame_encoded.mp3", "audio/mpeg");
    ("lib_audio/tests/data/korobeiniki.mid", "audio/midi");
    ("lib_audio/tests/data/korobeiniki.abc", "text/x-abc");
    ("lib_audio/tests/data/stereo.ogg", "audio/ogg");
    ("lib_audio/tests/data/tiny_soundtracker.mod", "audio/x-mod");
    ("browsers/engine/tests/pages/small.html", "text/html");
    ("kernels/9pi/tests/hellodraw.ppm.gz", "application/gzip");
    ("lib_mime/File_kind.ml", "text/plain");
    ("license.txt", "text/plain") ]

(* the repository's top, whichever directory Testo runs from *)
let rec top (dir : string) : string =
  if Sys.file_exists (Filename.concat dir "license.txt") && Sys.file_exists (Filename.concat dir "lib_mime") then dir
  else if Filename.dirname dir = dir then failwith "the repository's top not found"
  else top (Filename.dirname dir)

let from_samples (caps : < Cap.open_in ; .. >) () =
  let root = top (Sys.getcwd ()) in
  List.iter (fun (path, kind) -> check path kind (File_kind.of_path caps (Fpath.v (Filename.concat root path)))) samples

let magics () =
  let is (what : string) (kind : string) (bytes : string) = check what kind (File_kind.of_file ~name:"x" bytes) in
  is "AVI, WAV's container" "video/x-msvideo" "RIFF\000\000\000\000AVI LIST";
  is "a video stream" "video/mpeg" "\000\000\001\xB3xxxx";
  is "an .mpg" "video/mpeg" "\000\000\001\xBAxxxx";
  is "Y4M" "video/x-y4m" "YUV4MPEG2 W4 H4";
  is "FLI" "video/x-flic" ("\000\000\000\000\x11\xAF" ^ String.make 122 '\000');
  is "two bytes of FLI's in a short file: not one" "application/octet-stream" "\000\000\000\000\x11\xAF";
  is "a document of mini-office's" "application/x-office" "TinyOffice 1\n\132\149";
  is "Plan 9's a.out, arm" "application/x-executable" "\000\000\006\071\000";
  is "Plan 9's a.out, arm64" "application/x-executable" "\000\000\140\071\000";
  is "ELF" "application/x-executable" "\127ELF\002";
  is "a script" "text/x-script" "#!/bin/sh\n";
  is "HTML, after blanks, in capitals" "text/html" "\n  <!DOCTYPE HTML>";
  is "iCalendar" "text/calendar" "BEGIN:VCALENDAR\r\n";
  is "vCard" "text/vcard" "BEGIN:VCARD\r\n";
  is "nothing" "text/plain" "";
  is "not text, and no magic" "application/octet-stream" "\001\002\003"

let names () =
  let is (what : string) (kind : string) (name : string) (bytes : string) = check what kind (File_kind.of_file ~name bytes) in
  is "the bytes before the name" "image/png" "lies.wav" "\137PNG\r\n\026\n";
  is "a module without a tag" "audio/x-mod" "song.MOD" "\001\002\003";
  is "HTML without its tag" "text/html" "a.html" "<p>hello";
  is "a name of no help" "text/plain" "notes" "hello\n"

let rules () =
  let rules = Helpers.of_mailcap "# a comment\nimage/*; feh %s\nvideo/mpeg; mpv --fs %s; needsterminal\n" @ Helpers.defaults in
  let program (kind : string) = match Helpers.for_type rules kind with Some r -> Helpers.name r | None -> "none" in
  check "a mailcap's type/*" "feh" (program "image/png");
  check "a mailcap's before the built-in" "mpv" (program "video/mpeg");
  check "the built-in, a PDF file" "mini-page" (program "application/pdf");
  check "the built-in, text" "mini-emacs" (program "text/plain");
  check "a sound" "mini-play" (program "audio/mpeg");
  check "a film" "mini-play" (program "video/x-msvideo");
  check "a mailcap's image/* over the built-in GIF" "feh" (program "image/gif");
  check "a GIF, which may be a film, built in" "mini-play"
    (match Helpers.for_type Helpers.defaults "image/gif" with Some r -> Helpers.name r | None -> "none");
  check "a tune, not as any text" "mini-play" (program "text/x-abc");
  check "HTML, not as any text" "mini-netscape" (program "text/html");
  check "nothing for what is not known" "none" (program "application/octet-stream");
  match Helpers.for_type rules "video/mpeg" with
  | Some r -> Alcotest.(check (list string)) "the file in the command" [ "mpv"; "--fs"; "f.mpg" ] (Helpers.command r ~url:"f.mpg" ~file:(Some "f.mpg"))
  | None -> Alcotest.fail "no rule"

let () =
  Cap.main (fun caps ->
      Testo.interpret_argv ~project_name:"mime" (fun _env ->
          [ Testo.create "File_kind: the repository's samples" (from_samples (caps :> < Cap.open_in >));
            Testo.create "File_kind: the magic numbers" magics;
            Testo.create "File_kind: the name, when the bytes say nothing" names;
            Testo.create "Helpers: the rules, a mailcap's then the built-in" rules ]))
