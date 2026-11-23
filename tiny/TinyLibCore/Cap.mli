(* Cap: the name alone of lib_core/system/'s module (see Stdlib.mli).
 * TinyLibSystem.mli takes capabilities, < Cap.stdout; .. >, which OCaml
 * checks on the host; tiny-ml leaves types out, so no unit is made of
 * it here (not in the Buildfile's CORE). It is for a reader that
 * resolves the names in types on this library, mini-analyze -L. *)
type all_caps = < >
