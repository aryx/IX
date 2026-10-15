(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineFetch.mli *)

(* The nearest of the machine's 256 colours, for each colour with 5 bits
 * of red, green and blue: a table made once, then a lookup per pixel. *)
let nearest =
  let pal = TinyMachineDevices.colours in
  let best r g b =
    let d k = let dr = r - Char.code pal.[3 * k] and dg = g - Char.code pal.[(3 * k) + 1] and db = b - Char.code pal.[(3 * k) + 2] in (dr * dr) + (dg * dg) + (db * db) in
    let rec go k bk bd = if k = 256 then bk else let dk = d k in if dk < bd then go (k + 1) k dk else go (k + 1) bk bd in
    go 1 0 (d 0) in
  lazy (Array.init 32768 (fun i -> best (((i lsr 10) land 31) * 255 / 31) (((i lsr 5) land 31) * 255 / 31) ((i land 31) * 255 / 31)))

(* A picture as w by h bytes of the machine's colours: each pixel the
 * average of the source's pixels that fall in it, on white where they
 * are transparent. *)
let reduce (img : Rgba_image.t) w h =
  let table = Lazy.force nearest in
  let out = Bytes.create (w * h) in
  for y = 0 to h - 1 do
    let y0 = y * img.height / h and y1 = max ((y + 1) * img.height / h) ((y * img.height / h) + 1) in
    for x = 0 to w - 1 do
      let x0 = x * img.width / w and x1 = max ((x + 1) * img.width / w) ((x * img.width / w) + 1) in
      let r = ref 0 and g = ref 0 and b = ref 0 and n = ref 0 in
      for sy = y0 to min y1 img.height - 1 do
        for sx = x0 to min x1 img.width - 1 do
          let o = 4 * ((sy * img.width) + sx) in
          let a = Char.code (Bytes.get img.rgba (o + 3)) in
          let over c = ((Char.code (Bytes.get img.rgba (o + c)) * a) + (255 * (255 - a))) / 255 in
          r := !r + over 0; g := !g + over 1; b := !b + over 2; incr n
        done
      done;
      let n = max !n 1 in
      let i = (((!r / n) lsr 3) lsl 10) lor (((!g / n) lsr 3) lsl 5) lor ((!b / n) lsr 3) in
      Bytes.set out ((y * w) + x) (Char.chr table.(i))
    done
  done;
  Bytes.to_string out

let main (caps : < Cap.network; Cap.open_in; Cap.stdout; Cap.argv; .. >) =
  let get url = match Http_client.get caps url with Ok (r : Http.response) -> Ok r.body | Error why -> Error why in
  match Array.to_list (CapSys.argv caps) with
  | [ _; "-picture"; w; h; source ] -> (
      let w = int_of_string w and h = int_of_string h in
      let bytes = if Sys.file_exists source then Ok (FS.read caps (Fpath.v source)) else get source in
      match bytes with
      | Ok bytes -> (
          match Image_file.decode bytes with
          | img -> Console.print caps (reduce img w h); 0
          | exception Failure why -> Console.print caps ("www: " ^ source ^ ": " ^ why ^ "\n"); 1)
      | Error why -> Console.print caps ("www: " ^ source ^ ": " ^ why ^ "\n"); 1)
  | [ _; url ] -> (
      match get url with
      | Ok body -> Console.print caps body; 0
      | Error why -> Console.print caps ("www: " ^ url ^ ": " ^ why ^ "\n"); 1)
  | _ -> Console.print caps "www: usage: tiny-machine-fetch url | -picture w h url-or-file\n"; 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
