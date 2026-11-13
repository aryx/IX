(* Tab_worker has a tab's pieces of work done by a worker beside the
   window (Worker_spawn: a thread or a domain), so that the window can
   draw, scroll and go Back while a page is on its way. A piece is one
   call of Tab.step: the page fetched, read and laid out, its scripts
   run, or a picture fetched. The worker is given a copy of the tab,
   and the window keeps its own (see Netscape):

      window                         worker
      ------                         ------
      give tab, gets n ----------->  Tab.step
      draws its copy, scrolls;            |
      on Back, a tab or an address,       |
        piece n is given up               |
      a click or a key on the page        |
        is kept for later                 |
      take () <--------------------  (n, tab')
      tab' is merged with the copy (Tab.merged), and what was kept is
        done on it

   The tab's scripts run on one thread at a time, because their engine
   is not a value but a store. They run on the worker's thread while a
   piece is out (given, or given up and not done yet), and on the
   window's thread otherwise. While a piece is out, their timers wait,
   and so do the events that a click or a key on the page would send
   them. The cookies are written by the worker's requests, and the
   window reads them when the tab has nothing left to do. There is one
   worker, and it does one piece at a time.

   With worker=wait (Waited), the window waits for each piece, so that
   the tests see the same frames at each run. With worker=off (Inline),
   the window does the piece itself, as before, and a frame waits for
   it. Under mini-ml a thread runs until it waits, so the window yields
   at each frame while a piece is out, and the worker does the piece
   whole.

   modern:
   In Chrome (2008) each tab is a process of its own, its renderer;
   Firefox moved its pages out of the window's process with Electrolysis
   (2016). Here the renderer is a thread, and a page's work is still
   done one piece after the other. *)

type working = Beside | Waited | Inline

(* Beside, unless the worker= flag says otherwise *)
val working : working ref

(* Gives the worker a piece of [tab] (starting the worker the first
 * time) and returns the piece's number. *)
val give : < Cap.network; Cap.clock; Cap.open_in; .. > -> Tab.t -> int

(* is a piece out (given, and not taken back)? *)
val out : unit -> bool

(* The piece done, with its number, if it is done (with Waited, [take]
 * waits for it). The result is Error with what Tab.step raised, when
 * it raised. *)
val take : unit -> (int * (Tab.t, exn) result) option
