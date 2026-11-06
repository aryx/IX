(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineFetch.mli *)

(* A picture as w by h bytes of the machine's colours: each pixel the
 * average of the source's pixels that fall in it, on white where they
 * are transparent. *)
let reduce (img : Rgba_image.t) w h =
  let out = Bytes.create (w * h) in
  for y = 0 to h - 1 do
    let y0 = y * img.height / h
    and y1 = max ((y + 1) * img.height / h) ((y * img.height / h) + 1) in
    for x = 0 to w - 1 do
      let x0 = x * img.width / w
      and x1 = max ((x + 1) * img.width / w) ((x * img.width / w) + 1) in
      let r = ref 0 and g = ref 0 and b = ref 0 and n = ref 0 in
      for sy = y0 to min y1 img.height - 1 do
        for sx = x0 to min x1 img.width - 1 do
          let o = 4 * ((sy * img.width) + sx) in
          let a = Char.code (Bytes.get img.rgba (o + 3)) in
          let over c =
            ((Char.code (Bytes.get img.rgba (o + c)) * a) + (255 * (255 - a)))
            / 255 in
          r := !r + over 0; g := !g + over 1; b := !b + over 2; incr n
        done
      done;
      let n = max !n 1 in
      Bytes.set out ((y * w) + x)
        (Char.chr (TinyMachineDevices.nearest (!r / n) (!g / n) (!b / n)))
    done
  done;
  Bytes.to_string out

let main (caps : < Cap.network; Cap.open_in; Cap.readdir; Cap.stdout; .. >)
    (argv : string array) : Exit.t =
  let get url =
    match Http_client.get caps url with
    | Ok (r : Http.response) -> Ok r.body
    | Error why -> Error why in
  (* (the failures said on the standard output, the answer the kernel
   * reads, not after the program's name: Code 1, not Err) *)
  match Array.to_list argv with
  | [ _; "-picture"; w; h; source ] -> (
      let w = int_of_string w and h = int_of_string h in
      let bytes =
        if CapSys.file_exists caps source then Ok (FS.read caps (Fpath.v source))
        else get source in
      match bytes with
      | Ok bytes -> (
          match Image_file.decode bytes with
          | img -> Console.print caps (reduce img w h); Exit.OK
          | exception Failure why ->
              Console.print caps ("www: " ^ source ^ ": " ^ why ^ "\n");
              Exit.Code 1)
      | Error why ->
          Console.print caps ("www: " ^ source ^ ": " ^ why ^ "\n");
          Exit.Code 1)
  | [ _; url ] -> (
      match Http_client.get caps url with
      | Ok (r : Http.response) ->
          (* the body's own framing undone, so not said *)
          let framing = [ "content-length"; "content-encoding";
                          "transfer-encoding"; "connection" ] in
          let headers =
            List.filter
              (fun (n, _) -> not (List.mem (String.lowercase_ascii n) framing))
              r.headers in
          Console.print caps (TinyBrowserHttp.response r.status headers r.body);
          Exit.OK
      | Error why ->
          Console.print caps ("www: " ^ url ^ ": " ^ why ^ "\n"); Exit.Code 1)
  | _ ->
      Console.print caps
        "www: usage: tiny-machine-fetch url | -picture w h url-or-file\n";
      Exit.Code 2

let () = TinyLibSystem.main "tiny-machine-fetch" main
