(* The switch between optimized code and the simpler code it replaced,
   which is kept, runnable, next to it.

   An optimization makes the code faster and harder to read. Someone
   reading the browser should be able to read the simple code first, to
   understand what is done, and the optimized one later, to learn the
   trick. So when a few simple lines become an algorithm (a memo, a
   laziness, an index), the simple function stays as [xxx_simple], the
   fast one is [xxx_opti], and [xxx] chooses:

     let draw_simple b = (* every shape of the page, at once *) ...
     let draw_opti b = (* a line's shapes when it is shown *) ...
     let draw b = if !Mini_opti.enabled then draw_opti b else draw_simple b

   A test checks that the two agree, and the switch shows what the
   optimization buys: opti=off, on mini-chrome's command line and on
   scripts/perf/Page_bench.exe's, runs the simple paths.

   This is a matter of judgment, not a rule (docs/plans/plan_performance.md,
   "The way"). A small optimization is just made, and the simple lines
   it replaced by a few others can stay in a comment beside them, with
   no switch. The comments of every kind start with "opti:" and give
   the numbers measured (grep -rn "opti:").

   This follows elm-playground's Opti (tiny_libs.graphics_core; its
   notes_opti_ocaml.md, section 18), which is the switch of the
   software rasterizer, and is another switch: opti=off does not touch
   it, so that what is measured with and without is our code alone.

   In ix, of all that follows, the engine came with its switch and the
   rest of the browser came without it (mini-netscape is built on
   mini-chrome's first versions). The code that checks [enabled] here
   is:

   - Js_scope.global, Js_operators.arithmetic, Js_eval.item and
     put_item, and Js_eval's call with [compiled] (Js_compile), all told
     in the list below, which is mini-chrome's;
   - Js_value.join, which keeps a long text made by + as a rope
     (Js_value.mli);
   - Js_globals.store, which keeps a Map's and a Set's entries in a
     table by key, where the simple way is to go through a list;
   - Script_dom's querySelector and matches.

   The switch is set by the tests, not by a command line. MINI_OPTI=off
   runs the engine's tests on the simple paths, and MINI_OPTI=walk runs
   them with a function's body walked, not compiled; the three ways
   must agree (the tests' modes.sh).

   design:
   Keeping the simple code beside the fast one, with a switch to run
   it, is the rule of all of ix, since ix is read before it is run: the
   reader is owed the version that says what is done. mini-qemu has the
   same for its processor (Arm32's execute, with Arm32_fast beside it;
   Board's forget_used and keep_decoded), each turned off by a flag,
   and a boot's output is compared with and without them. What the
   switch costs is a test of a boolean at each choice. What it buys,
   besides the reading, is the measure: an optimization that cannot be
   turned off cannot be weighed.

   The code that checks [enabled] in mini-chrome (search for
   "Mini_opti.enabled"):
   - Browser_draw.later builds a line's shapes when the line is first
     shown, rather than all the page's shapes at each relayout (the
     simple way builds them at once). A relayout of a long page went
     from 450 ms to 28; the explanation and its picture are in
     Browser_draw.mli.
   - Window_view.view gives back the shapes of the frame before when
     the model is the same except for its time, so that the platform
     does not draw a window at rest (the simple way, view_simple, makes
     a new list and draws a frame, sixty times a second). See
     Window_view.mli.
   - Stroke_text.glyph draws a letter as one picture made once
     (glyph_picture, Glyph_picture.mli) rather than as its pen's ten to
     twenty shapes (glyph_segments, the simple way); see [letters].
   - Mdct.dct4 computes a block's cosine transform by a Fourier
     transform (dct4_opti) rather than by its definition (dct4_simple):
     a second of Vorbis is decoded in 0.06 s, not 1.2. See Mdct.mli.
   - Selectors.has_word, Cascade.key and Computed's declarations: a
     class is found in the attribute's text rather than in a list of
     its words; a rule with no id, class or name is filed under an
     attribute's name or what its :where() holds, rather than tried on
     every element; and an element's declarations are in a table
     rather than a list searched for each property. A style pass of
     GitHub's page went from 3.0 G instructions to 1.3
     (docs/plans/plan_performance.md, step 7).
   - Browser_tab.settle: a layout owed to a picture's arrival or to a
     script's change of the tree is made once, at the next frame,
     rather than at each change. GitHub's load went from 39 layouts to
     24.
   - Js_scope.global keeps a JavaScript engine's scopes as arrays, and
     each name of the program remembers its place (find_opti; the
     places are put in a copy of the tree by Js_quicken, which such an
     engine runs instead of the parser's tree). The simple way is a
     table in each scope, searched by the name (lookup). A call's frame
     is also made at once (Js_frame.opti, where Js_frame.simple
     declares name by name). Together with Js_operators.arithmetic and
     Js_eval.item (two numbers, or an array's item, with no
     conversion), this makes the engine four times faster. See
     Js_scope.mli; tests/js is run both ways.
   - Js_eval.call_value, with [compiled], compiles a function's body to
     closures when it is first called (Js_compile), rather than walking
     it at each call: a quarter faster on a real program. See
     Js_compile.mli.
   - Media.open_ decodes an Ogg file's sound as it plays
     (Sound_stream), not whole when the file is opened. *)
(* ix: copied from libs/opti/Mini_opti.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

(* true for the optimized versions (the default) *)
val enabled : bool ref

(* with [enabled]: a JavaScript function's body is compiled to
 * closures when it is first called (Js_compile), rather than its tree
 * being walked at each call (Js_eval). false keeps the walk, with the
 * rest of the optimizations, to show what the compiler alone buys. *)
val compiled : bool ref

(* how a letter of the page is drawn in mini-chrome, where there are
 * several ways to set against each other (docs/plans/plan_performance.md,
 * step 4b). Nothing in ix reads it: Stroke_text always draws the pen's
 * strokes. With [enabled] false, it is the simple one whatever this
 * says:
 * - Segments: the pen's strokes, with a rectangle for each segment and
 *   a dot for each point (Stroke_text.glyph_segments). This is the
 *   simple way, to read first.
 * - Pictures: one picture for each letter, made once (Glyph_picture).
 *   This is the default; a frame of about:chrome is drawn in 8 ms
 *   instead of 74. *)
type letters = Segments | Pictures

val letters : letters ref
