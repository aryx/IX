(* A decoded picture: what the image readers of graphics/images/ give,
 * whatever the file's format (PNG, GIF, JPEG, ...) and whatever its
 * pixels were there (a palette, gray, RGB), and what the backends draw
 * from.

   width x height pixels, row by row from the top, 4 bytes per pixel,
   red, green, blue, alpha (0 = transparent, 255 = opaque; straight,
   not premultiplied), no padding between rows:

     width = 3                 rgba (row 0, then row 1):
     +-----+-----+-----+       FF 00 00 FF  00 FF 00 FF  00 00 FF FF
     | red |green|blue |       00 00 00 00  FF FF FF FF  FF FF FF 80
     +-----+-----+-----+       ^ transparent             ^ half-opaque white
     |     |white|white|
     +-----+-----+-----+

   The layout of Blit.image (graphics/core/) and Texture.image
   (graphics/3d/), and what an OpenGL texture upload wants as is (a
   Bigarray, not Bytes, for that). See notes_images.md, section 1.

   Where it stands in ix: the one type between a picture's file and
   whoever shows it. Png, Jpeg, Gif and Svg give one (Image_file
   chooses between the first two by the file's first bytes, the
   browser among the four), a PDF page drawn is one
   (Pdf_canvas.to_image), and Png.encode writes one. Those who
   show it: Blit, on a Framebuffer; mini-page; mini-office's
   pictures; the browser (Browser_picture). It is not a Framebuffer,
   whose four bytes are in the screen's order, blue first, with no
   alpha: a picture is laid on the screen, not copied to it.

   terminology:
   Straight and premultiplied alpha. Here a half-opaque white is FF FF
   FF 80: the colour, and apart from it how much of the pixel it
   covers. Premultiplied, it is 80 80 80 80: the colour already
   multiplied by its alpha, the form Porter and Duff argue for (1984)
   and the draw device's. Laying a premultiplied pixel on another is
   one multiplication less a channel, and the average of two pixels
   (a picture scaled down) is right, where straight pixels averaged
   take colour from the transparent ones: the dark or white fringe
   round a sprite. Straight is what PNG stores and what is simplest
   to say, so it is what the files' readers give; who needs the other
   multiplies. *)
(* ix: the author's playground's libs/graphics/images/rgba/Rgba_image.mli (docs/plans/plan_playground.md) *)

(* ix: the bytes a Bytes, not a Bigarray (mini-ml has none) *)
type t = { width : int; height : int; rgba : Bytes.t }

val create : width:int -> height:int -> t
