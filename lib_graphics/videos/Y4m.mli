(* Y4M (YUV4MPEG2) is raw video, and nothing else.

   It is the format in which video tools hand each other uncompressed
   frames (mjpegtools, 2001; ffmpeg, x264 and most encoders read and
   write it). A file is a line of text that says what the frames are,
   then each frame as a line "FRAME" and its three planes of bytes
   (Yuv.mli). There is no compression, no index, and nothing to decode
   but the color:

     YUV4MPEG2 W320 H240 F25:1 Ip A1:1 C420jpeg XCOLORRANGE=LIMITED\n
     FRAME\n  320 x 240 bytes of Y, 160 x 120 of Cb, 160 x 120 of Cr
     FRAME\n  ...

   The header's fields are a letter and a value each, separated by
   spaces:
   - W and H are the size;
   - F is the frame rate as a fraction (25:1, and NTSC's 30000:1001,
     29.97 a second);
   - I is the interlacing (p is progressive, the only one read here);
   - A is the pixels' aspect;
   - C is the color sampling: 420jpeg, 420paldv and 420mpeg2 (4:2:0
     whose color samples sit in slightly different places, all read
     here as the same), and 444;
   - X is anything else, as XCOLORRANGE=FULL or LIMITED (Yuv.mli's
     ranges; limited, video's own, when it isn't said).
   A frame line can carry fields too; they are skipped.

   **How big video is**: at 320 x 240 in 4:2:0, a frame is 115,200
   bytes (76,800 of Y, and 19,200 of each color), and at 25 frames a
   second, that is 2.9 MB a second. A minute of 640 x 480 at 30 frames
   a second is 830 MB, which is half of RGB's 1.6 GB, from the 4:2:0
   alone. Every other format here is a way of not storing all that.

   Since every frame has the same size, a movie read from Y4M goes to
   any frame at once (its bytes are at a known place), unlike the
   formats whose frames are differences (Movie.mli). *)

type header = {
  width : int;
  height : int;
  rate : int * int; (* frames a second, as num:den *)
  chroma : Yuv.chroma;
  range : Yuv.range;
}

(* [frame_bytes h] is the size of a frame's planes, without the
 * "FRAME\n" line *)
val frame_bytes : header -> int

(* [of_string s] gives the header and the frames, decoded when they are
 * shown. It raises Failure if [s] isn't a Y4M file, or is one of a kind
 * not read here (interlaced, 4:2:2, gray). *)
val of_string : string -> header * Movie.t

(* [to_string ~chroma ~range ~rate frames] is a Y4M file of these
 * pictures (all of the same size), with that subsampling, that range
 * and that frame rate *)
val to_string : chroma:Yuv.chroma -> range:Yuv.range -> rate:int * int -> Rgba_image.t list -> string
