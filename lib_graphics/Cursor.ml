(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The mouse's cursor (Plan 9's /dev/cursor; libdraw's Cursor; xix's
 * lib_graphics/input): 16 by 16 pixels, two bits each, as two images
 * of a bit a pixel (32 bytes each, a row two bytes): where [clr] has a
 * bit the pixel is white, where [set] has one it is black ([set]
 * wins); elsewhere the screen shows. [offset] is from the mouse's
 * point to the image's corner. No Cursor.mli: a type and one function.
 *
 *     clr set    the pixel        what is written to /dev/cursor,
 *      0   0     the screen's     72 bytes:
 *      1   0     white              offset.x  offset.y   clr   set
 *      0   1     black                 4         4        32    32
 *      1   1     black              (numbers the low byte first; a
 *                                   row is 2 bytes, the left pixel
 *                                   the first byte's high bit)
 *
 * Two bits and not one, so that an arrow is black with a white edge
 * and is seen on a white page and on a black one. The offset is
 * negative or zero: an arrow's point is at its corner; a cross
 * hair's is its middle, (-7, -7).
 *
 * design:
 * The cursor is not drawn by the program, and not through /dev/draw.
 * It must follow the hand while the program computes, so the kernel
 * moves it, at its clock's tick (mini-9pi's Swcursor: what is under
 * it kept aside and put back, and any drawing on the screen first
 * takes it away); it is not part of any image a program has. A
 * machine whose video hardware can lay a small picture over the
 * screen by itself needs no saving at all: the same file would do.
 * In a window the file is mini-rio's (Virtual_mouse), which keeps a
 * cursor a window.
 *
 * References: mouse(3) of Plan 9's manual (the cursor file);
 * mouse(2), setcursor. *)

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
