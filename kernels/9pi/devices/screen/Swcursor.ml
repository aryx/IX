(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Swcursor.mli *)

let enabled = ref false
let visible = ref false
(* swpt, where it should be; swvispt, where it is *)
let pt = ref (0, 0)
let vispt = ref (0, 0)
(* swvers, incremented by each load; swvisvers, the one on the screen *)
let vers = ref 0
let visvers = ref 0
let offset = ref (0, 0)
(* swrect: the screen's rectangle it covers *)
let r = ref (0, 0, 0, 0)
let drawlock = ref false

type images = { back : Kdraw.image; img : Kdraw.image; mask : Kdraw.image; img1 : Kdraw.image; mask1 : Kdraw.image }
let images = ref None

let draw () =
  match !images with
  | Some i when not !visible && !enabled ->
      vispt := !pt;
      visvers := !vers;
      let (x, y) = !pt in
      r := (x, y, x + 16, y + 16);
      (* what is under it kept, then it drawn *)
      Kdraw.draw i.back (0, 0, 32, 32) (Kdraw.screen ()) (x, y, 0, 0) (Kdraw.opaque ());
      Kdraw.draw (Kdraw.screen ()) !r i.img1 (0, 0, 0, 0) i.mask1;
      visible := true
  | _ -> ()

let hide () =
  match !images with
  | Some i when !visible ->
      visible := false;
      Kdraw.draw (Kdraw.screen ()) !r i.back (0, 0, 0, 0) (Kdraw.opaque ())
  | _ -> ()

let avoid (x0, y0, x1, y1) =
  let (a0, b0, a1, b1) = !r in
  if !visible && x0 < a1 && a0 < x1 && y0 < b1 && b0 < y1 then hide ()

let init () =
  enabled := true;
  (* hwdraw's (draw9.c): any drawing on the screen avoids it *)
  Kdraw.on_screen := avoid;
  let i = { back = Kdraw.alloc (0, 0, 32, 32) 0;
            mask = Kdraw.alloc (0, 0, 16, 16) Kdraw.grey8; mask1 = Kdraw.alloc (0, 0, 16, 16) Kdraw.grey1;
            img = Kdraw.alloc (0, 0, 16, 16) Kdraw.grey8; img1 = Kdraw.alloc (0, 0, 16, 16) Kdraw.grey1 } in
  List.iter (fun m -> Kdraw.draw m (0, 0, 16, 16) (Kdraw.opaque ()) (0, 0, 0, 0) (Kdraw.opaque ())) [ i.mask; i.mask1 ];
  List.iter (fun m -> Kdraw.draw m (0, 0, 16, 16) (Kdraw.black ()) (0, 0, 0, 0) (Kdraw.opaque ())) [ i.img; i.img1 ];
  images := Some i

let load off clr set =
  match !images with
  | None -> ()
  | Some i ->
      (* a byte a pixel: the image black where set, the mask opaque
       * where clr or set *)
      let img = Bytes.create 256 and mask = Bytes.create 256 in
      for k = 0 to 31 do
        let s = Char.code set.[k] and c = Char.code clr.[k] in
        for j = 0 to 7 do
          let bit = 0x80 lsr j in
          Bytes.set img (k * 8 + j) (if s land bit <> 0 then '\000' else '\255');
          Bytes.set mask (k * 8 + j) (if (c lor s) land bit <> 0 then '\255' else '\000')
        done
      done;
      ignore (Kdraw.load i.img (Bytes.unsafe_to_string img));
      ignore (Kdraw.load i.mask (Bytes.unsafe_to_string mask));
      offset := off;
      incr vers;
      Kdraw.draw i.img1 (0, 0, 16, 16) i.img (0, 0, 0, 0) (Kdraw.opaque ());
      Kdraw.draw i.mask1 (0, 0, 16, 16) i.mask (0, 0, 0, 0) (Kdraw.opaque ())

let move (x, y) = let (ox, oy) = !offset in pt := (x + ox, y + oy)

let cursoron () =
  if !drawlock then true else begin hide (); draw (); false end

let cursoroff () = hide ()

let ksetcursor off clr set = cursoroff (); load off clr set; ignore (cursoron ())

let clock xy =
  if !enabled then begin
    move xy;
    if not (!visible && !pt = !vispt && !vers = !visvers) && not !drawlock then begin
      hide ();
      draw ()
    end
  end
