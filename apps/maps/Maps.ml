(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-maps: a map moved and zoomed, fetched from the internet
 * (docs/plans/plan_maps.md): the program, the window being Map_window.
 *
 *   mini-maps                       the world
 *   mini-maps lat=47.39 lon=0.69    a place
 *
 * Dragging moves the map, as do the arrows; the wheel, a double click,
 * + and - zoom it. *)

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch @@ fun () ->
      Logging.setup caps ~name:"mini-maps";
      let flags = Playground_platform.flags caps in
      (* heap=modest: tiles are kept, tens of megabytes (mini-netscape's);
       * the screen as large as the window *)
      let flags = ("heap", "modest") :: (if List.mem_assoc "window" flags then flags else ("window", "") :: flags) in
      let wcaps = (caps :> Map_window.caps) in
      Playground_platform.run_app caps flags
        (Playground.game Map_window.view Map_window.update (Map_window.initial wcaps flags));
      Exit.OK)
