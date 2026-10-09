(* mini-office's new documents, one of each kind, each holding a part
 * of another kind. *)

val styled : bold:bool -> float -> string -> Rich.t

val with_title : string -> string -> Rich.t

val budget : Sheet.t

val shapes : Drawing.t

val obj : slide:int -> link:Document.link option -> Component.part -> float -> float -> float -> float -> Document.obj

val fresh : Document.kind -> Document.doc
