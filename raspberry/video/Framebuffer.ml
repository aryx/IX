(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Framebuffer.mli *)

type geometry = { width : int; height : int; depth : int; pitch : int; base : int }

type t = { mem : Memory.t; mutable geometry : geometry option }

let create mem = { mem; geometry = None }

let configure t g = t.geometry <- Some g

(* the screen as RGB bytes, 3 a pixel, row after row *)
let rgb t =
  match t.geometry with
  | None -> None
  | Some g ->
      let out = Bytes.create (g.width * g.height * 3) in
      let row = Bytes.create g.pitch in
      for y = 0 to g.height - 1 do
        Bytes.blit_string (Memory.read_string t.mem (g.base + (y * g.pitch)) g.pitch) 0 row 0 g.pitch;
        for x = 0 to g.width - 1 do
          let r, gr, b =
            match g.depth with
            | 16 ->
                let v = Bytes.get_uint16_le row (2 * x) in
                let r5 = (v lsr 11) land 31 and g6 = (v lsr 5) land 63 and b5 = v land 31 in
                (* shifted up, as QEMU's display: white is f8 fc f8 *)
                r5 lsl 3, g6 lsl 2, b5 lsl 3
            | 24 -> Char.code (Bytes.get row (3 * x)), Char.code (Bytes.get row ((3 * x) + 1)), Char.code (Bytes.get row ((3 * x) + 2))
            | _ ->
                (* 32 bits: red first, as 24's and as QEMU's board shows them
                 * (old: red in the word's bits 16 to 23, blue first: no kernel
                 * had asked 32 bits before mini-squeak, whose colours QEMU
                 * and this then showed differently) *)
                Char.code (Bytes.get row (4 * x)), Char.code (Bytes.get row ((4 * x) + 1)), Char.code (Bytes.get row ((4 * x) + 2)) in
          let o = 3 * ((y * g.width) + x) in
          Bytes.set out o (Char.chr r); Bytes.set out (o + 1) (Char.chr gr); Bytes.set out (o + 2) (Char.chr b)
        done
      done;
      Some (g.width, g.height, Bytes.to_string out)

(* the pixels as the kernel wrote them, pitch after pitch *)
let raw t = Option.map (fun g -> g, Memory.read_string t.mem g.base (g.pitch * g.height)) t.geometry

(* the same without a copy: the RAM's bytes, and where the pixels start *)
let direct t = Option.map (fun g -> let bytes, at = Memory.direct t.mem g.base (g.pitch * g.height) in g, bytes, at) t.geometry

let ppm (w, h, rgb) = Printf.sprintf "P6\n%d %d\n255\n" w h ^ rgb
