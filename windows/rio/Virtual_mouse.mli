(* A window's mouse (rio's Qmouse, Qcursor; xix's Virtual_mouse): what
 * a program that draws in a window opens as /dev/mouse and /dev/cursor. *)

(* Once the file is opened, the mouse in the window belongs to its
 * program, buttons and all, until the file is closed (the window's
 * text is then drawn again). A read gets the mouse's next change,
 * written as the kernel's /dev/mouse writes it: m, or r when the
 * window was moved or made another size, and four numbers. *)
val mouse : Device.t
(* A write sets the mouse's picture while the mouse is in the window.
 * The bytes are those of the kernel's /dev/cursor: the offset's two
 * numbers, then 32 bytes twice; fewer bytes bring back the arrow.
 * This is what Cursor.set writes. *)
val cursor : Device.t
