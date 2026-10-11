(* The keyboard and the mouse of the kernel built for a web page (make
 * WEB=1, plan_web.md): what the page's person types and points, asked
 * of the emulator at each tick of the clock, where a Raspberry Pi has
 * a USB controller, a hub, a keyboard and a mouse on it, and Kusb or
 * usbd asking them.
 *
 *   the page's events --> the board's queue (Board.host_key, host_pointer)
 *        clock --> Kweb.clock --> Machine.web_input
 *                     a keyboard's report --> Hid.typed --> Kbd.kbdputsc
 *                     the mouse's state   --> Devmouse.at
 *
 * design: a USB mouse that moves cost 5 of the 6 million instructions
 * a page runs in a second: the controller's registers, the driver's
 * process, the cursor drawn again. An emulator's host has the mouse's
 * place on the screen already; here it gives it, and draws the cursor
 * too (Swcursor's load). The keys come as a USB keyboard's reports, so
 * that Hid's tables are the only ones.
 *
 * On a Raspberry Pi, and under an emulator with no page, there is
 * never anything: a call each tick, and no more. *)

(* at each tick: what was typed and pointed since the last *)
val clock : unit -> unit
