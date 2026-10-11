(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyNetwork.mli *)

(*****************************************************************************)
(* Bytes *)
(*****************************************************************************)

(* each byte's string, made once; a number of 16 bits as the network
 * has it, the high byte first, and read back *)
let net_byte = Array.make 256 ""
let () = for c = 0 to 255 do net_byte.(c) <- String.make 1 (Char.chr c) done
let net16 v = net_byte.((v lsr 8) land 255) ^ net_byte.(v land 255)
let net_get16 s i = (256 * Char.code s.[i]) + Char.code s.[i + 1]

(* The Internet's checksum (RFC 1071): the bytes as numbers of 16 bits
 * added up, what goes over 16 bits added back in, the result's bits
 * turned. Written into the bytes it covers (at a place left 0 while
 * adding), the sum of the whole is then 0: that is the check. A
 * packet's 2,048 bytes add up to less than 2^27: an int of 31 bits
 * holds it. *)
let net_sum s =
  let n = String.length s in
  let acc = ref 0 in
  for i = 0 to (n / 2) - 1 do acc := !acc + net_get16 s (2 * i) done;
  if n land 1 = 1 then acc := !acc + (256 * Char.code s.[n - 1]);
  while !acc > 0xffff do acc := (!acc land 0xffff) + (!acc lsr 16) done;
  0xffff - !acc

(*****************************************************************************)
(* Addresses *)
(*****************************************************************************)

(* an address is its four bytes, a string: nothing is computed on one,
 * and 32 bits do not fit tiny-ml's int. "10.0.0.2" to it and back; ""
 * when the text is not an address *)
let net_address text =
  let n = String.length text in
  let rec go i v digits acc =
    if i = n || text.[i] = '.' then
      (if digits = 0 || v > 255 then "" else if i = n then acc ^ net_byte.(v) else go (i + 1) 0 0 (acc ^ net_byte.(v)))
    else if text.[i] >= '0' && text.[i] <= '9' then go (i + 1) ((10 * v) + Char.code text.[i] - 48) (digits + 1) acc
    else "" in
  let a = go 0 0 0 "" in
  if String.length a = 4 then a else ""

let net_dotted a =
  string_of_int (Char.code a.[0]) ^ "." ^ string_of_int (Char.code a.[1]) ^ "." ^ string_of_int (Char.code a.[2]) ^ "."
  ^ string_of_int (Char.code a.[3])

(* the two ends of tiny-machine's wire: the machine, and its host *)
let net_machine = net_address "10.0.0.2"
let net_peer = net_address "10.0.0.1"

(*****************************************************************************)
(* IP: the envelope *)
(*****************************************************************************)

(* what a packet carries: IP's numbers *)
let ip_icmp = 1

(* a packet: IP's header of 20 bytes (version 4 and its length in
 * words, 0x45; the whole length; no fragment; 64 hops to live; what
 * it carries; the header's checksum; from; to), then what it carries *)
let ip_packet proto src dst payload =
  let head sum =
    net_byte.(0x45) ^ net_byte.(0) ^ net16 (20 + String.length payload) ^ net16 0 ^ net16 0 ^ net_byte.(64) ^ net_byte.(proto) ^ net16 sum
    ^ src ^ dst in
  head (net_sum (head 0)) ^ payload

(* a packet that came, if it is one for [me]: what it carries (IP's
 * number), who sent it, the bytes. Anything else is dropped without a
 * word, as on the Internet: a header that is not this plain one, a
 * length that is not the packet's, a checksum that is wrong, another's
 * address *)
let ip_read me p =
  let n = String.length p in
  if n < 20 || Char.code p.[0] <> 0x45 then None
  else begin
    let total = net_get16 p 2 in
    if total < 20 || total > n || net_sum (String.sub p 0 20) <> 0 || String.sub p 16 4 <> me then None
    else Some (Char.code p.[9], String.sub p 12 4, String.sub p 20 (total - 20))
  end

(*****************************************************************************)
(* ICMP: the echo *)
(*****************************************************************************)

(* "are you there?" and "yes": the question's kind is 8, the answer's
 * 0, and the answer returns the question's two numbers (whose
 * question, which one of them) and its bytes *)
let icmp_ask = 8
let icmp_answer = 0

let icmp_message kind id seq data =
  let m sum = net_byte.(kind) ^ net_byte.(0) ^ net16 sum ^ net16 id ^ net16 seq ^ data in
  m (net_sum (m 0))

(* its kind, its two numbers, its bytes; None when cut or damaged *)
let icmp_read b =
  if String.length b < 8 || net_sum b <> 0 then None
  else Some (Char.code b.[0], net_get16 b 4, net_get16 b 6, String.sub b 8 (String.length b - 8))

(*****************************************************************************)
(* A packet that came *)
(*****************************************************************************)

(* The packets to send back, and an answer to an echo if it is one (who
 * answers, the question's two numbers, its bytes), for who asked. A
 * question is answered here, by whoever has the address: the kernel,
 * and the host's end of the wire, which is this same function. *)
let net_input me packet =
  match ip_read me packet with
  | None -> [], None
  | Some (proto, from, body) ->
      if proto <> ip_icmp then [], None
      else (
        match icmp_read body with
        | None -> [], None
        | Some (kind, id, seq, data) ->
            if kind = icmp_ask then [ ip_packet ip_icmp me from (icmp_message icmp_answer id seq data) ], None
            else if kind = icmp_answer then [], Some (from, id, seq, data)
            else [], None)

(*****************************************************************************)
(* A packet said *)
(*****************************************************************************)

(* a packet in a few words, for who watches the wire: "echo? 1 from
 * 10.0.0.2 to 10.0.0.1, 4 bytes" *)
let net_describe p =
  if String.length p < 20 || Char.code p.[0] <> 0x45 || net_sum (String.sub p 0 20) <> 0 then
    "not a packet, " ^ string_of_int (String.length p) ^ " bytes"
  else begin
    let body = String.sub p 20 (String.length p - 20) in
    let what =
      if Char.code p.[9] <> ip_icmp then "protocol " ^ string_of_int (Char.code p.[9]) ^ ", " ^ string_of_int (String.length body) ^ " bytes"
      else (
        match icmp_read body with
        | None -> "icmp, damaged"
        | Some (kind, _, seq, data) ->
            (if kind = icmp_ask then "echo? " else if kind = icmp_answer then "echo! " else "icmp " ^ string_of_int kind ^ " ")
            ^ string_of_int seq ^ ", " ^ string_of_int (String.length data) ^ " bytes") in
    what ^ ", from " ^ net_dotted (String.sub p 12 4) ^ " to " ^ net_dotted (String.sub p 16 4)
  end
