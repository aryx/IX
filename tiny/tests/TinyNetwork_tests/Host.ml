(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyNetwork.ml on the host, with no machine: its laws, a line each
 * (TinyNetwork_test.sh compares them with host.expected), and, given a
 * file's name, a ping's two packets and a conversation of IL's written
 * there as a capture (pcap,
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

(* Two machines and a wire between them, with no machine: a's program
 * dials b's port 70, writes its messages and reads until the end (as
 * get does); b's reads as many, writes its own and is done (as the
 * peer). A packet takes 2 ticks; which are lost is said by [lost], a
 * function of the packet's count. What each program read, whether both
 * connections ended, the packets sent and lost, the ticks it took; and
 * every packet, in its order, with where it went. *)
let rec heard c = match il_hear c with Some m -> m :: heard c | None -> []

let converse_slow every lost from_a from_b =
  let a = net_stack net_machine 1000 and b = net_stack net_peer 5000 in
  b.ns_ports <- [ 70 ];
  let wire = ref [] and sent = ref 0 and dropped = ref 0 and trace = ref [] and now = ref 0 in
  let put to_a packets =
    List.iter (fun p ->
      incr sent;
      let gone = lost !sent in
      trace := ((if gone then "x " else if to_a then "< " else "> "), p) :: !trace;
      if gone then incr dropped else wire := !wire @ [ !now + 2, to_a, p ]) packets in
  let ca, sync = net_dial a net_peer 70 0 in
  put false [ sync ];
  let cb = ref None and most = ref 0 in
  let todo_a = ref from_a and todo_b = ref from_b and got_a = ref [] and got_b = ref [] in
  let rec push to_a c todo =
    match !todo with
    | m :: rest when il_room c -> todo := rest; put to_a [ il_write c m !now ]; push to_a c todo
    | _ -> () in
  while !now < 20000 && (!now = 0 || a.ns_conns <> [] || b.ns_conns <> []) do
    incr now;
    let due, later = List.partition (fun (t, _, _) -> t <= !now) !wire in
    wire := later;
    List.iter (fun (_, to_a, p) -> put (not to_a) (fst (net_input (if to_a then a else b) !now p))) due;
    (match b.ns_fresh with c :: _ -> cb := Some c; b.ns_fresh <- [] | [] -> ());
    (* (a's program reads all there is, or one message every so many ticks) *)
    if every = 1 then got_a := !got_a @ heard ca
    else if !now mod every = 0 then (match il_hear ca with Some m -> got_a := !got_a @ [ m ] | None -> ());
    most := max !most (List.length ca.il_r.il_heard);
    push false ca todo_a;
    (match !cb with
     | Some c ->
         got_b := !got_b @ heard c;
         if List.length !got_b >= List.length from_a then (push true c todo_b; if !todo_b = [] then il_done c)
     | None -> ());
    put false (net_tick a !now);
    put true (net_tick b !now)
  done;
  (!got_a, !got_b, ca.il_at = Il_closed && a.ns_conns = [] && b.ns_conns = [], !sent, !dropped, !now, List.rev !trace), !most

let converse lost from_a from_b = fst (converse_slow 1 lost from_a from_b)

(* a wire that loses so many packets in a hundred, by a seed *)
let by_seed seed percent =
  let state = ref seed in
  fun _ ->
    state := ((!state * 1103515245) + 12345) land 0x3fffffff;
    (!state lsr 8) mod 100 < percent

let rec prefix l m = match l, m with [], _ -> true | x :: l, y :: m -> x = y && prefix l m | _ -> false
let numbered who n = List.init n (fun i -> Printf.sprintf "%s's message %d" who i)

let il_laws () =
  let a = net_machine and b = net_peer in
  let sync = ip_packet ip_il a b (il_message il_sync 5000 70 1000 0 "") in
  print_endline (hex sync);
  let data = il_message il_data 5000 70 1001 5000 "hello.txt" in
  check "IL's header is 18 bytes, and read back" (String.length data = 27 && il_read data = Some (il_data, 5000, 70, 1001, 5000, "hello.txt"));
  check "a byte damaged, anywhere: not read" (List.for_all (fun i -> il_read (damaged data i) = None) (List.init 27 Fun.id));
  check "cut, or longer than it says: not read" (il_read (String.sub data 0 26) = None && il_read (data ^ "x") = None);
  check "a number over 2^30: not read" (il_read (il_message il_data 1 2 0x40000000 0 "") = None && il_read (il_message il_data 1 2 0x3fffffff 0 "") <> None);
  (* a conversation with nothing lost, and its packets *)
  let got_a, got_b, ended, sent, _, _, trace = converse (fun _ -> false) [ "hello.txt" ] [ "Hello,"; "from the other end." ] in
  check "a line there, two messages back, the end" (got_b = [ "hello.txt" ] && got_a = [ "Hello,"; "from the other end." ] && ended);
  List.iter (fun (dir, p) -> print_endline (dir ^ net_describe p)) trace;
  check "in 10 packets" (sent = 10);
  (* the plan's conversation: the peer's second message of five lost *)
  let five = numbered "b" 5 in
  let got_a, _, ended, _, dropped, _, trace = converse (fun n -> n = 7) [ "five" ] five in
  List.iter (fun (dir, p) -> print_endline (dir ^ net_describe p)) trace;
  check "a message lost: asked for, sent again, all five once and in order" (got_a = five && ended && dropped = 1);
  check "the lost one was sent as data and again as data?"
    (List.length (List.filter (fun (_, p) -> ip_read a p <> None && (match il_read (String.sub p 20 (String.length p - 20)) with Some (k, _, _, id, _, _) -> k = il_dataquery && id = 5003 | None -> false)) trace) = 1);
  (* a program that reads slower than the wire brings: the other end waits for it *)
  let slow = numbered "b" 100 in
  let (got_a, _, ended, sent, _, ticks, trace), most = converse_slow 8 (fun _ -> false) [ "slow" ] slow in
  let again = List.length (List.filter (fun (_, p) -> match il_read (String.sub p 20 (String.length p - 20)) with Some (k, _, _, _, _, _) -> k = il_dataquery || k = il_query | None -> false) trace) in
  Printf.printf "a slow reader: %d packets, %d ticks, %d messages waiting at most, %d asked or sent again\n" sent ticks most again;
  check "a reader of a message every 8 ticks: all 100, never more than 20 waiting, nothing asked or sent again" (got_a = slow && ended && most <= il_window && again = 0);
  (* and one slower than the other end's patience: asked where it is, it says what it received, and nothing is sent again *)
  let slower = numbered "b" 30 in
  let (got_a, _, ended, sent, _, ticks, trace), _ = converse_slow 60 (fun _ -> false) [ "slower" ] slower in
  let kinds k = List.length (List.filter (fun (_, p) -> match il_read (String.sub p 20 (String.length p - 20)) with Some (k', _, _, _, _, _) -> k' = k | None -> false) trace) in
  Printf.printf "a slower reader: %d packets, %d ticks, %d queries, %d states, %d sent again\n" sent ticks (kinds il_query) (kinds il_state) (kinds il_dataquery);
  check "a reader of a message every 60 ticks: all 30, asked where it is, nothing sent again" (got_a = slower && ended && kinds il_query > 0 && kinds il_dataquery = 0);
  (* nobody listens; nobody is there *)
  let s = net_stack a 1000 and t = net_stack b 5000 in
  let c, sync = net_dial s b 71 0 in
  let no = fst (net_input t 0 sync) in
  check "a port nobody listens on: a close back, and the dial is over" (List.length no = 1 && fst (net_input s 0 (List.hd no)) = [] && c.il_at = Il_closed);
  let s = net_stack a 1000 in
  let c, _ = net_dial s b 70 0 in
  let syncs = ref 1 and now = ref 0 in
  while c.il_at <> Il_closed && !now < 100000 do incr now; syncs := !syncs + List.length (net_tick s !now) done;
  Printf.printf "nobody there: %d packets, given up at tick %d\n" !syncs !now;
  check "nobody there: asked again five times, each wait twice the one before, then the end said and over" (c.il_at = Il_closed && s.ns_conns = [] && !syncs = 7);
  (* a gateway: the wire's end that answers for another address, when it said it would, once *)
  let far = net_address "192.0.2.7" in
  let s = net_stack a 1000 and g = net_stack b 5000 in
  g.ns_gate <- true;
  let c, sync = net_dial s far 80 0 in
  let refused = fst (net_input g 0 sync) in
  check "a gateway asked for an address it has no way to: a close from that address" (List.length refused = 1 && ip_read a (List.hd refused) <> None && String.sub (List.hd refused) 12 4 = far && fst (net_input s 0 (List.hd refused)) = [] && c.il_at = Il_closed);
  let c, sync = net_dial s far 80 0 in
  g.ns_others <- [ far, 80 ];
  let agreed = fst (net_input g 0 sync) in
  check "and for one it has: a connection, the gateway's end of it at that address, the leave used"
    (List.length agreed = 1 && (match g.ns_fresh with [ d ] -> d.il_me = far && d.il_peer = a && d.il_lport = 80 | _ -> false) && g.ns_others = []
     && List.length (fst (net_input s 0 (List.hd agreed))) = 1 && c.il_at = Il_established);
  let other = net_stack b 5000 in
  check "who is no gateway does not read what is for another" (net_input other 0 sync = ([], None));
  (* the law: over a wire that loses, every message once and in order *)
  let from_a = numbered "a" 30 and from_b = numbered "b" 300 in
  List.iter (fun percent ->
    List.iter (fun seed ->
      let got_a, got_b, ended, sent, dropped, ticks, _ = converse (by_seed seed percent) from_a from_b in
      let whole = got_a = from_b && got_b = from_a in
      check (Printf.sprintf "%2d%% lost, seed %d: %s; %d packets, %d lost, %d ticks" percent seed
               (if whole then "30 messages there and 300 back, each once, in order"
                else Printf.sprintf "given up after %d there and %d back, each once, in order" (List.length got_b) (List.length got_a))
               sent dropped ticks)
        (prefix got_a from_b && prefix got_b from_a && ((whole && ended) || percent >= 30))) [ 1; 2; 3; 4; 5 ]) [ 0; 2; 10; 30; 50 ];
  List.map snd trace

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
  let sa = net_stack a 1000 and sb = net_stack b 5000 in
  let net_input me p = net_input (if me = a then sa else sb) 0 p in
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
  let il = il_laws () in
  if Array.length Sys.argv > 1 then begin
    let out = open_out_bin Sys.argv.(1) in
    output_string out (pcap ([ question; answer ] @ il));
    close_out out
  end
