(* File_kind: what a file is, by its first bytes, then by its name; the
   answer a content type (image/png), as a mail's part or a web server's
   answer says it, so one table of programs (Helpers) serves them all.

   A name can lie (a PNG saved as .wav) or say nothing (a file from a
   URL), so the bytes come first: nearly every format begins with a
   **magic number**, a few bytes chosen to be unlikely anywhere else:

       "RIFF" .... "WAVE"        WAV (RIFF, Microsoft and IBM, 1991)
       "RIFF" .... "AVI "        AVI (Video for Windows, 1992): WAV's
                                 container, another type
       "MThd"                    a Standard MIDI File (1988)
       "OggS"                    an Ogg stream (Xiph, 2003)
       "M.K." at byte 1080       a MOD (1987; and the other tags)
       89 "PNG" 0D 0A 1A 0A      PNG (1996): a high byte, then a DOS and a
                                 Unix newline and a DOS end-of-file, so a
                                 transfer that mangles either shows
       "GIF87a", "GIF89a"        GIF (1987, 1989)
       FF D8 FF                  JPEG (a start-of-image marker, then the next)
       "/* XPM */"               XPM (a C comment: the file is C source)
       "YUV4MPEG2 "              Y4M, raw video (mjpegtools, 2001)
       00 00 01 B3, 00 00 01 BA  MPEG-1 (1993): the start code of a video
                                 stream's sequence, of an .mpg's pack
       11 AF, 12 AF at byte 4    FLI, FLC (Autodesk Animator, 1989): two
                                 bytes only, a weak magic, trusted only in
                                 a file of the header's 128 bytes
       "%PDF-"                   PDF (1993)
       "TinyOffice 1\n"          a document of mini-office's
       1F 8B                     gzip (1992)
       "ustar" at byte 257       tar, POSIX's (1988)
       7F "ELF", 00 00 06 47,    an executable: Linux's, Plan 9's a.out for
       00 00 8C 47               arm and arm64 (4*b*b+7, Exe)
       "#!"                      a script (Dennis Ritchie, 1980)
       "<!doctype html", "<html" HTML, after blanks and in either case
       "BEGIN:VCALENDAR"         iCalendar (1998)
       "BEGIN:VCARD"             vCard (1995)
       "X:"                      an ABC tune (its first field, the number)
       "ID3", FF Ex or Fx        MPEG audio, MP2 and MP3 (1993): a music
                                 player's tag, or 11 bits of sync

   then the name: Ultimate Soundtracker's modules have no tag (.mod), an
   HTML file need not begin with its tag; then what the bytes look like:
   text, or nothing known (application/octet-stream).

   cs-history:
   file(1) came with Research Unix's V4 (1973), and looked at a file's
   first bytes for the few kinds Unix had. Ian Darwin's rewrite of 1987
   made the rules a table, /etc/magic, which every Unix's file(1) still
   reads. The Macintosh (1984) went the other way, a type of four letters
   and the program that made it kept beside the file, in its resource
   fork; Windows took the name's end from CP/M. Both lose the answer in
   transit, which is why a web server has to say a content type: MIME's
   (Borenstein and Freed, 1992). The browsers then learned to distrust
   that too and sniff, against a table of bytes much like this one. *)

(* the content type its bytes say; None if they say nothing *)
val of_bytes : string -> string option

(* the content type its name says, for what has no magic *)
val of_name : string -> string option

(* [of_file ~name bytes]: the bytes, the name, then text or
   application/octet-stream. [bytes] the file's first ones are enough
   (of_path's). *)
val of_file : name:string -> string -> string

(* the same, of a file on the disk; Sys_error if it cannot be read *)
val of_path : < Cap.open_in ; .. > -> Fpath.t -> string
