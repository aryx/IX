(* tiny-machine in a web page (plan_web.md, stage 0): TinyMachineDevices's
 * machine compiled by js_of_ocaml, its screen a canvas, its console
 * the page's text, its keys and its mouse the page's. TinyMachine.ml is
 * the same machine in a terminal. Not a program of t-ix's own tools:
 * OCaml and js_of_ocaml build it (./tiny-machine -web dir tiny-kernel
 * builds the page's directory; TinyMachineWeb.html is the page).
 *
 * The page gives three elements, by their ids: screen (a canvas, 640
 * by 480), console (the text), status (a line). The kernel's image is
 * fetched: boot.img beside the page, or what the address says
 * (?image=kernel.img&disk=fs.img: t6, whose disk's writes last
 * as long as the page), or, before both, what the page says in a
 * variable of its own, tiny_machine = { image: ..., disk: ... }, each
 * an address (docs/t-ix.html, the website's page: its files are in
 * another place, the assets').
 *
 * The keys are of two kinds, as TinyMachine's are with -window, where
 * a person types in the terminal or in the window. They are a
 * terminal's unless said otherwise: the line is shown on the console
 * as it is typed, a backspace corrects it, and Enter gives it to the
 * machine (a kernel's console echoes nothing, a terminal does). They
 * are the screen's, each byte to the machine as it is typed (a game's
 * arrows, a window's text, which the window system echoes), when the
 * screen was clicked (it then has the page's focus, and the page's
 * style frames it) and a program has drawn on it: on a black screen
 * nothing would show them. (A first version went by where the mouse
 * was: it is over the screen most of the time, and nothing was echoed.)
 *
 * The loop is the browser's: at each frame (requestAnimationFrame) the
 * instructions the time since the last one is worth, at the machine's
 * speed (TinyMachineDevices.rate), and no more than [budget] milliseconds
 * of them, so that a browser too slow for the speed still draws and
 * listens: the machine is then slower, and the status line says so,
 * as a part of the full speed. Then the screen, if it changed, and the console's new text.
 *
 * The machine's wire (plan_tiny_network.md) leads to the page: its
 * other end is TinyMachinePeer, tiny-kernel's own stack run here, and the
 * page gives it its documents, which is where the Internet comes in:
 *
 *     tiny-kernel: wiki plan 9                 this page
 *        | IL, over the wire's packets  ===>   TinyMachinePeer, port 70: the line
 *        |                                        | [wikipedia]: one fetch, a search;
 *        |                                        |   the first article's sentences
 *        |                                        | [picture]: its picture's address,
 *        |                                        |   read and made small by the
 *        |                                        |   browser, each pixel then the
 *        |                                        |   nearest of the screen's colours
 *     the text, then a row      <===  IL  ===  a message of text, a message a row
 *     painted at each message
 *
 * A name alone (get) is a file fetched from www/ beside the image; a
 * wiki that Wikipedia does not answer is a picture kept there. A page
 * may fetch only from sites that allow it, and Wikipedia does: the
 * machine has no way out but this end of its wire. Three more
 * elements, which a page may leave out: wire (a canvas: a dot for
 * each packet, crossing in half a second of the page's time, falling
 * when lost), wirelog (the last packets, a line each, as
 * tiny-machine -net-trace says them) and lose (a button: the other
 * end's next packet is lost, and it says how many were).
 *
 * An int has 32 bits here (TinyMachineCPU.ult says what that asks). *)

(* A program: it starts when the page has loaded it, and gives nothing
 * to another file. *)
