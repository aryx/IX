(* The keyboard and the mouse of the kernel built for a web page (make
 * WEB=1, plan_web.md). At each tick of the clock, the kernel asks the
 * emulator what the person on the page typed and pointed at. On a
 * Raspberry Pi, a USB controller has a hub with a keyboard and a mouse
 * on it instead, and Kusb or usbd asks them.
 *
 *   the page's events --> the board's queue (Board.host_key, host_pointer)
 *        clock --> Kweb.clock --> Machine.web_input
 *                     a keyboard's report --> Hid.typed --> Kbd.kbdputsc
 *                     the mouse's state   --> Devmouse.at
 *
 * design:
 * A USB mouse that moves cost 5 of the 6 million instructions that a
 * page runs in a second: the controller's registers, the driver's
 * process, and the cursor drawn again. An emulator's host already knows
 * where the mouse is on the screen, so here the host gives that place,
 * and it draws the cursor too (with the cursor that Swcursor's load
 * gives it). The keys come as a USB keyboard's reports, so that Hid's
 * tables are the only ones.
 *
 * On a Raspberry Pi, and under an emulator with no page, nothing ever
 * comes: there is one call at each tick, and no more. *)

(* called at each tick: takes what was typed and pointed at since the
 * last tick *)
val clock : unit -> unit
