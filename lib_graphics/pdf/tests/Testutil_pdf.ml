(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Testutil_pdf.mli *)

let reader : (string -> string) ref = ref (fun (_ : string) -> failwith "Testutil_pdf.reader is not set")
let read (name : string) : string = !reader name

let away (fb : Framebuffer.t) (img : Rgba_image.t) : float =
  if abs (fb.width - img.width) > 1 || abs (fb.height - img.height) > 1 then 1000.
  else begin
    let w = min fb.width img.width / 4 and h = min fb.height img.height / 4 in
    let grey (r : int) (g : int) (b : int) : int = (299 * r) + (587 * g) + (114 * b) in
    let total = ref 0. in
    for by = 0 to h - 1 do
      for bx = 0 to w - 1 do
        let ours = ref 0 and theirs = ref 0 in
        for y = 4 * by to (4 * by) + 3 do
          for x = 4 * bx to (4 * bx) + 3 do
            let rgb = Framebuffer.get_rgb fb ~x ~y and i = 4 * ((y * img.width) + x) in
            let part (k : int) = Char.code (Bytes.get img.rgba (i + k)) in
            ours := !ours + grey (rgb lsr 16) ((rgb lsr 8) land 255) (rgb land 255);
            theirs := !theirs + grey (part 0) (part 1) (part 2)
          done
        done;
        total := !total +. (Float.abs (float (!ours - !theirs)) /. 16000.)
      done
    done;
    !total /. float (max 1 (w * h))
  end
