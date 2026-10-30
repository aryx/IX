(* Weather_panel: the forecast on the window's right, over the map:

      +------------------------------+
      | Tours, Indre-et-Loire...     |
      |  (sun)  10°                  |
      |  clear, wind 13 km/h         |
      |  the next 24 hours, 5° to 14°|
      |  ...:::::::.....             |   whole degrees to whole pixels:
      |  Sat 31  (cloud)  5° to 15°  |   the same frame by both compilers
      |  Sun 1   (rain)   6° to 14°  |
      |  Open-Meteo.com, CC BY 4.0   |
      +------------------------------+

   The pictures of the sky are made of circles and rectangles, so they
   are the same on every platform and are drawn at any size. *)

(* what the panel has to say *)
type state = Waiting | Came of Weather.t | Failed of string

(* where it is, for the mouse: [inside fw fh mx my] *)
val inside : float -> float -> float -> float -> bool

(* [panel fw fh name state] *)
val panel : float -> float -> string -> state -> Playground.shape list
