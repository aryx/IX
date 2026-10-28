(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Runs TinyBrowser's reading (TinyBrowserHtml) on the host, built by
 * OCaml. It reads a page from a file, gives it to the reading in
 * messages of [size] bytes (the whole page at once if no size is
 * given), and prints the lines as text. With -address, it prints
 * what was typed as a full address instead (TinyBrowserAddress); with
 * -request, the address www's request for it asks; with -http, an
 * answer read on standard input as www reads it (TinyBrowserHttp): its
 * status, its type and its body, or - when its head has not ended.
 * usage: Host.exe width page.html [size] | -address typed
 *        | -request typed | -http *)

let () =
  match Array.to_list Sys.argv with
  | [ _; "-address"; typed ] ->
      print_endline (TinyBrowserAddress.absolute typed)
  | [ _; "-request"; typed ] ->
      let url = TinyBrowserAddress.absolute typed in
      print_endline
        (Option.value (TinyBrowserHttp.asked (TinyBrowserHttp.request url))
           ~default:"none")
  | [ _; "-http" ] ->
      let s = In_channel.input_all stdin in
      let e = TinyBrowserHttp.head_end s in
      let head = if e < 0 then s else String.sub s 0 e in
      Printf.printf "%d|%s|%s\n" (TinyBrowserHttp.status head)
        (TinyBrowserHttp.media_type head)
        (if e < 0 then "-" else String.sub s e (String.length s - e))
  | [ _; width; file ] | [ _; width; file; _ ] ->
      let ic = open_in_bin file in
      let s = really_input_string ic (in_channel_length ic) in
      close_in ic;
      let n = String.length s in
      let size =
        if Array.length Sys.argv > 3 then int_of_string Sys.argv.(3)
        else max 1 n in
      let p = TinyBrowserHtml.create (int_of_string width) in
      let rec go i =
        if i < n then begin
          TinyBrowserHtml.feed p (String.sub s i (min size (n - i)));
          go (i + size)
        end in
      go 0;
      TinyBrowserHtml.finish p;
      print_string (Testutil_browser.dump p (int_of_string width))
  | _ ->
      prerr_endline
        "usage: Host.exe width page.html [size] | -address typed \
         | -request typed | -http";
      exit 2
