(* The switch between optimized code and the simpler code it replaced,
   which is kept, runnable, next to it.

   An optimization makes the code faster and harder to read. Someone
   reading the browser should be able to read the simple code first, to
   understand what is done, and the optimized one later, to learn the
   trick. So when a few simple lines become an algorithm (a memo, a
   laziness, an index), the simple function stays, as [xxx_simple], the
   fast one is [xxx_opti], and [xxx] chooses:

     let draw_simple b = (* every shape of the page, at once *) ...
     let draw_opti b = (* a line's shapes when it is shown *) ...
     let draw b = if !Mini_opti.enabled then draw_opti b else draw_simple b

   A test checks that the two agree, and the switch shows what the
   optimization buys: opti=off on mini-chrome's command line, and on
   scripts/perf/Page_bench.exe's, runs the simple paths.

   A matter of judgment, not a rule (docs/plans/plan_performance.md, "The
   way"): a small optimization is just made, and simple lines replaced
   by a few others can stay in a comment beside them, with no switch.
   The comments of every kind start "opti:" and give the
   numbers measured (grep -rn "opti:").

   After elm-playground's Opti (tiny_libs.graphics_core; its
   notes_opti_ocaml.md, section 18), which is the software rasterizer's
   switch and another one: opti=off does not touch it, so that what is
   measured with and without is our code alone.

   Code checking [enabled] (search for "Mini_opti.enabled"):
   - Browser_draw.later: a line's shapes built when it is first shown,
     not all the page's at each relayout (the simple way: built at
     once). A relayout of a long page 450 ms to 28; the explanation
     and its picture are in Browser_draw.mli.
   - Window_view.view: the shapes of the frame before given back when
     the model is the same but for its time, so that the platform does
     not draw a window at rest (the simple way, view_simple: a new list
     and a frame drawn, sixty times a second). In Window_view.mli.
   - Stroke_text.glyph: a letter as one picture made once
     (glyph_picture, Glyph_picture.mli) rather than its pen's ten to
     twenty shapes (glyph_segments, the simple way); see [letters].
   - Mdct.dct4: a block's cosine transform by a Fourier transform
     (dct4_opti) rather than by its definition (dct4_simple): a second
     of Vorbis decoded in 0.06 s, not 1.2. In Mdct.mli.
   - Selectors.has_word, Cascade.key, Computed's declarations: a class
     found in the attribute's text rather than in a list of its words;
     a rule with no id, class or name filed under an attribute's name
     or what its :where() holds rather than tried on every element; an
     element's declarations in a table rather than a list searched for
     each property. A style pass of GitHub's page: 3.0 G instructions
     to 1.3 (docs/plans/plan_performance.md, step 7).
   - Browser_tab.settle: a layout owed by a picture's arrival or a
     script's change of the tree, made once at the next frame rather
     than at each. GitHub's load: 39 layouts to 24.
   - Js_scope.global: a JavaScript engine's scopes as arrays, each name
     of the program remembering its place (find_opti; the places put in
     a copy of the tree by Js_quicken, which such an engine runs
     instead of the parser's), rather than a table in each scope
     searched by the name (lookup); and a call's frame made at once
     (Js_frame.opti, where Js_frame.simple declares name by name). With
     Js_operators.arithmetic and Js_eval.item (two numbers, an array's
     item, with no conversion): the engine four times faster. In
     Js_scope.mli; tests/js is run on both.
   - Js_eval.call_value, with [compiled]: a function's body compiled to
     closures when first called (Js_compile), not walked at each call:
     a quarter more on a real program. In Js_compile.mli.
   - Media.open_: an Ogg file's sound decoded as it plays
     (Sound_stream), not whole when the file is opened. *)
(* ix: the author's mini-chrome's libs/opti/Mini_opti.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* true: the optimized versions (the default) *)
val enabled : bool ref

(* with [enabled]: a JavaScript function's body compiled to closures
 * when it is first called (Js_compile), rather than its tree walked
 * at each call (Js_eval), which false keeps, with the rest of the
 * optimizations: what the compiler alone buys *)
val compiled : bool ref

(* how a letter of the page is drawn, where there are several
 * ways to set against each other (docs/plans/plan_performance.md, step 4b);
 * with [enabled] false, the simple one whatever this says:
 * - Segments: the pen's strokes, a rectangle a segment and a dot a
 *   point (Stroke_text.glyph_segments): the simple way, to read first;
 *   letters=segments on the command line;
 * - Pictures: a picture a letter, made once (Glyph_picture): the
 *   default. A frame of about:chrome drawn in 8 ms instead of 74. *)
type letters = Segments | Pictures

val letters : letters ref
