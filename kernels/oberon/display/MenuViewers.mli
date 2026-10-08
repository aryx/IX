(* A viewer with a menu (Oberon's MenuViewers): a border, a menu frame
 * of one line at the top, a main frame under it. It gives the mouse
 * and the messages to the one of the two concerned, tells them when
 * its own rectangle changes, and is what the hand moves: the left key
 * held in the menu drags the viewer's top up or down; with the middle
 * key too, the viewer goes where the mouse is let go.
 *)

(* What a viewer tells its two frames, before it changes their
 * rectangle: (dy, y, h), the frame becomes [y, y + h), grown (Extend)
 * or cut (Reduce), its contents moved up by dy. *)
exception Extend of int * int * int
exception Reduce of int * int * int

(* [new_ menu main menu_h x y]: opened at (x, y), and drawn *)
val new_ : Display.frame -> Display.frame -> int -> int -> int -> Viewers.viewer
(* a viewer as that one, its two frames copies of that one's (each
 * asked by Oberon.Copy), not opened *)
val copy : Viewers.viewer -> Viewers.viewer
