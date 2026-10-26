type piece = Text of string | Hole of char * bool * bool * int
val printf_call : string -> TinyMLTree.expr list -> TinyMLTree.expr
