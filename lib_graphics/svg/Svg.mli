(* Svg turns a picture made of shapes into pixels. It reads the small
   part of SVG that logos and icons use.

   A PNG is pixels. An SVG (Scalable Vector Graphics, W3C, 2001) is a
   drawing's description, in XML: shapes filled and stroked, in a
   coordinate system of its own that its viewBox maps onto any size.
   The web's logos and icons are SVG now (Hacker News' "Y" and its vote
   arrows, Wikipedia's wordmark, GitHub's icons, Google's "G"), because
   one file is sharp at every size.

     <svg viewBox="0 0 24 24" width="48" height="48">
       <path d="M4 12 L12 4 L20 12 Z" fill="#f60"/>
     </svg>

   This is a triangle, drawn in a square of 24 units and shown on 48
   pixels, so every number is doubled on its way to the screen.

   A page has SVG pictures in four ways, and all four come here:

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

   There are three stages, and each is a part of Svg.ml:

     text --[parse]--> nodes --shapes--> contours --painting--> Rgba_image
                                 |                    |
                         Affine, Curve.flatten   Stroke.contours,
                                                 Fill.polygons_aa

   **Reading** ([parse]) reads XML as far as SVG files need it
   (elements and their attributes, and <x/>; comments, <?xml ...?>,
   <!DOCTYPE>, CDATA and text are skipped) into a tree of [node]s. A
   browser gives its inline <svg> elements from its own DOM, as the
   same nodes.

   **The shapes**: each is made a list of polygons (its contours) in
   the picture's pixels. They are:

     rect (x y width height), circle (cx cy r), ellipse (cx cy rx ry),
     line, polyline, polygon (points), and path (d) with its commands,
     absolute and relative (lower case): M L H V (lines), C S (cubic
     Bézier curves, S's first control point the mirror of the last),
     Q T (quadratic ones), A (elliptical arcs: SVG's endpoint form
     converted to a centre and angles, appendix F.6), Z (closed).

   The curves are flattened into lines (by Curve.flatten, a tenth of a
   pixel off at most), and the points go through the transforms of the
   elements around them (transform: translate, scale, rotate, matrix;
   composed as Affine) and through the viewBox's transform (scaled
   uniformly and centred, SVG's default preserveAspectRatio "xMidYMid
   meet").

   The path is the format's heart, and a language of its own, made to
   be short: a letter, then numbers. The letter is left out when it
   repeats, and the separators are left out where a sign or a point
   can do (M4 12l8-8 8 8z is the triangle above). An icon set's file
   is mostly these strings, written by a drawing program and by
   nobody's hand.

   **Painting** reads:
   - fill, with its rule (nonzero, evenodd). It is black by default,
     or none, or a colour: #rgb, #rrggbb, rgb(), a few names, or
     currentColor, which is the caller's colour;
   - stroke (none by default), of stroke-width;
   - the opacities (opacity, fill-opacity, stroke-opacity).
   They are given as attributes or as style="fill: ...", and are
   inherited down the tree as CSS properties are. Fill.polygons_aa
   fills a shape (its stroke goes through Stroke.contours first) into
   a framebuffer that has no alpha. So each shape's coverage is drawn
   white on black, then laid onto the picture in the shape's colour, at
   that coverage times its opacity: Porter and Duff's "over".

   The two rules say what is inside a path that crosses itself or has
   several contours (Fill.mli draws them). With evenodd, a point is
   inside if a ray from it crosses the contours an odd number of times,
   so a ring is two circles, whichever way they turn. With nonzero,
   each crossing counts +1 or -1 by the contour's direction, and inside
   is where the sum is not 0, so the ring's inner circle must turn the
   other way. A letter O, a doughnut, and GitHub's cat in its circle
   have holes made this way.

   A worked example (from the tests): in a 4 by 4 picture, <rect x=1
   y=1 width=2 height=2 fill=red/> makes the 4 middle pixels opaque
   red, and the rest transparent.

   What is not done: gradients and patterns (fill="url(#...)" is drawn
   grey), text, <use> and <symbol>, clipping, masks, filters, markers,
   dashes, CSS <style> sheets inside the SVG, stroke joins other than
   round, and animation.

   Where it stands in ix: it is the third reader of the same picture of
   the world, after Pdf_render (PDF's operators m, l, c, h, f, S under
   cm) and before the playground's own shapes. All three end as
   contours given to Fill, through Affine and Curve. Its XML is read
   here, in some sixty lines, and not by the browser's HTML parser,
   which a picture's file must not need.

   cs-history:
   Where it came from. Its picture of the world is PostScript's
   (Warnock and Geschke, Adobe, 1984): a path is built by moving,
   drawing lines and curves, and closing; then it is filled, by one of
   the two rules, or stroked with a pen of some width; all of it is
   under a current transform. PostScript said moveto, lineto, curveto,
   closepath; SVG says M, L, C, Z. PDF (1993) is the same model without
   the programming language, and the curves are those Pierre Bezier at
   Renault and Paul de Casteljau at Citroen drew car bodies with around
   1960 (Curve.mli).

   cs-history:
   In 1998 the W3C was sent two proposals, within weeks, to put that
   model in a page as XML. PGML, the Precision Graphics Markup Language
   (Adobe, IBM, Netscape, Sun), was PostScript's model spelt in tags.
   VML, the Vector Markup Language (Microsoft, Macromedia and others),
   was shipped by Internet Explorer 5. The working group took neither
   and made a third from both: SVG 1.0, a Recommendation in September
   2001, then SVG 1.1 in 2003, which is still what files are written
   in.

   cs-history:
   Then came ten years of waiting. A browser showed SVG through Adobe's
   plug-in, and vector drawings on the web were done in Flash
   (Macromedia's, then Adobe's own). Opera 8 and Firefox 1.5 drew SVG
   themselves in 2005, Safari followed, and Internet Explorer, which
   had VML, did so only in version 9, in 2011. Two things then made it
   the web's way to draw an icon within a few years. The first was
   telephones whose browsers had no Flash (the iPhone, 2007) and whose
   screens had two and three dots to a CSS pixel, where a PNG icon is
   either blurred or sent in three sizes. The second was HTML5's
   parser (Html_tree.mli), which let <svg> stand in a page with no
   namespace and no XML.

   others:
   <canvas> (Apple, 2004; then HTML5) is the other way a page draws. It
   has the same model again (moveTo, lineTo, bezierCurveTo, fill,
   stroke), but as calls of a script that leave only pixels. SVG keeps
   the drawing: its shapes are elements of the document, which a
   selector can find, a sheet can style, and a listener can be given
   to. This is retained mode against immediate mode, the old pair of
   computer graphics; a chart of ten thousand points wants the second,
   and an icon or a diagram the first.

   others:
   An icon font is what sites used in between: the icons are the
   letters of a font, since a browser already drew fonts' curves at any
   size. It has one colour only, and a screen reader reads its private
   letters aloud; SVG replaced it.

   modern:
   A real browser does not make an SVG a picture and then scale it, as
   [render] does, once, at the size asked. Its shapes are painted with
   the page, by the library that paints everything (Chrome's Skia),
   each time and at the zoom of the moment, and so they stay sharp.
   They are in the DOM, and they move when a script or a style changes
   them. Here an inline <svg> is drawn again only when the page is laid
   out again (and mini-netscape has no zoom that would show its
   pixels).

   References: W3C, Scalable Vector Graphics (SVG) 1.1 (Second
   Edition, 2011), chapters 7 (coordinate systems), 8 (paths), 9
   (basic shapes), 11 (painting), appendix F.6 (arcs); T. Porter and
   T. Duff, "Compositing Digital Images", SIGGRAPH '84; Adobe,
   PostScript Language Reference Manual (the red book), for the
   model. *)
(* ix: copied from libs/graphics/images/svg/Svg.mli in the author's
 * playground (docs/plans/plan_browser.md). The colour of render must
 * be given, in render_in, where it was optional. *)

type node = { name : string; attributes : (string * string) list; children : node list }

(* the <svg> element of an SVG file's text, if it has one *)
val parse : string -> node option

(* whether bytes look like an SVG file: they start with "<svg" or with
 * "<?xml ... <svg" *)
val sniff : string -> bool

(* its size in pixels: from width= and height=, from one of them and
 * the viewBox's ratio, or from the viewBox; None if it gives none *)
val size : node -> (float * float) option

(* [render node ~width ~height] is the picture, with currentColor
 * black *)
val render : node -> width:int -> height:int -> Rgba_image.t

(* the same, with currentColor being this colour (ix: it was the
 * optional ?color of render) *)
val render_in : int * int * int -> node -> width:int -> height:int -> Rgba_image.t
