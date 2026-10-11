(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-timesync: the time a server of the network says, as the seconds
 * since 1970, on standard output; what a machine without a clock chip
 * (a Raspberry Pi) writes to its /dev/time when it starts, a
 * certificate's dates being checked against it:
 *
 *     timesync pool.ntp.org > /dev/time
 *
 * One question and its answer (SNTP): a packet of 48 bytes, its first
 * 0x1b (version 3, a client), sent to UDP's port 123; in the answer of
 * the same size the bytes 40 to 43 are the seconds since 1900 when the
 * server sent it. None of NTP's own work: no delay measured, no clock
 * slowed or hurried, one server believed; a second is what is wanted.
 *
 * history:
 * Plan 9's is aux/timesync, which also takes the time from a file
 * server or a radio clock and keeps the clock's frequency right.
 * David Mills's NTP (1985) is the protocol; SNTP its simple subset.
 *
 * References: RFC 4330, "Simple Network Time Protocol (SNTP) Version
 * 4" (2006); Plan 9's timesync(8). *)

type caps = < Cap.network; Cap.open_in; Cap.stdout; Cap.stderr; Cap.argv >

let usage = "usage: mini-timesync server
  the seconds since 1970 as the server (pool.ntp.org) says them, by SNTP"

(* 1900 to 1970, in seconds *)
let since_1900 = 2208988800.

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let result : (float, string) result =
    match List.tl (Array.to_list argv) with
    | [ server ] when server <> "" && server.[0] <> '-' -> (
        (* (an address is itself) *)
        let is_address = String.for_all (fun c -> (c >= '0' && c <= '9') || c = '.') server in
        match if is_address then [ server ] else Dns.resolve caps server with
        | [] -> Error (server ^ ": no address")
        | address :: _ -> (
            match Udp.ask caps ~address ~port:123 ("\x1b" ^ String.make 47 '\000') 5. with
            | Some answer when String.length answer >= 48 ->
                (* (in floats: the seconds are past an int of 31 bits) *)
                let byte i = float_of_int (Char.code answer.[40 + i]) in
                let seconds = (byte 0 *. 16777216.) +. (byte 1 *. 65536.) +. (byte 2 *. 256.) +. byte 3 in
                if seconds < since_1900 then Error (server ^ ": no time in its answer") else Ok (seconds -. since_1900)
            | Some _ -> Error (server ^ ": an answer too short")
            | None -> Error (server ^ ": no answer")
            | exception Unix.Unix_error (e, _, _) -> Error (server ^ ": " ^ Unix.error_message e)))
    | _ -> Error usage
  in
  match result with
  | Ok seconds -> Console.print caps (Printf.sprintf "%.0f\n" seconds); Exit.OK
  | Error why -> Console.eprint caps ("mini-timesync: " ^ why ^ "\n"); Exit.Err "timesync"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
