(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ogg.mli *)

(* ix: the author's playground's libs/audio/formats/vorbis/Ogg.ml (docs/plans/plan_quake.md) *)

let packets (s : string) : string list =
  let n = String.length s in
  let out = ref [] and partial = Buffer.create 4096 in
  let rec page (at : int) : unit =
    if at + 27 <= n && String.sub s at 4 = "OggS" then (
      let segments = Char.code s.[at + 26] in
      if at + 27 + segments <= n then (
        let data = ref (at + 27 + segments) in
        for i = 0 to segments - 1 do
          let size = Char.code s.[at + 27 + i] in
          if !data + size <= n then Buffer.add_substring partial s !data size;
          data := !data + size;
          (* a segment shorter than 255 ends its packet *)
          if size < 255 then (
            out := Buffer.contents partial :: !out;
            Buffer.clear partial)
        done;
        page !data))
  in
  page 0;
  List.rev !out

(* the last page's granule position: for sound, how many samples the
 * stream has, each channel *)
let length (s : string) : int option =
  let n = String.length s in
  let rec page (at : int) (last : int option) : int option =
    if at + 27 <= n && String.sub s at 4 = "OggS" then (
      let segments = Char.code s.[at + 26] in
      let size = ref 0 in
      for i = 0 to min segments (n - at - 27) - 1 do size := !size + Char.code s.[at + 27 + i] done;
      let granule = ref 0 in
      for i = 7 downto 0 do granule := (!granule lsl 8) lor Char.code s.[at + 6 + i] done;
      (* -1 (all the bits): no packet ends on this page *)
      page (at + 27 + segments + !size) (if !granule < 0 || Char.code s.[at + 13] = 0xff then last else Some !granule))
    else last
  in
  page 0 None
