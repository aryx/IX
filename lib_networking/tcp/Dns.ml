(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dns.mli *)

let server (caps : < Cap.open_in; .. >) : string =
  let words l = List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) l)) in
  let lines (file : string) = match FS.read caps (Fpath.v file) with s -> String.split_on_char '\n' s | exception Sys_error _ -> [] in
  let starts (p : string) (w : string) = String.length w > String.length p && String.sub w 0 (String.length p) = p in
  match List.find_map (fun l -> match words l with [ "nameserver"; a ] when not (String.contains a ':') -> Some a | _ -> None) (lines "/etc/resolv.conf") with
  | Some a -> a
  | None -> (
      (* Plan 9's: what ipconfig was told, "dns=10.0.2.3" among /net/ndb's words *)
      match List.find_opt (starts "dns=") (List.concat_map words (lines "/net/ndb")) with
      | Some w -> String.sub w 4 (String.length w - 4)
      (* a /net and no server said: none to ask ("": resolve gives []) *)
      | None -> if Sys.file_exists "/net/ndb" then "" else "127.0.0.1")

let u16 (n : int) : string = String.init 2 (fun i -> Char.chr ((n lsr (8 * (1 - i))) land 0xff))
let get16 (s : string) (i : int) : int = (Char.code s.[i] lsl 8) lor Char.code s.[i + 1]

let question ~(id : int) (name : string) : string =
  let labels = List.filter (fun l -> l <> "") (String.split_on_char '.' name) in
  (* recursion desired; one question, of type A and class IN *)
  u16 id ^ u16 0x0100 ^ u16 1 ^ u16 0 ^ u16 0 ^ u16 0
  ^ String.concat "" (List.map (fun l -> String.make 1 (Char.chr (String.length l)) ^ l) labels)
  ^ "\000" ^ u16 1 ^ u16 1

(* past the name at i: its labels, or the pointer that ends it *)
let rec skip_name (s : string) (i : int) : int =
  let n = Char.code s.[i] in
  if n = 0 then i + 1 else if n land 0xc0 = 0xc0 then i + 2 else skip_name s (i + 1 + n)

let answers ~(id : int) (s : string) : string list =
  try
    if String.length s < 12 || get16 s 0 <> id || get16 s 2 land 0x800f <> 0x8000 then []
    else begin
      let pos = ref 12 in
      for _i = 1 to get16 s 4 do pos := skip_name s !pos + 4 done;
      let found = ref [] in
      for _i = 1 to get16 s 6 do
        let i = skip_name s !pos in
        let typ = get16 s i and len = get16 s (i + 8) in
        if typ = 1 && len = 4 then
          found := String.concat "." (List.init 4 (fun k -> string_of_int (Char.code s.[i + 10 + k]))) :: !found;
        pos := i + 10 + len
      done;
      List.rev !found
    end
  with Invalid_argument _ | Failure _ -> [] (* a packet shorter than it says *)

let resolve (caps : < Cap.network; Cap.open_in; .. >) (name : string) : string list =
  let ns = server caps in
  let id = int_of_float (Unix.gettimeofday () *. 1000.) land 0xffff in
  (* old: a socket here (SOCK_DGRAM, connect, write, select, read): Udp's now, which Plan 9 has another of *)
  let ask () = Option.map (answers ~id) (Udp.ask caps ~address:ns ~port:53 (question ~id name) 2.0) in
  let rec go (left : int) = if left = 0 || ns = "" then [] else match ask () with Some l -> l | None -> go (left - 1) | exception Unix.Unix_error _ -> go (left - 1) in
  go 3
