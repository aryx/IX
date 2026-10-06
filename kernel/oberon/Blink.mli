(* A task and nothing else (Oberon's Blink, which blinks the board's
 * LED twice a second): here a small block at the display's lower
 * right corner. Blink.Run installs it, Blink.Stop removes it. *)
val run : unit -> unit
val stop : unit -> unit
