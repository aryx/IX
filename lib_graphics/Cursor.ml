(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The mouse's cursor (Plan 9's /dev/cursor; libdraw's Cursor; xix's
 * lib_graphics/input): 16 by 16 pixels, two bits each, as two images
 * of a bit a pixel (32 bytes each, a row two bytes): where [clr] has a
 * bit the pixel is white, where [set] has one it is black ([set]
 * wins); elsewhere the screen shows. [offset] is from the mouse's
 * point to the image's corner. No Cursor.mli: a type and one function. *)

type t = { offset : Point.t; clr : string; set : string }

(* the cursor shown from now on; None: the kernel's arrow again *)
let set (_ : < Cap.mouse; .. >) (c : t option) =
  let fd = Unix.openfile "/dev/cursor" [ Unix.O_WRONLY ] 0 in
  let bytes = match c with
    | None -> "\000"            (* (less than a cursor: the arrow) *)
    | Some c ->
        let b = Bytes.create 8 in
        Bytes.set_int32_le b 0 (Int32.of_int c.offset.x);
        Bytes.set_int32_le b 4 (Int32.of_int c.offset.y);
        Bytes.to_string b ^ c.clr ^ c.set in
  ignore (Unix.write_substring fd bytes 0 (String.length bytes));
  Unix.close fd
