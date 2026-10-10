(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-basename: Plan 9's basename (principia's utilities/misc/basename.c):
 * a name's last part, what follows its last /, without a suffix when
 * one is given and it ends with it; -d: what is before that /, its
 * directory ("." when it has none). For a script. *)

type caps = < Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let dir, args = match List.tl (Array.to_list argv) with "-d" :: rest -> true, rest | args -> false, args in
  match args with
  | name :: ([] | [ _ ] as suffix) ->
      let slash = String.rindex_opt name '/' in
      let said =
        if dir then (match slash with Some k -> String.sub name 0 k | None -> ".")
        else begin
          let last = match slash with Some k -> String.sub name (k + 1) (String.length name - k - 1) | None -> name in
          match suffix with
          | [ s ] when String.ends_with ~suffix:s last -> String.sub last 0 (String.length last - String.length s)
          | _ -> last
        end in
      Console.print caps (said ^ "\n"); Exit.OK
  | _ -> Console.eprint caps "usage: basename [-d] string [suffix]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
