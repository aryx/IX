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

   It is the layout of Blit.image (graphics/core/) and Texture.image
   (graphics/3d/), and what an OpenGL texture upload wants as it is
   (as a Bigarray, not Bytes, for that). See notes_images.md, section 1.

   Here is where it stands in ix: it is the one type between a
   picture's file and whoever shows it. Png, Jpeg, Gif and Svg give one
   (Image_file chooses between the first two by the file's first
   bytes, and the browser chooses among the four), a PDF page drawn is
   one (Pdf_canvas.to_image), and Png.encode writes one. Those who show
   it are Blit, on a Framebuffer; mini-page; mini-office's pictures;
   and the browser (Browser_picture). It is not a Framebuffer, whose
   four bytes are in the screen's order, blue first, with no alpha: a
   picture is laid on the screen, not copied to it.

   It is not for a picture made again at every frame. mini-doom and
   mini-quake gave one at each frame (a Playground Bitmap), made from
   their 320 by 200 bytes of a palette, with each pixel n by n. On the
   Pi 2 this took 30% of a frame, and the draw platform then converted
   it again to the screen's format. They now give their bytes and
   palette as they are (Playground.Pixels: a byte for each pixel, a
   quarter of the memory), and each platform turns them, once, into
   what its device wants
   (docs/plans/done/plan_playground_framebuffer.md, F2).

   terminology:
   Straight and premultiplied alpha. Here a half-opaque white is FF FF
   FF 80: the colour, and apart from it, how much of the pixel the
   colour covers. Premultiplied, it is 80 80 80 80: the colour is
   already multiplied by its alpha, which is the form Porter and Duff
   argue for (1984) and the one the draw device uses. Laying a
   premultiplied pixel on another takes one multiplication less for
   each channel, and the average of two pixels (in a picture scaled
   down) is right. Straight pixels, when averaged, take colour from the
   transparent ones, which gives the dark or white fringe around a
   sprite. Straight is what PNG stores and what is simplest to say, so
   it is what the files' readers give; whoever needs the other form
   multiplies. *)
(* ix: the author's playground's libs/graphics/images/rgba/Rgba_image.mli (docs/plans/done/plan_playground.md) *)

(* ix: the bytes are a Bytes, not a Bigarray (mini-ml has no Bigarray) *)
type t = { width : int; height : int; rgba : Bytes.t }

val create : width:int -> height:int -> t
