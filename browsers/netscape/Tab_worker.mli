(* Tab_worker: a tab's pieces (Tab.step: the page fetched, read and
   laid out, its scripts run, a picture) done by a worker beside the
   window (Worker_spawn: a thread, a domain), so that the window draws,
   scrolls and goes Back while a page is on its way. The worker is
   given a copy of the tab; the window keeps its own (Netscape):

      window                         worker
      ------                         ------
      give tab: n  --------------->  Tab.step
      draws its copy, scrolls;            |
      Back, a tab, an address: the        |
        piece n given up                  |
      a click on the page, a key in       |
        it: kept for later                |
      take () <--------------------  (n, tab')
      tab' merged with the copy (Tab.merged), what was kept done on it

   The tab's scripts (their engine is not a value but a store) run on
   one thread at a time: the worker's while a piece is out -- given, or
   given up and not done yet -- the window's otherwise: its timers
   wait, and so does what a click on the page or a key in it is to
   tell them. The cookies, written by the worker's requests, are read
   by the window when the tab has nothing left to do. One worker, one
   piece at a time.

   worker=wait (Waited): the window waits for each piece (the tests:
   the same frames at each run); worker=off (Inline): the window does
   the piece itself, as before (a frame waits for it). Under mini-ml a
   thread runs until it waits: the window yields at each frame while
   a piece is out, and the worker does it whole.

   modern: Chrome's tab (2008) is a process of its own, its renderer;
   Firefox moved its pages out of the window's process with
   Electrolysis (2016). Here the renderer is a thread, and a page's
   work is still done one piece after the other. *)

type working = Beside | Waited | Inline

(* Beside unless the flag says *)
val working : working ref

(* the piece of [tab] given to the worker (started the first time): its number *)
val give : < Cap.network; Cap.open_in; .. > -> Tab.t -> int

(* is a piece out (given, and not taken back)? *)
val out : unit -> bool

(* the piece done, if it is (Waited: waited for), with its number;
 * Error, what it raised *)
val take : unit -> (int * (Tab.t, exn) result) option
