(* tiny-machine-fetch fetches a web page for tiny-kernel's browser. It
 * runs on the host, at the other end of tiny-machine's wire, when the
 * browser sends its request "GET address HTTP/1.0"
 * (TinyMachinePeer.www_request). Like tiny-machine-socket, it is a
 * separate program, so that tiny-machine itself links no network
 * library. This one links ix's own, lib_networking, which does DNS,
 * TCP, TLS 1.3, and HTTP/1.1 with its redirections, chunks and gzip.
 * tiny-machine runs it when it has -net-out, and waits for it.
 *
 *     tiny-machine-fetch https://en.wikipedia.org/api/rest_v1/page/html/OCaml
 *
 * prints the answer on standard output and exits 0, whatever the
 * status (a 404 page is still a page). The answer is written by ix's
 * Http.response_to_string:
 * - an HTTP/1.0 status line;
 * - the site's headers, except those about the body's framing (the
 *   length, gzip, chunks), since that framing is undone here;
 * - then the body.
 * When there is no answer at all, it prints the reason on standard
 * output, as one line starting with "www: ", and exits 1.
 *
 *     tiny-machine-fetch -picture 250 188 https://.../250px-Award.jpg
 *
 * fetches a picture (or reads it, when the source is a file holding a
 * kept copy), decodes it (PNG, JPEG or GIF, with lib_graphics), and
 * prints it
 * as 250 times 188 bytes, one byte per pixel in the machine's 256
 * colours. Each pixel is the average of the source pixels that fall in
 * it, put on white where they are transparent, then mapped to the
 * nearest colour of the palette. This answers the line
 * "img w h address" of tiny-kernel's browser.
 *
 * This is the part of the web that the tiny machine does not do
 * itself: the encrypted half (plan_tiny_browser.md, section 3).
 * Everything from the first < of the page on is done by the machine.
 *
 * In m-ix the same work is done by mini-curl (Curl in networking/, built
 * on the same lib_networking), which runs on mini-9pi itself, and the
 * browser there decodes the pictures. Here the host does both, so
 * tiny-kernel needs no TLS and no PNG or JPEG decoder. *)

val main :
  < Cap.network; Cap.open_in; Cap.readdir; Cap.stdout; Cap.clock; .. > ->
  string array -> Exit.t
