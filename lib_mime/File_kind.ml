(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See File_kind.mli *)

(* ix: the author's playground's apps/media/Media.ml, its by_bytes and
 * by_name; content types where it had a variant, and the kinds that are
 * not media *)

let starts (s : string) (at : int) (magic : string) : bool =
  String.length s >= at + String.length magic && String.sub s at (String.length magic) = magic

(* Mod.channels_of_tag's, without the library of sound: "M.K.", "6CHN", "12CH"... *)
let mod_tag (s : string) : bool =
  String.length s >= 1084
  &&
  let tag = String.sub s 1080 4 in
  let digit (i : int) = tag.[i] >= '0' && tag.[i] <= '9' in
  List.mem tag [ "M.K."; "M!K!"; "FLT4"; "FLT8"; "OCTA" ]
  || (digit 0 && String.sub tag 1 3 = "CHN")
  || (digit 0 && digit 1 && String.sub tag 2 2 = "CH")

(* the first frame's header alone (the next frame's place is
 * Mpeg_audio_header's, which needs the file): the sync, a layer, a
 * bitrate and a rate that are not the forbidden ones *)
let mpeg_audio (s : string) : bool =
  starts s 0 "ID3"
  || String.length s >= 4
     && s.[0] = '\255'
     && Char.code s.[1] land 0xE0 = 0xE0
     && Char.code s.[1] land 0x06 <> 0
     && Char.code s.[2] lsr 4 <> 15
     && (Char.code s.[2] lsr 2) land 3 <> 3

let plan9_exe (s : string) : bool = starts s 0 "\000\000\006\071" || starts s 0 "\000\000\140\071"

(* after blanks, what an HTML file begins with, in either case *)
let html (s : string) : bool =
  let n = String.length s in
  let rec first i = if i < n && List.mem s.[i] [ ' '; '\t'; '\r'; '\n' ] then first (i + 1) else i in
  let i = first 0 in
  let lower = String.lowercase_ascii (String.sub s i (min 15 (n - i))) in
  String.starts_with ~prefix:"<!doctype html" lower || String.starts_with ~prefix:"<html" lower

let of_bytes (s : string) : string option =
  let is magic = starts s 0 magic in
  if is "RIFF" && starts s 8 "WAVE" then Some "audio/wav"
  else if is "RIFF" && starts s 8 "AVI " then Some "video/x-msvideo"
  else if is "MThd" then Some "audio/midi"
  else if is "OggS" then Some "audio/ogg"
  else if mod_tag s then Some "audio/x-mod"
  else if is "\137PNG\r\n\026\n" then Some "image/png"
  else if is "GIF87a" || is "GIF89a" then Some "image/gif"
  else if is "\255\216\255" then Some "image/jpeg"
  else if is "/* XPM */" then Some "image/x-xpixmap"
  else if is "YUV4MPEG2 " then Some "video/x-y4m"
  else if is "\000\000\001\xB3" || is "\000\000\001\xBA" then Some "video/mpeg"
  else if String.length s >= 128 && (starts s 4 "\x11\xAF" || starts s 4 "\x12\xAF") then Some "video/x-flic"
  else if is "%PDF-" then Some "application/pdf"
  else if is "TinyOffice 1\n" then Some "application/x-office"
  else if is "\031\139" then Some "application/gzip"
  else if starts s 257 "ustar" then Some "application/x-tar"
  else if is "\127ELF" || plan9_exe s then Some "application/x-executable"
  else if is "#!" then Some "text/x-script"
  else if html s then Some "text/html"
  else if is "BEGIN:VCALENDAR" then Some "text/calendar"
  else if is "BEGIN:VCARD" then Some "text/vcard"
  else if is "X:" then Some "text/x-abc"
  else if mpeg_audio s then Some "audio/mpeg"
  else None

let of_name (name : string) : string option =
  let ends = Filename.check_suffix (String.lowercase_ascii name) in
  if ends ".mod" then Some "audio/x-mod"
  else if ends ".abc" then Some "text/x-abc"
  else if ends ".html" || ends ".htm" then Some "text/html"
  else if ends ".office" then Some "application/x-office"
  else None

(* text has no magic: no NUL, and no byte under a space but the blanks *)
let is_text (s : string) : bool =
  let ok = ref true in
  String.iter (fun c -> if Char.code c < 32 && not (List.mem c [ '\t'; '\n'; '\r'; '\012'; '\027' ]) then ok := false) s;
  !ok

let of_file ~(name : string) (bytes : string) : string =
  match of_bytes bytes with
  | Some kind -> kind
  | None -> (
      match of_name name with
      | Some kind -> kind
      | None -> if is_text bytes then "text/plain" else "application/octet-stream")

(* (the first bytes are enough: a MOD's tag, at 1,080, the furthest) *)
let first_bytes = 4096

let of_path (caps : < Cap.open_in ; .. >) (path : Fpath.t) : string =
  let bytes =
    FS.with_open_in caps
      (fun (chan : Chan.i) ->
        let buf = Bytes.create first_bytes in
        let rec fill (at : int) : int =
          let n = input chan.ic buf at (first_bytes - at) in
          if n = 0 then at else fill (at + n)
        in
        Bytes.sub_string buf 0 (fill 0))
      path
  in
  of_file ~name:(Filename.basename (Fpath.to_string path)) bytes
