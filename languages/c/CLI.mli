(* mini-cc's command line: [help] in CLI.ml, what mini-cc -h prints *)

type caps =
    < open_in : string -> Cap.FS_.open_in;
      open_out : string -> Cap.FS_.open_out; stderr : Cap.Console_.stderr;
      stdout : Cap.Console_.stdout >

val main :
  < open_in : string -> Cap.FS_.open_in;
    open_out : string -> Cap.FS_.open_out; stderr : Cap.Console_.stderr;
    stdout : Cap.Console_.stdout; .. > ->
  string array -> int
