val toks : (TinyMLLexer.token * int) array ref
val pos : int ref
val peek : unit -> TinyMLLexer.token

val advance : unit -> unit
val fail : unit -> 'a
val expect : TinyMLLexer.token -> unit
val forgotten : string list ref
val abbreviations : (string * (string list * TinyMLTree.texpr)) list ref
val abbreviation : string -> TinyMLTree.ty list -> TinyMLTree.ty option



val ty : unit -> TinyMLTree.texpr
val items : unit -> (TinyMLTree.item * int) list
