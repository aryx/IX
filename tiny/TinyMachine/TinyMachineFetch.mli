(* tiny-machine-fetch: a web page's bytes, for the other end of
 * tiny-machine's wire when tiny-kernel's browser asks for one (the line
 * "www address", TinyMachinePeer.www_address). It is a program apart, as
 * tiny-machine-socket is, so that tiny-machine itself links no network
 * library: this one links ix's own (lib_networking: DNS, TCP, TLS 1.3,
 * HTTP/1.1 with its redirections, chunks and gzip). tiny-machine runs it
 * when it has -net-out, and waits for it.
 *
 *     tiny-machine-fetch https://en.wikipedia.org/api/rest_v1/page/html/OCaml
 *
 * prints the body on standard output, whatever the status (a 404's page
 * is a page), and exits 0; if there is no answer at all, it prints why
 * on standard output, as one line starting with "www: ", and exits 1.
 *
 *     tiny-machine-fetch -picture 250 188 https://.../250px-Award.jpg
 *
 * fetches a picture (or reads it, when the source is a file: a kept
 * copy), decodes it (PNG, JPEG, GIF: lib_graphics), and prints it as 250
 * times 188 bytes, a byte a pixel in the machine's 256 colours: each
 * pixel is the average of the source's pixels that fall in it, put on
 * white where they are transparent, then the nearest colour of the
 * palette. That is the line "img w h address" of tiny-kernel's browser.
 *
 * This is the part of the web that the tiny machine does not do itself:
 * the encrypted half (plan_tiny_browser.md, section 3). Everything from
 * the first < of the page on is the machine's.
 *
 * In m-ix the same work is mini-curl's (networking/'s Curl, on the
 * same lib_networking), which runs on mini-9pi itself, and the
 * pictures are decoded by the browser there; here both are the host's,
 * so tiny-kernel has no TLS and no decoder of PNG or JPEG. *)

val main : < Cap.network; Cap.open_in; Cap.stdout; Cap.argv; .. > -> int
