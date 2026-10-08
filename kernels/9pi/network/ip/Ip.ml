(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Ip.mli *)

open Types
open Errors

(*****************************************************************************)
(* Addresses, bytes *)
(*****************************************************************************)

let noaddr = "\000\000\000\000"
let bcast = "\255\255\255\255"

let has s c = try ignore (String.index s c); true with Not_found -> false

let rec parse s =
  if s = "*" || s = "" then noaddr
  else if has s ':' then begin
    (* IPv6's notation (Plan 9's %I, %M of a v4 address or mask in its
     * IPv6 form): its last 32 bits, two hex groups or a dotted tail *)
    let groups = String.split_on_char ':' s in
    let last = List.nth groups (List.length groups - 1) in
    if has last '.' then parse last
    else begin
      let hx g = try int_of_string ("0x" ^ (if g = "" then "0" else g)) with Failure _ -> 0 in
      let g2 = hx (List.nth groups (List.length groups - 2)) and g1 = hx last in
      String.concat "" (List.map (fun v -> String.make 1 (Char.chr (v land 255))) [ g2 lsr 8; g2; g1 lsr 8; g1 ])
    end
  end
  else
    match List.map (fun w -> try int_of_string w with Failure _ -> 0) (String.split_on_char '.' s) with
    | [ a; b; c; d ] -> String.concat "" (List.map (fun v -> String.make 1 (Char.chr (v land 255))) [ a; b; c; d ])
    | _ -> noaddr

(* a mask: dotted, or a prefix's length (/120: Plan 9's %M of a v4 mask
 * in its IPv6 form, 96 bits more) *)
let parsemask s =
  if String.length s > 1 && s.[0] = '/' then begin
    let n = (try int_of_string (String.sub s 1 (String.length s - 1)) with Failure _ -> 0) in
    let n = if n >= 96 then n - 96 else n in
    String.concat "" (List.map (fun i -> let b = max 0 (min 8 (n - (8 * i))) in String.make 1 (Char.chr ((0xff lsl (8 - b)) land 0xff))) [ 0; 1; 2; 3 ])
  end else parse s

let show a = Printf.sprintf "%d.%d.%d.%d" (Char.code a.[0]) (Char.code a.[1]) (Char.code a.[2]) (Char.code a.[3])

let get16 s o = (Char.code s.[o] lsl 8) lor Char.code s.[o + 1]
let put16 v = String.make 1 (Char.chr ((v lsr 8) land 255)) ^ String.make 1 (Char.chr (v land 255))

let band a b = String.concat "" (List.map (fun i -> String.make 1 (Char.chr (Char.code a.[i] land Char.code b.[i]))) [ 0; 1; 2; 3 ])

(* the ones' complement sum of s's bytes [off, off+len), from init *)
let cksum s off len init =
  let sum = ref init in
  let i = ref off in
  while !i + 1 < off + len do sum := !sum + get16 s !i; i := !i + 2 done;
  if !i < off + len then sum := !sum + (Char.code s.[!i] lsl 8);
  while !sum lsr 16 <> 0 do sum := (!sum land 0xffff) + (!sum lsr 16) done;
  (lnot !sum) land 0xffff

(*****************************************************************************)
(* The interface *)
(*****************************************************************************)

type lifc = { local : string; mask : string }
type ifc = { mutable dev : string; mutable lifcs : lifc list; mutable mtu : int; mutable pktin : int; mutable pktout : int }

let ifc = { dev = ""; lifcs = []; mtu = 1514; pktin = 0; pktout = 0 }

let ours a = a = bcast || List.exists (fun l -> l.local = a) ifc.lifcs

let onnet a = List.exists (fun l -> band a l.mask = band l.local l.mask) ifc.lifcs

let source dst =
  match List.filter (fun l -> band dst l.mask = band l.local l.mask) ifc.lifcs with
  | l :: _ -> l.local
  | [] -> (match ifc.lifcs with l :: _ -> l.local | [] -> noaddr)

let routes = ref []

let add ip mask =
  ifc.lifcs <- ifc.lifcs @ [ { local = ip; mask = mask } ];
  routes := !routes @ [ (band ip mask, mask, noaddr) ]

let remove ip mask =
  ifc.lifcs <- List.filter (fun l -> not (l.local = ip && l.mask = mask)) ifc.lifcs;
  routes := List.filter (fun (d, m, _) -> not (d = band ip mask && m = mask)) !routes

(*****************************************************************************)
(* ARP *)
(*****************************************************************************)

