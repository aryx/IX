(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Runs TinyBrowser's reading (TinyBrowserPage) on the host, built by
 * OCaml. It reads a page from a file, gives it to the reading in
 * messages of [size] bytes (the whole page at once if no size is
 * given), and prints the lines as text.
 * usage: Host.exe width page.html [size] *)

let () =
  match Array.to_list Sys.argv with
  | [ _; width; file ] | [ _; width; file; _ ] ->
      let ic = open_in_bin file in
      let s = really_input_string ic (in_channel_length ic) in
      close_in ic;
      let n = String.length s in
      let size =
        if Array.length Sys.argv > 3 then int_of_string Sys.argv.(3)
        else max 1 n in
      let p = TinyBrowserPage.create (int_of_string width) in
      let rec go i =
        if i < n then begin
          TinyBrowserPage.feed p (String.sub s i (min size (n - i)));
          go (i + size)
        end in
      go 0;
      TinyBrowserPage.finish p;
      print_string (Testutil_browser.dump p (int_of_string width))
  | _ -> prerr_endline "usage: Host.exe width page.html [size]"; exit 2
