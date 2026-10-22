(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Hid's mice on the host, for hid.sh: two report descriptors read, and
 * a report of each read by its layout. A line each, ok or FAIL. *)

let bytes (l : int list) : string =
  String.concat "" (List.map (fun b -> String.make 1 (Char.chr b)) l)

let check (name : string) (desc : int list) (report : int list)
    (want : int * int * int) : bool =
  match Hid.layout (bytes desc) with
  | None ->
      Printf.printf "FAIL %s: no layout\n" name;
      false
  | Some l -> (
      match Hid.moved (Hid.Report l) (bytes report) with
      | Some got when got = want ->
          Printf.printf "ok %s\n" name;
          true
      | Some (x, y, b) ->
          Printf.printf "FAIL %s: %d %d %d\n" name x y b;
          false
      | None ->
          Printf.printf "FAIL %s: not read\n" name;
          false)

let () =
  (* QEMU's usb-mouse (hw/usb/dev-hid.c): 3 buttons and 5 bits of
   * padding, then X, Y and the wheel, a signed byte each *)
  let qemu =
    [
      0x05;
      0x01;
      0x09;
      0x02;
      0xa1;
      0x01;
      0x09;
      0x01;
      0xa1;
      0x00;
      0x05;
      0x09;
      0x19;
      0x01;
      0x29;
      0x03;
      0x15;
      0x00;
      0x25;
      0x01;
      0x95;
      0x03;
      0x75;
      0x01;
      0x81;
      0x02;
      0x95;
      0x01;
      0x75;
      0x05;
      0x81;
      0x01;
      0x05;
      0x01;
      0x09;
      0x30;
      0x09;
      0x31;
      0x09;
      0x38;
      0x15;
      0x81;
      0x25;
      0x7f;
      0x75;
      0x08;
      0x95;
      0x03;
      0x81;
      0x06;
      0xc0;
      0xc0;
    ]
  in
  (* a mouse of Logitech's kind: report 2, 16 buttons, X and Y in 12
   * bits each (from -2047), the wheel, a horizontal pan (page 0x0c) *)
  let logitech =
    [
      0x05;
      0x01;
      0x09;
      0x02;
      0xa1;
      0x01;
      0x85;
      0x02;
      0x09;
      0x01;
      0xa1;
      0x00;
      0x05;
      0x09;
      0x19;
      0x01;
      0x29;
      0x10;
      0x15;
      0x00;
      0x25;
      0x01;
      0x95;
      0x10;
      0x75;
      0x01;
      0x81;
      0x02;
      0x05;
      0x01;
      0x16;
      0x01;
      0xf8;
      0x26;
      0xff;
      0x07;
      0x75;
      0x0c;
      0x95;
      0x02;
      0x09;
      0x30;
      0x09;
      0x31;
      0x81;
      0x06;
      0x15;
      0x81;
      0x25;
      0x7f;
      0x75;
      0x08;
      0x95;
      0x01;
      0x09;
      0x38;
      0x81;
      0x06;
      0x05;
      0x0c;
      0x0a;
      0x38;
      0x02;
      0x95;
      0x01;
      0x81;
      0x06;
      0xc0;
      0xc0;
    ]
  in
  let all =
    [
      (* the right button, 3 right, 2 up, the wheel a notch away *)
      check "qemu: right button, moved, wheel away" qemu
        [ 0x02; 0x03; 0xfe; 0x01 ]
        (3, -2, 4 lor 8);
      check "qemu: wheel towards you" qemu [ 0x00; 0x00; 0x00; 0xff ] (0, 0, 16);
      (* the left button, X -3 (0xffd), Y 5: fd, 5f, 00; the wheel -1 *)
      check "logitech: left button, 12-bit moves, wheel towards you" logitech
        [ 0x02; 0x01; 0x00; 0xfd; 0x5f; 0x00; 0xff; 0x00 ]
        (-3, 5, 1 lor 16);
      check "logitech: middle button" logitech
        [ 0x02; 0x04; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00 ]
        (0, 0, 2);
      (* another report's number: not the mouse's *)
      (match Hid.layout (bytes logitech) with
      | Some l when Hid.moved (Hid.Report l) (bytes [ 0x03; 0x01 ]) = None ->
          print_endline "ok logitech: another report's number";
          true
      | _ ->
          print_endline "FAIL logitech: another report's number read";
          false);
      (* the boot protocol: a 4th byte's wheel by its sign *)
      (if
         Hid.moved Hid.Boot (bytes [ 0x01; 0x00; 0x00; 0x02 ])
         = Some (0, 0, 1 lor 8)
       then (
         print_endline "ok boot: a wheel of 2 notches";
         true)
       else (
         print_endline "FAIL boot: a wheel of 2 notches";
         false));
    ]
  in
  exit (if List.for_all (fun b -> b) all then 0 else 1)
