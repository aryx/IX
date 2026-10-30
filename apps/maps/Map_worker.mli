(* Map_worker: what is fetched beside the window, which does not wait: the
   tiles, and now and then a place or a forecast (a job, before the tiles).

   Http_client blocks, and a map cannot: it must move under the mouse
   while a tile is on its way. So one worker (Worker_spawn: a thread)
   fetches and reads the tiles, one after the other, and the window draws
   what it has:

      window                             worker
      ------                             ------
      want [a; b; c]      ----------->   takes the first: a
      moves; want [d; e]: what is no     fetches it, reads its PNG
        longer in view is not fetched      |
      take () <------------------------  (a, its picture)
                                         takes the first: d

   [want] replaces the list, so that the map asks only for what is in
   view at that moment, as OSM's tile policy asks: a window dragged across
   a country fetches what it stops on, not all that it went over.

   One worker, one connection kept open (Keep_alive), which is what the
   policy prefers too; a browser would have six, and the mini-chrome's
   numbers (Keep_alive.mli) say what that buys.

   Waited: for the tests. The window gives one tile and waits for it, each
   frame: the frame n of a session has n tiles, on any machine. Under
   mini-ml a thread runs until it waits or yields, a system call stopping
   all of them: the window yields at each frame while tiles are out, and
   the worker gives its turn back after each tile. *)

type mode = Beside | Waited

val mode : mode ref

(* [start fetch]: the worker; [fetch] is what it does of a tile *)
val start : (Tiles.key -> (Rgba_image.t, string) result) -> unit

(* the tiles the window wants now, the first first (those being fetched
 * ignored) *)
val want : Tiles.key list -> unit

(* the tiles done since the last call, with what the fetch gave *)
val take : unit -> (Tiles.key * (Rgba_image.t, string) result) list

(* [job f]: [f] run by the worker, before any more tiles; it leaves what
 * it finds where the window looks *)
val job : (unit -> unit) -> unit

(* something asked and not taken yet? *)
val out : unit -> bool
