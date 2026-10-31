(* A window's mouse (rio's Qmouse, Qcursor; xix's Virtual_mouse): what
 * a program that draws in a window opens as /dev/mouse and /dev/cursor. *)

(* opened: the mouse in the window is its program's, buttons and all,
 * until it is closed (the window's text is then drawn again); a read:
 * the mouse's next change, as the kernel's /dev/mouse says it (m, or
 * r when the window was moved or made another size, and four numbers) *)
val mouse : Device.t
(* written: the mouse's picture while it is in the window (the kernel's
 * /dev/cursor's bytes: the offset's two numbers, then 32 bytes twice;
 * fewer: the arrow again). What Cursor.set writes *)
val cursor : Device.t
