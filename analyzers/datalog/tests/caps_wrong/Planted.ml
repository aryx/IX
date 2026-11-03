(* Programs OCaml refuses, mini-ml takes (its objects are one type): each error
 * planted for capabilities_types.dl to find, and what looks like one. *)
let g (caps : < Cap.stdout; .. >) s = Console.print caps s
let opens (caps : < Cap.open_in; Cap.stderr; .. >) f = FS.read caps f

(* fine: as much, more, by an alias, a group, a closure *)
type mine = < Cap.stdout; Cap.exit >
let same (caps : < Cap.stdout; .. >) = g caps "a"
let more (caps : < Cap.stdout; Cap.exit; .. >) = g caps "b"
let alias (caps : mine) = g caps "c"
let group (caps : < Cap.console; .. >) = g caps "d"
let in_closure (caps : < Cap.stdout; .. >) = fun () -> g caps "e"
let renamed (caps : < Cap.stdout; .. >) = let c = caps in g c "f"

(* OCaml: this expression has type ..., it has no method stdout *)
let lacks (caps : < Cap.exit; .. >) = g caps "h"
let lacks_closure (caps : < Cap.stderr; .. >) = fun () -> g caps "i"
let lacks_one (caps : < Cap.open_in; .. >) f = opens caps f
let lacks_renamed (caps : < Cap.exit; .. >) = let c = caps in g c "j"

(* unseen *)
type r = { rcaps : < Cap.stdout; .. > }
let by_field t = g t.rcaps "k"
let no_type caps = g caps "l"
let asks_nothing (caps : < .. >) s = Console.print caps s
let to_nothing (caps : < Cap.exit; .. >) = asks_nothing caps "m"

let () =
  Cap.main (fun caps ->
    same caps; more caps; alias caps; group caps; in_closure caps (); renamed caps;
    lacks caps; lacks_closure caps (); ignore (lacks_one caps (Fpath.v "n")); lacks_renamed caps;
    by_field { rcaps = caps }; no_type caps; to_nothing caps)
