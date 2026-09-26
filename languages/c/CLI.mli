(* mini-cc [-m 5|7] [-simple [-dir] [-O|-Opass]] [-S] [-x] [-o out] [-Idir] [-Dname[=value]] file.c
 * -m the machine (5, arm, the default; 7, arm64), -S the listing on
 * stdout, -x each function's trees on stdout too; the object in mini-asm's
 * format, for mini-ld, to out or x.5 (x.7) in the current directory,
 * as 5c. 5c's other flags are ignored. -simple: the back end whose
 * contract is the behavior, not 5c's listing (the compat back end);
 * -dir prints its stack machine's code, function by function; -O runs
 * all of Opti's passes on it, -Oincs, -Oplaces... one each. *)

type caps =
    < open_in : string -> Cap.FS_.open_in;
      open_out : string -> Cap.FS_.open_out; stderr : Cap.Console_.stderr;
      stdout : Cap.Console_.stdout >

val main :
  < open_in : string -> Cap.FS_.open_in;
    open_out : string -> Cap.FS_.open_out; stderr : Cap.Console_.stderr;
    stdout : Cap.Console_.stdout; .. > ->
  string array -> int
