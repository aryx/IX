(* Svg: a picture as shapes -- the small part of SVG that logos and
   icons use, turned into pixels.

   A PNG is pixels; an SVG (Scalable Vector Graphics, W3C, 2001) is a
   drawing's description, XML: shapes filled and stroked, in a
   coordinate system of its own that its viewBox maps onto any size.
   The web's logos and icons are SVG now -- Hacker News' "Y", its vote
   arrows, Wikipedia's wordmark, GitHub's 242 icons, Google's "G" --
   because one file is sharp at every size.

     <svg viewBox="0 0 24 24" width="48" height="48">
       <path d="M4 12 L12 4 L20 12 Z" fill="#f60"/>
     </svg>

   A triangle, drawn in a square of 24 units and shown on 48 pixels:
   every number is doubled on its way to the screen.

   A page has them in four ways, and all four come here:

     <img src=logo.svg>          a file, or a data: URL with the text
                                 in it: read by [parse], drawn at its
                                 own [size]   (Browser_picture)
     <svg>...</svg> in the page  no file and no parsing: the HTML
                                 parser already made the elements, and
                                 the browser hands them as [node]s
                                 (Browser_boxes)
     background: url(x.svg)      as the first, behind a box
     mask: url(x.svg)            the drawing's coverage alone, painted
                                 in the box's colour: an icon that
                                 takes the text's colour

   Three stages, each a part of the file:

     text --[parse]--> nodes --shapes--> contours --painting--> Rgba_image
                                 |                    |
                         Affine, Curve.flatten   Stroke.contours,
                                                 Fill.polygons_aa

   **Reading** ([parse]): XML as far as SVG files need -- elements and
   their attributes, <x/>, comments, <?xml ...?>, <!DOCTYPE>, CDATA and
   text skipped -- into a tree of [node]s (a browser gives its inline
   <svg>'s from its own DOM, as the same nodes).

   **The shapes**, each made a list of polygons (its contours) in the
   picture's pixels:

     rect (x y width height), circle (cx cy r), ellipse (cx cy rx ry),
     line, polyline, polygon (points), and path (d) with its commands,
     absolute and relative (lower case): M L H V (lines), C S (cubic
     Bézier curves, S's first control point the mirror of the last),
     Q T (quadratic ones), A (elliptical arcs: SVG's endpoint form
     converted to a centre and angles, appendix F.6), Z (closed);

   the curves flattened into lines (Curve.flatten, a tenth of a pixel
   off at most), through the transforms of the elements around them
   (transform: translate, scale, rotate, matrix; composed as Affine)
   and the viewBox's (scaled uniformly and centred, SVG's default
   preserveAspectRatio "xMidYMid meet").

   The path is the format's heart, and a language of its own, made to
   be short: a letter, then numbers, the letter left out when it
   repeats, the separators left out where a sign or a point can do
   (M4 12l8-8 8 8z is the triangle above). An icon set's file is
   mostly these strings, written by a drawing program and by nobody's
   hand.

   **Painting**: fill (default black; none; a colour: #rgb, #rrggbb,
   rgb(), a few names, currentColor the caller's colour) with its rule
   (nonzero, evenodd), stroke (default none) of stroke-width, and the
   opacities (opacity, fill-opacity, stroke-opacity) -- attributes or
   style="fill: ...", inherited down the tree as CSS properties are. A
   shape is filled by Fill.polygons_aa (its stroke by Stroke.contours
   first), into a framebuffer that has no alpha: so each shape's
   coverage is drawn white on black, then laid onto the picture in its
   colour at that coverage times its opacity -- Porter and Duff's "over".

   The two rules say what is inside a path that crosses itself or has
   several contours (Fill.mli draws them). Evenodd: a point is inside
   if a ray from it crosses the contours an odd number of times; a
   ring is two circles, whichever way they turn. Nonzero: each
   crossing counts +1 or -1 by the contour's direction, and inside is
   where the sum is not 0; the ring's inner circle must turn the other
   way. A letter O, a doughnut, GitHub's cat in its circle are holes
   made this way.

   Worked example (the tests'): a 4 by 4 picture, <rect x=1 y=1
   width=2 height=2 fill=red/>: its 4 middle pixels opaque red, the
   rest transparent.

   Not done: gradients and patterns (fill="url(#...)", drawn grey), text,
   <use> and <symbol>, clipping, masks, filters, markers, dashes, CSS
   <style> sheets inside the SVG, stroke joins other than round,
   animation.

   Where it stands in ix: the third reader of the same picture of the
   world, after Pdf_render (PDF's operators m, l, c, h, f, S under cm)
   and before the playground's own shapes: all three end as contours
   given to Fill, through Affine and Curve. Its XML is read here, in
   some sixty lines, and not by the browser's HTML parser, which a
   picture's file must not need.

   cs-history:
   Where it came from. Its picture of the world is PostScript's
   (Warnock and Geschke, Adobe, 1984): a path built by moving, drawing
   lines and curves, and closing; then filled, by one of the two
   rules, or stroked with a pen of some width; all under a current
   transform. PostScript said moveto, lineto, curveto, closepath; SVG
   says M, L, C, Z. PDF (1993) is the same model without the
   programming language, and the curves are those Pierre Bezier at
   Renault and Paul de Casteljau at Citroen drew car bodies with
   around 1960 (Curve.mli).

   cs-history:
   In 1998 the W3C was sent two proposals to put that model in a page
   as XML, within weeks: PGML, the Precision Graphics Markup Language
   (Adobe, IBM, Netscape, Sun), PostScript's model spelt in tags; and
   VML, the Vector Markup Language (Microsoft, Macromedia and others),
   which Internet Explorer 5 shipped. The working group took neither
   and made a third from both: SVG 1.0, a Recommendation in September
   2001; SVG 1.1 in 2003, which is still what files are written in.

   cs-history:
   Then ten years of waiting. A browser showed SVG through Adobe's
   plug-in; vector drawings on the web were Flash's (Macromedia's,
   then Adobe's own). Firefox 1.5 drew SVG itself in 2005, Opera and
   Safari followed, and Internet Explorer, which had VML, only in
   version 9, in 2011. Two things then made it the web's way to draw
   an icon within a few years: telephones whose browsers had no Flash
   (the iPhone, 2007) and whose screens had two and three dots to a
   CSS pixel, where a PNG icon is either blurred or sent in three
   sizes; and HTML5's parser (Html_tree.mli), which let <svg> stand
   in a page with no namespace and no XML.

   others:
   <canvas> (Apple, 2004; then HTML5), the other way a page draws: the
   same model again -- moveTo, lineTo, bezierCurveTo, fill, stroke --
   but as calls of a script that leave only pixels. SVG keeps the
   drawing: its shapes are elements of the document, found by a
   selector, styled by a sheet, given a listener. Retained against
   immediate, the old pair of computer graphics; a chart of ten
   thousand points wants the second, an icon or a diagram the first.

   others:
   An icon font, what sites did between: the icons as the letters of
   a font, since a browser already drew fonts' curves at any size. One
   colour only, and a private letter read aloud by a screen reader;
   SVG replaced it.

   modern:
   A real browser does not make an SVG a picture and then scale it, as
   [render] does once at the size asked: its shapes are painted with
   the page, by the library that paints everything (Chrome's Skia),
   each time and at the zoom of the moment, and so stay sharp; they
   are in the DOM, and move when a script or a style changes them.
   Here an inline <svg> is drawn again only when the page is laid out
   again (and mini-netscape has no zoom to show its pixels).

   References: W3C, Scalable Vector Graphics (SVG) 1.1 (Second
   Edition, 2011), chapters 7 (coordinate systems), 8 (paths), 9
   (basic shapes), 11 (painting), appendix F.6 (arcs); T. Porter and
   T. Duff, "Compositing Digital Images", SIGGRAPH '84; Adobe,
   PostScript Language Reference Manual (the red book), for the
   model. *)
(* ix: the author's playground's libs/graphics/images/svg/Svg.mli; render's colour is said, in render_in, where it was optional (docs/plans/plan_browser.md) *)

type node = { name : string; attributes : (string * string) list; children : node list }

(* the <svg> element of an SVG file's text, if it has one *)
val parse : string -> node option

(* whether bytes look like an SVG file: "<svg" or "<?xml ... <svg" first *)
val sniff : string -> bool

(* its size in pixels: width= and height=, one of them and the viewBox's
 * ratio, or the viewBox's; None if it says none *)
val size : node -> (float * float) option

(* [render node ~width ~height]: the picture, currentColor being black *)
val render : node -> width:int -> height:int -> Rgba_image.t

(* the same, currentColor being this one (ix: it was render's optional
 * ?color) *)
val render_in : int * int * int -> node -> width:int -> height:int -> Rgba_image.t
