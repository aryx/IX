(* externals naming .NET members (decision 7): static and instance
 * methods, .NET's int32 and char converted to ML's int and char, a
 * bool, a unit result *)

external length : string -> int = "dotnet:instance System.String::get_Length() -> int32"
external sub : string -> int -> int -> string
  = "dotnet:instance System.String::Substring(int32,int32)"
external upper : string -> string = "dotnet:instance System.String::ToUpper"
external index : string -> char -> int
  = "dotnet:instance System.String::IndexOf(char) -> int32"
external get : string -> int -> char
  = "dotnet:instance System.String::get_Chars(int32) -> char"
external contains : string -> string -> bool
  = "dotnet:instance System.String::Contains"
external concat : string -> string -> string
  = "dotnet:static System.String::Concat"
external print_line : string -> unit = "dotnet:static System.Console::WriteLine"

let s = "hello, world"

let () =
  print_int (length s); print_newline ();
  print_string (sub s 7 5); print_newline ();
  print_string (upper s); print_newline ();
  print_int (index s 'w'); print_newline ();
  print_char (get s 4); print_newline ();
  print_string (if contains s "lo, w" then "yes" else "no"); print_newline ();
  print_line (concat "a " (concat "b " "c"));
  let n = length s + 1000000000000 in
  print_int n; print_newline ()
