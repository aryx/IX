(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What a page read keeps (Browser_page.read): each part of it in
 * megabytes (Obj.reachable_words: a part shared with another counted
 * in both), and the whole, after its time; then its scripts' engine
 * made (Browser_script.create_with, as Tab.load does: none run), and
 * what it holds that the page does not. A page of Hacker News's
 * comments, 1.3 MB of HTML, is 150 MB alive in mini-netscape (OCaml's,
 * 64 bits): more than mini-ml's heap on mini-9pi holds (64 MB a half).
 * "without": the page less the three stages nothing reads (its
 * source's lines, its tokens, its Line_mode). Sheets given are the
 * page's <link>s, in order; none: unstyled.
 *
 * usage: memory [-w width] page.html [sheet.css...] *)

let read (file : string) : string = let ic = open_in_bin file in let s = really_input_string ic (in_channel_length ic) in close_in ic; s

let mb (words : int) : float = float_of_int (words * (Sys.word_size / 8)) /. 1048576.

let () =
  let width, files =
    match List.tl (Array.to_list Sys.argv) with
    | "-w" :: w :: files -> (float_of_string w, files)
    | files -> (1000., files)
  in
  match files with
  | [] -> prerr_endline "usage: memory [-w width] page.html [sheet.css...]"; exit 2
  | page :: sheets ->
      let bytes = read page in
      let texts = List.map read sheets in
      let wanted = ref [] in
      (* (the page's sheets, by the order it asks for them: the files given) *)
      let sheet (u : string) : string option =
        if not (List.mem u !wanted) then wanted := !wanted @ [ u ];
        let rec nth l i = match l with [] -> None | x :: r -> if i = 0 then Some x else nth r (i - 1) in
        let rec index l i = match l with [] -> None | x :: r -> if x = u then Some i else index r (i + 1) in
        Option.bind (index !wanted 0) (nth texts)
      in
      let s : Browser_page.settings = { css = true; width; visited = (fun _ -> false); picture = (fun _ -> None); sheet } in
      let t0 = Sys.time () in
      let p = Browser_page.read s ("file://" ^ page) 200 (Some "text/html") bytes in
      let p = if sheets = [] then p else Browser_page.laid_out s p in
      let t1 = Sys.time () in
      let part (name : string) (o : Obj.t) = Printf.printf "%-10s %7.1f MB\n" name (mb (Obj.reachable_words o)) in
      Printf.printf "%s: %d bytes, read and laid out in %.1f s\n" page (String.length bytes) (t1 -. t0);
      part "lines" (Obj.repr p.lines);
      part "tokens" (Obj.repr p.tokens);
      part "tree" (Obj.repr p.tree);
      part "line_mode" (Obj.repr p.line_mode);
      part "layout" (Obj.repr p.layout);
      part "drawn" (Obj.repr p.drawn);
      part "forms" (Obj.repr p.forms);
      part "the page" (Obj.repr p);
      part "without" (Obj.repr { p with tokens = []; lines = []; line_mode = Line_mode.render 80 (Html_tree.of_string "") });
      let t2 = Sys.time () in
      let e = Browser_script.create_with Browser_script.defaults p.tree in
      Printf.printf "the engine made in %.1f s\n" (Sys.time () -. t2);
      part "the engine" (Obj.repr e);
      part "both" (Obj.repr (p, e));
      Gc.full_major ();
      let g = Gc.stat () in
      Printf.printf "alive in all %.1f MB, the heap at most %.1f MB\n" (mb g.live_words) (mb g.top_heap_words)
