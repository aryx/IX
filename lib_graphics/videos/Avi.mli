(* Avi reads Microsoft's Audio Video Interleave, which is a container,
 * apart from the codec.

   A video file is two things that are easy to confuse. The **codec**
   is how one frame (or a stretch of sound) is compressed. The
   **container** is the file that holds the compressed frames and the
   sound; it says when each one plays, and it lets a player find frame
   1000 without reading the 999 before it. AVI (Video for Windows,
   1992) is the simplest famous container. It is a RIFF file, WAV's
   own container (Wav.mli), made of chunks (four letters, a size, and
   the bytes, padded to an even size) and lists of chunks:

     RIFF "AVI "
       LIST "hdrl"                     the headers
         avih                          the main header (56 bytes): the
                                       microseconds a frame, the frames,
                                       the streams, the size
         LIST "strl"                   a stream, here the video:
           strh                        its header: "vids", the codec
                                       ("MJPG"), the rate as rate/scale
                                       (25/1), the frames
           strf                        its format: a BITMAPINFOHEADER,
                                       with the size and the codec again
         LIST "strl"                   the sound:
           strh                        "auds", with rate/scale in blocks
           strf                        a WAVEFORMATEX, WAV's "fmt "
       LIST "movi"                     the data, **interleaved**, so that
         00dc  a frame of stream 0     a player reading in order has the
         01wb  its sound, stream 1     picture and its sound at once
         00dc ...                      (dc is compressed video, wb is
                                       wave bytes)
       idx1                            the index: each chunk's name,
                                       whether a player can start there
                                       (a key frame), where it is, and
                                       its size, for seeking without
                                       reading

   The codec here is **Motion JPEG**. Every frame is a JPEG of its own
   (Jpeg.mli, Jpeg_encode.mli), and no frame depends on another. This
   is what webcams, early digital cameras and video editors recorded.
   It is simple to cut anywhere, and much bigger than the formats that
   store differences (Fli.mli, and MPEG). Since every frame is a key
   frame, a movie read from it goes to any frame at once, like Y4M's.

   The sound is PCM, WAV's samples. A player plays the sound and shows
   the frame at the sound's position: the **audio clock** drives the
   picture (Film).

   What is read:
   - RIFF, walked for the headers and the "movi" list (its "rec " lists
     too). The chunks are found by walking, so the index, the shortcut
     that a player seeking in a big file wants, is not needed and is
     not read;
   - Motion JPEG video;
   - PCM sound, 8 or 16 bits, mono or stereo, mixed down to mono.
   Other codecs and compressed sound are refused. Motion JPEG from some
   cameras leaves out the Huffman tables (the standard's tables are
   meant), and it is not read here either. *)

type header = {
  width : int;
  height : int;
  rate : int * int; (* frames a second as rate/scale *)
  codec : string; (* the video's four letters *)
}

(* [of_string s] gives the header, the frames, decoded when they are
 * asked for, and the sound, if there is any: its rate and its samples,
 * in mono, from -1 to 1. The player resamples them, because
 * lib_graphics knows nothing of lib_audio. It raises Failure if [s] is
 * not an AVI, or is one with a codec not read here. *)
val of_string : string -> header * Movie.t * (int * float array) option
