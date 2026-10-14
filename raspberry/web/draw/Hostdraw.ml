(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Hostdraw.mli *)

let drawn = ref 0
let declined = ref 0

(* the chans seen, made once *)
let chans : (int * int, Memchan.t option) Hashtbl.t = Hashtbl.create 16
let chan hi lo =
  match Hashtbl.find_opt chans (hi, lo) with
  | Some c -> c
  | None -> let c = Memchan.make hi lo in Hashtbl.add chans (hi, lo) c; c

exception Decline

(* The request (Memdraw.hosted): three images of 12 words (where its
 * bytes are, how many, its chan's hi and lo, r, org, the bytes a row,
 * xbase), then r, sr, mr and the op *)
let draw mem (piece : int -> int -> bool -> int) desc =
  let words = 49 in
  let pa = piece desc (4 * words) false in
  if pa < 0 then 0
  else begin
    let w = Array.init words (fun i -> Bits.signed32 (Memory.load32 mem (pa + (4 * i)))) in
    let rect at = (w.(at), w.(at + 1), w.(at + 2), w.(at + 3)) in
    (* an image on the RAM's bytes; the same bytes, the same data (the
     * loop goes bottom up when the source is the destination) *)
    let datas = ref [] in
    let image at ~write =
      let va = Memory.load32 mem (pa + (4 * at)) and len = w.(at + 1) in
      let c = match chan w.(at + 2) w.(at + 3) with Some c when not c.Memchan.cmap -> c | _ -> raise Decline in
      let where = piece va len write in
      if where < 0 || len <= 0 then raise Decline;
      let bytes, off = Memory.direct mem where len in
      let data =
        match List.assoc_opt off !datas with
        | Some d -> d
        | None -> let d = { Memimage.bytes; onscreen = false; keep = true } in datas := (off, d) :: !datas; d in
      let r = rect (at + 4) in
      ({ Memimage.data; r; clipr = r; repl = false; chan = c; bwidth = w.(at + 10); org = (w.(at + 8), w.(at + 9));
         xbase = w.(at + 11) - off; layer = None }, off, len) in
    match
      let dst, off, len = image 0 ~write:true in
      let src, _, _ = image 12 ~write:false in
      let mask, _, _ = image 24 ~write:false in
      let ((x0, y0, x1, y1) as r) = rect 36 in
      (* what is written is the destination's *)
      if x1 <= x0 || y1 <= y0 then raise Decline;
      let first = Memimage.byteaddr dst x0 y0 and last = Memimage.byteaddr dst (x1 - 1) (y1 - 1) + ((dst.chan.Memchan.depth + 7) / 8) in
      if first < off || last > off + len then raise Decline;
      Memgeneral.general dst r src (rect 40) mask (rect 44) w.(48)
    with
    | () -> incr drawn; 1
    | exception (Decline | Invalid_argument _ | Memory.Fault _ | Division_by_zero) -> incr declined; 0
  end

let install () = Board.host_draw := draw
