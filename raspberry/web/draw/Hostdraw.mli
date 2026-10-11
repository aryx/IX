(* memdraw's general loop, run by the emulator for the kernel it runs:
 * mini-9pi built for a web page (make WEB=1) asks its machine to
 * compose the pixels of a draw that none of its faster paths has.
 *
 *     Memdraw.draw (the kernel, ARM)          the board (the host)
 *       faster paths: a fill, a copy, a character
 *       else hosted --> web_draw --> mrc p15, 7, r0, c15, c0, 4
 *                                       --> Board.host_draw --> Hostdraw
 *                                             Memgeneral.general on the
 *                                             images in the board's RAM
 *       else Memgeneral.general (the kernel's own)
 *
 * design: the loop is not written again here. Memgeneral, Memimage and
 * Memchan are the kernel's files (this directory's dune copies them),
 * compiled for the host; an image here is the kernel's, its bytes the
 * board's RAM itself and its xbase moved by where the image's bytes
 * are in it, so that Memimage's byteaddr gives a place in the RAM:
 * nothing is copied, and two images on the same bytes are still so.
 * The pixels are the kernel's own loop's by construction. What the
 * host saves is the interpreter: a pixel composed is about a thousand
 * of the board's instructions, each some hundreds of the host's; a
 * menu of mini-rio's, 20 million instructions, was 4 seconds in a
 * page.
 *
 * Declined (0, and the kernel's loop runs): an image with a colour
 * map (Memdata's tables are not here), bytes that are not RAM in one
 * piece, a destination's rectangle outside its bytes. *)

(* Board.host_draw set to this module's *)
val install : unit -> unit

(* the draws done and declined since the start *)
val drawn : int ref
val declined : int ref
