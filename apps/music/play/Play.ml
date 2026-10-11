(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-play: a file of music to samples on standard output, for
 * /dev/audio:
 *
 *     mini-play song.mod > /dev/audio          on mini-9pi
 *     mini-play song.mp3 | aplay -f cd         on Linux
 *
 * The samples are what Plan 9's /dev/audio takes and what a CD holds:
 * 16 bits signed, the low byte first, the left channel then the right,
 * 44,100 of each a second (176,400 bytes a second). No header: a pipe
 * has no length to write in one.
 *
 *     the file's bytes --> Player (by the name's end: Mod_player,
 *                          Music, Mpeg_audio, Wav)
 *                             |  a block of 4,096 samples, floats
 *                             v
 *                          16 bits, clipped --> standard output
 *
 * The file is read whole (a song is a few megabytes); its samples are
 * not: a block is computed when the last was written, so the program
 * waits where its reader waits, and a device that plays at its own
 * pace paces it. Nothing here knows the device.
 *
 * others:
 * 9front's play(1) is a script over a decoder a format (audio/mp3dec,
 * audio/wavdec, games/midi ...), each a filter of this shape; one
 * program here (Player says more).
 *
 * References: Plan 9's audio(3), for the samples' layout. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

let usage = "usage: mini-play [-s seconds] file
  the file's sound (.mod, .mid, .mp3, .mp2, .wav, .abc) as samples on
  standard output: 16 bits, little-endian, two channels, 44,100 a second
  -s seconds: no more than that much of it"

let block = 4096

(* [play caps p limit]: [p]'s blocks written, to its end or [limit] samples *)
let play (caps : < Cap.stdout; .. >) (p : Player.t) (limit : int) : unit =
  let out = Console.stdout_fd caps in
  let samples : Signal.stereo = { left = Array.make block 0.; right = Array.make block 0. } in
  let bytes = Bytes.create (4 * block) in
  let written = ref 0 in
  while (not (p.finished ())) && !written < limit do
    p.fill samples;
    let n = min block (limit - !written) in
    for i = 0 to n - 1 do
      Bytes.set_uint16_le bytes (4 * i) (Signal.to_int16 samples.left.(i) land 0xFFFF);
      Bytes.set_uint16_le bytes ((4 * i) + 2) (Signal.to_int16 samples.right.(i) land 0xFFFF)
    done;
    if Unix.write out bytes 0 (4 * n) <> 4 * n then failwith "short write";
    written := !written + n
  done

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let error why = Console.eprint caps ("mini-play: " ^ why ^ "\n"); Exit.Err "play" in
  let run (limit : int) (file : string) : Exit.t =
    match FS.path file with
    | Error why -> error why
    | Ok path -> (
        match FS.read_opt caps path with
        | None -> error ("can't read " ^ file)
        | Some bytes -> (
            match Player.of_file file bytes with
            | Error why -> error (file ^ ": " ^ why)
            | Ok p -> (
                match play caps p limit with
                | () -> Exit.OK
                | exception Failure why -> error why
                | exception Unix.Unix_error (e, _, _) -> error (Unix.error_message e))))
  in
  match List.tl (Array.to_list argv) with
  | [ "-s"; seconds; file ] -> (
      match float_of_string_opt seconds with
      | Some s when s >= 0. -> run (Signal.samples s) file
      | _ -> error usage)
  | [ file ] when file <> "" && file.[0] <> '-' -> run max_int file
  | _ -> error usage

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
