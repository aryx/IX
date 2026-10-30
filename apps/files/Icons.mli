(* Icons: a picture for each kind of file, drawn of plain shapes, 16 pixels
   square.

       text/plain --of_kind--> Text --draw--> a page with lines on it

   cs-history:
   The icon is David Canfield Smith's word (his thesis, Pygmalion, 1975), and
   the Xerox Star's picture (1981): a document looks like a sheet, a folder
   like a folder. Susan Kare drew the Macintosh's in 1983, on graph paper,
   32 by 32 and one bit deep, and those are what people mean by the word.
   They worked because a picture is recognised before a name is read. *)

type look = Folder | Text | Web | Picture | Sound | Film | Book | Program | Archive | Other

(* what a content type looks like (File_kind's strings) *)
val of_kind : string -> look

(* centred on the origin, to be moved *)
val draw : look -> Playground.shape
