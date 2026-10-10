(* Event_loop: one thing at a time -- how a page's scripts, its
   timers and its events share a single thread; and setTimeout.

   A script is never interrupted. While a function runs, no other
   script runs, no click is handled, the page is not drawn: it runs
   to its end ("run to completion"), and so needs no lock on anything.
   Everything that is to happen *later* -- a timer's function, a
   click's handler, an answer from the network -- waits in a queue,
   and the browser's main thread is a loop that takes them one by
   one:

     forever:
       take the oldest *task* waiting      a script, an event, a timer
       run it to its end
       run every *microtask* there is      the promises' thens, until
                                           none is left
       if the page changed, lay it out and draw it

   That is the event loop. A task is what the outside world brings; a
   microtask is what the running code leaves to be done right after it
   (a promise settled: Js_promise.mli) -- before any other task, and
   before the page is drawn. Hence the question every JavaScript
   interview asks:

     console.log(1)
     setTimeout(() => console.log(4), 0)
     Promise.resolve().then(() => console.log(3))
     console.log(2)

   prints 1 2 3 4: the script is a task and runs to its end (1, 2);
   the promise's then is a microtask, run as the task ends (3); the
   timer's function is another task, and comes after (4), however
   small its delay.

   Here: [install] gives a page setTimeout, setInterval and their
   clear functions, which only put a function in a list with the time
   it is due; [advance] is the loop's turn for the timers -- the
   browser calls it at each frame with the time gone by, and each
   timer due is run as a task ([task]: Browser_script's, which runs
   the microtasks after it and reports an error on the console). The
   other tasks are the browser's to bring: a click (Browser_script's
   [click]), an answer ([answer]), a WebSocket's message (in
   mini-chrome; ix has no WebSocket).
   requestAnimationFrame is a timer of a sixtieth of a second.

   In ix the loop's "forever" is the window's: mini-netscape is a
   program of the playground's, called once a frame, and at each
   frame it does a piece of what the page still waits for (Tab.step:
   a file fetched, the scripts run, a request answered), handles the
   mouse and the keys (Tab.click: a task), and moves the page's clock
   by a sixtieth of a second (Tab.advance: the timers due, a task
   each). The clock is the frames', not the wall's: a frame is a
   sixtieth of a second to the page however long it took, and a
   recorded session sees the same ticks at each run (the timers wait
   while the page or its scripts are still on their way). The kernel
   has the same shape one
   level down: an interrupt is its click, the clock's tick its timer,
   and the scheduler its loop; what differs is that a process can be
   interrupted and a script cannot.

   Not here: a timer's delay is not clamped as a browser's (4 ms at
   least for a timer set from a timer five deep, a second in a tab
   not shown); tasks have no priorities; no idle callbacks.

   cs-history:
   setTimeout is of the first JavaScript (Netscape Navigator 2, 1995),
   setInterval of Navigator 4 (1997). The loop itself is older than
   the web: it is how every graphical program has been written since
   the Macintosh (1984) -- "get the next event, handle it" -- and
   JavaScript inherited it by living inside one. What JavaScript added
   was to have nothing else: no threads, no blocking call (but alert),
   so that everything slow had to be asked for and answered later, by
   a callback.

   cs-history:
   That style left the browser with Node.js (Ryan Dahl, 2009): a
   server as one loop and callbacks, on the bet that a server mostly
   waits. The microtask came with promises (ES2015; before them,
   MutationObserver, 2012), and the loop was only written down as a
   standard in HTML5 (the "event loop" of the HTML Standard), ten
   years after browsers had it.

   modern:
   A real browser has one such loop for each group of pages that can
   reach each other, another for each worker, and takes the tasks
   from several queues by priority (input before timers). Rendering
   is a step of the loop, at the screen's rate, and
   requestAnimationFrame's callbacks run in that step, not as timers.

   References: the HTML Standard, section 8.1.7, "Event loops", and
   8.6, "Timers"; Philip Roberts, What the heck is the event loop
   anyway? (JSConf EU, 2014); Jake Archibald, Tasks, microtasks,
   queues and schedules (2015). *)
(* ix: the author's mini-chrome's src/webapi/run/Event_loop.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* setTimeout, setInterval, clearTimeout, clearInterval,
 * requestAnimationFrame and cancelAnimationFrame, defined as globals *)
val install : t -> (string -> (value list -> value) -> unit) -> unit

(* [add t [f; ms] ~repeat]: f to be run in ms milliseconds (1 at
 * least), again every ms if [repeat]; the timer's number. [frame]:
 * requestAnimationFrame's, whose f is given the time *)
val add : frame:bool -> t -> value list -> repeat:bool -> value

(* the timer of that number forgotten *)
val clear : t -> value list -> value

(* [advance t ms ~task]: the page's clock moved on by [ms]; the timers
 * due run, the earliest first, each given to [task] with what it is
 * called with (the time, for an animation frame's; else undefined), a
 * thousand at most per call *)
val advance : t -> float -> task:(value -> value -> unit) -> unit
