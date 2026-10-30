(* A toy version of DrScheme (PLT: Matthias Felleisen, Robert Bruce
 * Findler, Matthew Flatt, Shriram Krishnamurthi and others, Rice
 * University, 1995; renamed DrRacket in 2010), in the look of version
 * 209 (2004): the program in the Definitions window above, a prompt in
 * the Interactions window below, and Execute between them (-h says the
 * keys).
 *
 * DrScheme was made for teaching, with How to Design Programs (2001),
 * and everything in it follows from that: two windows, so that a
 * student defines, then experiments, as a mathematician does; teaching
 * languages that print a value as the expression making it ((list 1
 * 2), not (1 2)) and forbid what a beginner only gets wrong with;
 * errors that say what was expected, the culprit painted pink in the
 * program; images as values, printed as pictures; and the stepper,
 * evaluation shown as algebra.
 *
 * What's new here:
 *
 *  - Two windows over one machine (DrScheme_run): Execute makes a new
 *    Scheme machine (languages/scheme's Scheme_eval, a CESK machine),
 *    runs the definitions a form at a time, and leaves it for the
 *    prompt, whose expressions see the definitions -- the REPL, the
 *    oldest interface of Lisp, next to an editor.
 *
 *  - The program runs a budget of steps a frame (DrScheme_run's fuel):
 *    the machine stops where it is and goes on at the next frame, so an
 *    endless loop keeps the window alive, the running indicator
 *    turning, and Break is simply not running it any more. DrScheme
 *    needed a thread and a custodian for that; a machine whose stack is
 *    data needs a counter.
 *
 *  - Errors with their place (the model's pink): the language keeps
 *    each expression's span in the text (languages/sexpr), so the one
 *    that failed is painted, DrScheme's pink.
 *
 *  - Images as values (DrScheme_draw): (circle 20 "solid" "red") at
 *    the prompt prints a red disc. The language only describes images
 *    (Scheme_image); drawing them is the Playground's Bigbang way,
 *    whose combinators are 2htdp/image's.
 *
 *  - big-bang in the IDE (DrScheme_run): the machine stops at
 *    (big-bang ...) and hands the world to the host, which opens a
 *    window, calls the handlers -- each a nested run of the machine --
 *    on ticks, keys and the mouse, and gives the last world back as
 *    big-bang's value.
 *
 *  - The stepper (DrScheme_run): Beginning Student's evaluation as
 *    a series of rewritings (Scheme_step), the redex in green, what
 *    replaced it in purple.
 *
 * What it uses: languages/scheme and languages/sexpr (the language:
 * the reader, the machine, the stepper), gui's Text_edit (the two
 * texts: a piece table, undo for free), the Bigbang way (the images
 * drawn, HtDP's key and mouse events). Not Physics, not Camera2d.
 *
 * Exercises: Check Syntax (the arrows from each use to its binding,
 * the spans are there), check-expect and its report, Intermediate
 * Student (lambda, local), the teachpacks' own functions
 * (on-mouse's pointer shape, key-release), a file saved and opened,
 * the images inside a printed list drawn too, a garbage collector for
 * the machine's store.
 *
 * What Execute does, and the prompt after it:
 *
 *     the Definitions' text (a Text_edit)
 *        | Sexpr_read.read_all       the forms, each expression with
 *        |                           its span in the text
 *     a job: the forms to run        one at a time (DrScheme_run's work):
 *        | Scheme_syntax.top         a form checked, made an expression
 *        | Scheme_eval.start, run    a budget of steps a frame; then
 *        |-- Running                 on at the next frame
 *        |-- Done v                  v printed below; the next form
 *        |-- Failed err              said below, err's span pink above
 *        '-- World spec              big-bang: the host runs the world
 *     the machine, kept              Enter at the prompt: what was
 *                                    typed is a job on the same machine
 *
 * The program's parts, each with its own part of the story:
 *
 *     DrScheme          the first text, the first model, -h, the main
 *       | a frame: update, then view (the Playground's game)
 *       |-- DrScheme_update  the keys and the mouse, to whom they go; a
 *       |                    text changed by keys
 *       '-- DrScheme_view    the windows, back to front
 *     both over:
 *       DrScheme_run         Execute, Break, a budget of steps; a
 *                            big-bang run by the host; the stepper
 *       DrScheme_draw        where things are; text in cells, its colours;
 *                            an image described, drawn
 *       DrScheme_model       the types
 *
 * Where it stands in ix: a program of the Playground, as the games
 * are (a model, an update, a view of shapes; its window SDL's on
 * Linux, mini-rio's on mini-9pi), not a Tui program of cells as
 * mini-emacs and mini-turbopascal. The other programming environment
 * of ix, mini-turbopascal, is the same loop for another school: a
 * text, a key, the program run by a machine that gives the screen
 * back (Turbo_debug's slice is DrScheme_run's fuel). What differs is
 * what comes after the run: there a debugger over the machine's
 * stack, here a prompt in the program's own language and a stepper
 * that shows no machine at all.
 *
 * cs-history:
 * The prompt is Lisp's read-eval-print loop, as old as Lisp: type an
 * expression, see its value, the definitions made so far all there.
 * What DrScheme added is the Execute button's rule: the prompt
 * always talks to the program as it is written above, run from
 * nothing. In a Lisp or a Smalltalk left running for days, what the
 * prompt knows and what the text says drift apart (a function
 * renamed is still there under its old name); a beginner cannot
 * tell which is wrong. Starting a new machine at each Execute
 * removes the question, at the price of running everything again.
 *
 * why-study:
 * It is the one editor here whose design starts from who uses it.
 * Each of its parts answers something a beginner was seen to
 * stumble on: the language levels, an error message that otherwise
 * speaks of features not yet taught; the pink, a message without a
 * place; the stepper, "what does the computer do with this?". The
 * editors for programmers (mini-ed, mini-emacs) assume the model is
 * known and make its use short.
 *
 * References: Robert Bruce Findler, John Clements, Cormac Flanagan,
 * Matthew Flatt, Shriram Krishnamurthi, Paul Steckler and Matthias
 * Felleisen, "DrScheme: A Programming Environment for Scheme"
 * (Journal of Functional Programming, 2002): the design told by its
 * authors, the levels, the stepper, Check Syntax. Felleisen,
 * Findler, Flatt and Krishnamurthi, "How to Design Programs" (MIT
 * Press, 2001), the course it was made for. Scheme_step.mli and
 * Scheme_eval.mli have the stepper's paper and the machine's.
 *)
