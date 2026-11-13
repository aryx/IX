(* tiny-machine in a web page (plan_web.md, stage 0). It is
 * TinyMachineDevices's machine compiled by js_of_ocaml: its screen is a
 * canvas, its console is the page's text, and its keys and its mouse
 * are the page's. TinyMachine.ml is the same machine in a terminal. It
 * is not built by t-ix's own tools, but by OCaml and js_of_ocaml
 * (./tiny-machine -web dir tiny-kernel builds the page's directory, and
 * TinyMachineWeb.html is the page).
 *
 * The page gives three elements, by their ids: screen (a canvas, 1024
 * by 768), console (the text) and status (a line). The kernel's image
 * is fetched, either from boot.img beside the page or from what the
 * address says, together with its disks: none, disk, or disk and
 * disk2. For example, ?image=boot.img&disk=disk.img&disk2=src.img
 * gives tiny-kernel's system and sources, and
 * ?image=kernel.img&disk=fs.img gives t6; a disk's writes last as long
 * as the page. The page can also say what to fetch in a variable of
 * its own, tiny_machine = { image: ..., disk: ..., disk2: ... }, where
 * each is an address, and this comes before both. docs/t-ix.html, the
 * website's page, does this, because its files are in another place,
 * with the assets.
 *
 * The keys are of two kinds, as TinyMachine's are with -window, where
 * a person types either in the terminal or in the window. By default
 * the keys are a terminal's: the line is shown on the console as it is
 * typed, a backspace corrects it, and Enter gives it to the machine (a
 * kernel's console echoes nothing, but a terminal does). The keys are
 * the screen's when the screen was clicked (it then has the page's
 * focus, and the page's style frames it) and a program has drawn on
 * it, since on a black screen nothing would show them. Each byte then
 * goes to the machine as it is typed: a game's arrows, or a window's
 * text, which the window system echoes. (A first version chose by
 * where the mouse was, but the mouse is over the screen most of the
 * time, and so nothing was echoed.)
 *
 * The loop is the browser's. At each frame (requestAnimationFrame), it
 * runs as many instructions as the time since the last frame is worth
 * at the machine's speed (TinyMachineDevices.rate), but no more than
 * [budget] milliseconds of them. This way a browser too slow for that
 * speed still draws and listens: the machine is then slower, and the
 * status line says so, as a percentage of the full speed. Then the
 * loop draws the screen, if it changed, and the console's new text.
 *
 * The machine's wire (plan_tiny_network.md) leads to the page. The
 * wire's other end is TinyMachinePeer, which is tiny-kernel's own
 * stack run here, and the page gives the peer its documents. This is
 * where the Internet comes in:
 *
 *  tiny-kernel: www OCaml                this page
 *     | IL, over the wire's packets ===> TinyMachinePeer, port 70: the line
 *     |                                     | "GET address": the page fetched
 *     |                                     |   (Wikipedia's REST HTML)
 *     |                                     | "img w h address": its picture,
 *     |                                     |   read and made small by the
 *     |                                     |   browser, each pixel then the
 *     |                                     |   nearest of the screen's colours
 *  the page drawn, then   <===  IL  ===  its messages; a picture's, a
 *  its pictures a row at                  message a row
 *  each message
 *
 * A name alone (from get) asks for a file, which is fetched from www/
 * beside the image. When a page cannot be fetched, a copy kept there
 * answers, if there is one. A page may fetch only from sites that
 * allow it, and Wikipedia does; the machine has no other way out than
 * this end of its wire. A page may also give three more elements:
 * - wire, a canvas that shows a dot for each packet; the dot crosses in
 *   half a second of the page's time, and falls when the packet is
 *   lost;
 * - wirelog, the last packets, one line each, as tiny-machine
 *   -net-trace prints them;
 * - lose, a button that makes the other end's next packet lost, and
 *   that says how many were lost.
 *
 * An int has 32 bits here (TinyMachineCPU.ult says what that asks of
 * the code).
 *
 * twin:
 * The twin is mini-qemu's page (MiniQemuWeb, in raspberry/web/), made
 * after this one (stage 1 of plan_web.md). It runs the Pi 1's board,
 * with the same three elements and the same two kinds of keys. That
 * page needs more to keep up: the instructions that run often are
 * translated to JavaScript (Jit), and the emulator runs memdraw's
 * general loop for its kernel (Hostdraw). It has no network.
 * tiny-machine's instructions are few and simple, and an interpreter
 * alone runs them at the speed the kernel was made for. *)

(* This is a program: it starts when the page has loaded it, and it
 * exports nothing to another file. *)