let arptab = ref []
(* the packets waiting for their next hop's address *)
let pending = ref []

let arptext () =
  String.concat "" (List.map (fun (ip, mac) ->
    Printf.sprintf "ether OK %-40s %s\n" (show ip)
      (String.concat "" (List.map (fun i -> Printf.sprintf "%02x" (Char.code mac.[i])) [ 0; 1; 2; 3; 4; 5 ]))) !arptab)

let frame dst typ payload = dst ^ String.make 6 '\000' ^ put16 typ ^ payload

(* an ARP packet: op 1 a request, 2 a reply *)
let arp op tmac tip sip =
  let mac = Devether.mac () in
  put16 1 ^ put16 0x800 ^ "\006\004" ^ put16 op ^ mac ^ sip ^ tmac ^ tip

let arpinput f =
  if String.length f >= 42 then begin
    let p = String.sub f 14 28 in
    let op = get16 p 6 and smac = String.sub p 8 6 and sip = String.sub p 14 4 and tip = String.sub p 24 4 in
    arptab := (sip, smac) :: List.filter (fun (i, _) -> i <> sip) !arptab;
    if op = 1 && List.exists (fun l -> l.local = tip) ifc.lifcs then
      Devether.transmit (frame smac 0x806 (arp 2 smac sip tip));
    (* the packets for sip, out now *)
    let go, stay = List.partition (fun (hop, _) -> hop = sip) !pending in
    pending := stay;
    List.iter (fun (_, pkt) -> ifc.pktout <- ifc.pktout + 1; Devether.transmit (frame smac 0x800 pkt)) go
  end

(*****************************************************************************)
(* Routes, IP out and in *)
(*****************************************************************************)

let routetext () =
  String.concat "" (List.map (fun (d, m, g) ->
    Printf.sprintf "%-15s %-15s %-15s %4s %4s %3s\n" (show d) (show m) (show g) (if g = noaddr then "4i" else "4") "" "") !routes)

let nexthop dst =
  if dst = bcast || onnet dst then Some dst
  else match List.filter (fun (d, m, g) -> g <> noaddr && band dst m = d) !routes with
    | (_, _, g) :: _ -> Some g
    | [] -> None

let ipid = ref 1
let protos_in = ref []
let register n f = protos_in := (n, f) :: !protos_in

let rec send proto src dst payload =
  let len = 20 + String.length payload in
  incr ipid;
  let h = "\069\000" ^ put16 len ^ put16 (!ipid land 0xffff) ^ "\000\000\255" ^ String.make 1 (Char.chr proto) ^ "\000\000" ^ src ^ dst in
  let c = cksum h 0 20 0 in
  let pkt = String.sub h 0 10 ^ put16 c ^ String.sub h 12 8 ^ payload in
  if ours dst && dst <> bcast then input pkt
  else
    match nexthop dst with
    | None -> ()
    | Some hop ->
        if hop = bcast then begin ifc.pktout <- ifc.pktout + 1; Devether.transmit (frame (String.make 6 '\255') 0x800 pkt) end
        else begin
          match (try Some (List.assoc hop !arptab) with Not_found -> None) with
          | Some mac -> ifc.pktout <- ifc.pktout + 1; Devether.transmit (frame mac 0x800 pkt)
          | None ->
              pending := !pending @ [ (hop, pkt) ];
              Devether.transmit (frame (String.make 6 '\255') 0x806 (arp 1 (String.make 6 '\000') hop (source hop)))
        end

and input pkt =
  if String.length pkt >= 20 && Char.code pkt.[0] lsr 4 = 4 then begin
    let len = min (get16 pkt 2) (String.length pkt) in
    let pkt = String.sub pkt 0 len in
    let dst = String.sub pkt 16 4 in
    if ours dst || dst = bcast then begin
      ifc.pktin <- ifc.pktin + 1;
      let p = Char.code pkt.[9] in
      List.iter (fun (n, f) -> if n = p then f pkt) !protos_in
    end
  end

let bind dev =
  if ifc.dev <> "" then raise (Error "interface already bound");
  ignore (Devether.mac ());
  ifc.dev <- dev;
  Devether.register 0x806 arpinput;
  Devether.register 0x800 (fun f -> input (String.sub f 14 (String.length f - 14)))

let unbind () = ifc.dev <- ""; ifc.lifcs <- []

(*****************************************************************************)
(* Connections *)
(*****************************************************************************)

type conv = {
  proto : string; cid : int; key : int; mutable held : int;
  mutable laddr : string; mutable lport : int; mutable raddr : string; mutable rport : int;
  rq : string Queue.t; mutable cstate : string; mutable headers : bool; mutable eof : bool }

type proto = {
  pname : string; convs : conv option array;
  connect : conv -> string -> unit; announce : conv -> string -> unit; write : conv -> string -> unit;
  state : conv -> string; close : conv -> unit; listen : conv -> conv; ctl : conv -> string list -> bool }

let protos = ref []
let keys = ref 0

let newconv p =
  let n = Array.length p.convs in
  let rec free i = if i = n then raise (Error "no free conversations") else match p.convs.(i) with None -> i | Some _ -> free (i + 1) in
  let i = free 0 in
  incr keys;
  let c = { proto = p.pname; cid = i; key = !keys; held = 0; laddr = noaddr; lport = 0; raddr = noaddr; rport = 0;
            rq = Queue.create (); cstate = "Closed"; headers = false; eof = false } in
  p.convs.(i) <- Some c;
  c

let addrport s =
  match String.split_on_char '!' s with
  | [ a; p ] -> (parse a, (try int_of_string p with Failure _ -> 0))
  | [ p ] -> (noaddr, (try int_of_string p with Failure _ -> 0))
  | _ -> raise (Error "bad address")

let lastport = ref 5000
let nextport () = incr lastport; !lastport

let deliver c data = Queue.add data c.rq; Proc.wakeup (Ip_conv c.key)
