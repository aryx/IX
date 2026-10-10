(* A value written down, and read back: OCaml's own Marshal, behind a
 * line saying what it is (plan_io.md).
 *
 * Marshal writes any value that is data -- a sheet, a text and its
 * looks, a bitmap, a drawing -- keeping what is shared shared, and
 * reads it back as it was. So an application needs no file format of
 * its own. Three things it will not do, which are why this module is
 * more than two calls:
 *
 * - **It believes the type it is told.** [Marshal.from_string] returns
 *   whatever type the caller expects; a file written by a program whose
 *   types have changed since is read as garbage, and can crash it. So
 *   the text starts with a line naming the kind of document and its
 *   version -- ["drawing 1"] -- checked before anything is unmarshalled,
 *   which turns that crash into "not a file I can read". (A version is
 *   only as good as whoever changes it when the type changes.)
 * - **It cannot write functions** in a way another program can read
 *   (and js_of_ocaml not at all): a TinyOpenDoc part, being a record of
 *   functions, saves its data, never itself.
 * - **It does not check that the data is all there.** Marshal's header
 *   says how long the data is, so a truncated file is refused here
 *   before it is read.
 *
 *   drawing 1\n<Marshal's bytes>
 *
 * Where it stands. File_menu writes a document so, with the line the
 * application gives it (mini-office's is "TinyOffice 1", in Document)
 * and hands the bytes to the platforms' Store; Part_drawing saves a
 * drawing so inside a document, the example above. The other parts
 * each write a form of their own (a sheet a cell a line, as text; a
 * picture its rows packed), which is the other choice, and the
 * comparison is in one file: a saved mini-office document is
 * Marshal's bytes holding, for each part, a string in that part's
 * own form.
 *
 * terminology:
 * The first line is a magic number, Unix's name for the first bytes
 * of a file when they say what the file is: the kernel reads them to
 * choose how to run a program (the two characters of a script's
 * first line among them), and file(1) is a table of them. Here they
 * are a line of text, so that a person looking at the file sees what
 * it is too. Image_file tells a PNG from a JPEG the same way, by the
 * bytes and not by the name.
 *
 * others:
 * A file that is the program's memory written down is the oldest
 * format there is, and the one a format designed on purpose is
 * measured against. Word's and Excel's binary files of the 1990s
 * were close to it: their own structures, laid out to be read and
 * written fast on a slow machine, which is why they were so hard for
 * anyone else to read, and why each version of the programs had its
 * own. What replaced them is the opposite on every count: a zip of
 * XML files, one a part (OpenDocument, 2005; Office Open XML, 2006),
 * slower and larger, and readable by a program its authors never
 * saw. This module is on the old side, knowingly: what it buys is
 * that there is nothing to write when a type gains a field, but the
 * number in the line.
 *
 * design:
 * Never unmarshal what you did not write. The line and the length
 * turn an honest mistake into a refusal; they are no defence against
 * a file made to deceive, since after them the bytes are believed.
 * It is the same warning Python gives for pickle and Java for its
 * serialization, and the reason formats meant to travel are parsed
 * and not loaded. A document here is the user's own, from the Store.
 *
 * References: OCaml's manual, the Marshal module, which says the
 * first two limits itself. Joel Spolsky, "Why are the Microsoft
 * Office file formats so complicated?" (2008), for the binary
 * formats' reasons. The playground's plan_io.md.
 *)

(* [to_string ~magic value]: the line, then the value *)
val to_string : magic:string -> 'a -> string

(* [of_string ~magic text]: the value, if [text] starts with [magic]'s
 * line and all of the data follows it; the caller says its type,
 * which the line is the only check of *)
val of_string : magic:string -> string -> 'a option
