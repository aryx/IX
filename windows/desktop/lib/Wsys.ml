(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wsys.mli *)

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

let file caps id name = read_file caps (Printf.sprintf "/dev/wsys/%d/%s" id name)

let windows (caps : < Cap.readdir; Cap.open_in; .. >) : Taskbar.window list =
  let names = try Sys_plan9.dirread caps "/dev/wsys" with Sys_error _ | Unix.Unix_error _ -> [] in
  let ids = List.filter_map (fun (d : Sys_plan9.dir) -> int_of_string_opt d.name) names in
  List.filter_map (fun id ->
      match file caps id "wctl", file caps id "label" with
      | Some wctl, Some label -> Taskbar.window_of id label wctl
      | _ -> None)
    (List.sort compare ids)

let winname caps id = file caps id "winname"

let ask (caps : < Cap.open_out; .. >) line =
  try
    let fd = FS.open_device_fd caps "/dev/wctl" in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()
