(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyNetwork.ml on the host, with no machine: its laws, a line each
 * (TinyNetwork_test.sh compares them with host.expected), and, given a
 * file's name, a ping's two packets written there as a capture (pcap,
 * the packets raw IP), for tcpdump to check with code that is not
 * ours. *)

open TinyNetwork

let check what ok = print_endline ((if ok then "ok " else "FAIL ") ^ what)
let hex s = String.concat " " (List.map (fun c -> Printf.sprintf "%02x" (Char.code c)) (List.of_seq (String.to_seq s)))

(* a string with one byte changed *)
let damaged s i = String.mapi (fun j c -> if j = i then Char.chr (Char.code c lxor 0x10) else c) s

(* pcap: a header (the magic, version 2.4, a packet's 65,535 bytes at
 * most, link type 101: raw IP), then each packet after its time and
 * its length twice, all little-endian *)
let pcap packets =
  let le32 v = String.init 4 (fun i -> Char.chr ((v lsr (8 * i)) land 255)) in
  let le16 v = String.init 2 (fun i -> Char.chr ((v lsr (8 * i)) land 255)) in
  le32 0xa1b2c3d4 ^ le16 2 ^ le16 4 ^ le32 0 ^ le32 0 ^ le32 65535 ^ le32 101
  ^ String.concat "" (List.mapi (fun i p -> le32 i ^ le32 0 ^ le32 (String.length p) ^ le32 (String.length p) ^ p) packets)

let () =
  let a = net_machine and b = net_peer in
  check "an address read and said" (net_dotted (net_address "192.168.0.199") = "192.168.0.199" && net_dotted a = "10.0.0.2");
  check "not an address" (List.for_all (fun t -> net_address t = "") [ ""; "10.0.0"; "10.0.0.256"; "10..0.1"; "10.0.0.1.2"; "ten.0.0.1" ]);
  (* RFC 1071's own example, and a header from the books (its sum b861) *)
  check "the checksum of RFC 1071's example" (net_sum "\x00\x01\xf2\x03\xf4\xf5\xf6\xf7" = 0x220d);
  let book = "\x45\x00\x00\x73\x00\x00\x40\x00\x40\x11\x00\x00\xc0\xa8\x00\x01\xc0\xa8\x00\xc7" in
  check "the checksum of a known header" (net_sum book = 0xb861);
  check "an odd number of bytes" (net_sum "\x01\x02\x03" = 0xffff - 0x0402);
  let question = ip_packet ip_icmp a b (icmp_message icmp_ask 7 1 "ping") in
  print_endline (hex question);
  check "a packet is 20 bytes and what it carries" (String.length question = 32);
  check "a packet read by whom it is for" (ip_read b question = Some (ip_icmp, a, icmp_message icmp_ask 7 1 "ping"));
  check "not read by another" (ip_read a question = None);
  check "a byte of the header damaged: dropped" (List.for_all (fun i -> ip_read b (damaged question i) = None) [ 0; 3; 8; 9; 10; 12; 19 ]);
  check "cut short: dropped" (ip_read b (String.sub question 0 31) = None && ip_read b "" = None);
  check "longer than it says: the rest left" (ip_read b (question ^ "xx") = ip_read b question);
  (* the echo: asked by a, answered by b, heard by a *)
  let back, heard = net_input b question in
  check "a question is answered, and is no answer" (List.length back = 1 && heard = None);
  let answer = List.hd back in
  print_endline (hex answer);
  check "the answer is heard by who asked: who, the numbers, the bytes" (net_input a answer = ([], Some (b, 7, 1, "ping")));
  check "an answer is not answered" (fst (net_input a answer) = []);
  check "a question's byte damaged: no answer" (net_input b (damaged question 25) = ([], None) && net_input b (damaged question 30) = ([], None));
  check "an empty question" (net_input a (List.hd (fst (net_input b (ip_packet ip_icmp a b (icmp_message icmp_ask 1 2 ""))))) = ([], Some (b, 1, 2, "")));
  let big = String.make 1024 'x' in
  check "a question of 1,024 bytes" (net_input a (List.hd (fst (net_input b (ip_packet ip_icmp a b (icmp_message icmp_ask 9 300 big))))) = ([], Some (b, 9, 300, big)));
  check "another protocol: nothing" (net_input b (ip_packet 40 a b "hello") = ([], None));
  print_endline (net_describe question);
  print_endline (net_describe answer);
  print_endline (net_describe (ip_packet 40 a b "hello"));
  print_endline (net_describe "junk");
  if Array.length Sys.argv > 1 then begin
    let out = open_out_bin Sys.argv.(1) in
    output_string out (pcap [ question; answer ]);
    close_out out
  end
