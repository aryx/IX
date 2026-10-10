(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dns.mli *)

let server (caps : < Cap.open_in; .. >) : string =
  let words l = List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) l)) in
  let lines = match FS.read caps (Fpath.v "/etc/resolv.conf") with s -> String.split_on_char '\n' s | exception Sys_error _ -> [] in
  match List.find_map (fun l -> match words l with [ "nameserver"; a ] when not (String.contains a ':') -> Some a | _ -> None) lines with
  | Some a -> a
  | None -> "127.0.0.1"

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

let answers ~(id : int) (s : string) : Unix.inet_addr list =
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
          found := Unix.inet_addr_of_string (String.concat "." (List.init 4 (fun k -> string_of_int (Char.code s.[i + 10 + k])))) :: !found;
        pos := i + 10 + len
      done;
      List.rev !found
    end
  with Invalid_argument _ | Failure _ -> [] (* a packet shorter than it says *)

let resolve (caps : < Cap.network; Cap.open_in; .. >) (name : string) : Unix.inet_addr list =
  let ns = server caps in
  let id = int_of_float (Unix.gettimeofday () *. 1000.) land 0xffff in
  let ask () =
    let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
      Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_of_string ns, 53));
      let q = question ~id name in
      ignore (Unix.write_substring fd q 0 (String.length q));
      match Unix.select [ fd ] [] [] 2.0 with
      | [], _, _ -> None
      | _ ->
          let b = Bytes.create 1500 in
          let n = Unix.read fd b 0 1500 in
          Some (answers ~id (Bytes.sub_string b 0 n)))
  in
  let rec go (left : int) = if left = 0 then [] else match ask () with Some l -> l | None -> go (left - 1) | exception Unix.Unix_error _ -> go (left - 1) in
  go 3
