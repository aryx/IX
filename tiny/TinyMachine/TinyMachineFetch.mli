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
 * This is the part of the web that the tiny machine does not do itself:
 * the encrypted half (plan_tiny_browser.md, section 3). Everything from
 * the first < of the page on is the machine's. *)

val main : < Cap.network; Cap.open_in; Cap.stdout; Cap.argv; .. > -> int
