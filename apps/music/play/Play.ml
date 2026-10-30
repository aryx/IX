(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-play: a file of music played: its samples written to
 * /dev/audio, or to standard output:
 *
 *     mini-play song.mod                       on mini-9pi
 *     mini-play -c song.mp3 | aplay -f cd      on Linux
 *
 * old: standard output always, mini-play song.mod > /dev/audio (the
 * author, 2026-10-13, having played on the Pi 1: "I think it would be
 * better for play to use directly /dev/audio"). A filter is 9front's
 * way and kept as -c; what one types to hear a file is its name.
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
 *                          16 bits, clipped --> /dev/audio (or -c)
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
 * A film is the same command with a window: mini-play clip.avi (Film; its
 * kind is the file's first bytes, File_kind, where a sound's is the name's
 * end, Player). -c and -s are for sounds.
 *
 * References: Plan 9's audio(3), for the samples' layout. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-play [-c] [-s seconds] file
  the file's sound (.mod, .mid, .mp3, .mp2, .wav, .abc) played: written
  to /dev/audio, 16 bits, little-endian, two channels, 44,100 a second;
  a film (.y4m, .fli, .flc, .avi, an animated .gif) in a window
  -c: the samples to standard output (mini-play -c file | aplay -f cd)
  -s seconds: no more than that much of it"

let device = "/dev/audio"

let block = 4096

(* [play out p limit]: [p]'s blocks written, to its end or [limit] samples *)
let play (out : Unix.file_descr) (p : Player.t) (limit : int) : unit =
  let samples : Signal.stereo = { left = Array.make block 0.; right = Array.make block 0. } in
  let bytes = Bytes.create (4 * block) in
  let written = ref 0 in
  while (not (p.finished ())) && !written < limit do
    p.fill samples;
    let n = min block (limit - !written) in
    (* old: Bytes.set_uint16_le bytes (4 * i) (Signal.to_int16
     * samples.left.(i) land 0xFFFF), and the right one's: Float.round
     * and two checked stores a sample, a tenth of a MIDI file's
     * instructions on arm (machine/tests/profile.sh, 2026-10-13).
     * Audio_source.s16's way: to the nearest, a half away from zero,
     * by a truncation; the places are within [bytes]. *)
    for i = 0 to (2 * n) - 1 do
      let x = if i land 1 = 0 then Array.unsafe_get samples.left (i lsr 1) else Array.unsafe_get samples.right (i lsr 1) in
      let y = x *. 32767. in
      let v = if y >= 0. then int_of_float (y +. 0.5) else - int_of_float (0.5 -. y) in
      let v = if v > 32767 then 32767 else if v < -32768 then -32768 else v in
      Bytes.unsafe_set bytes (2 * i) (Char.unsafe_chr (v land 0xff));
      Bytes.unsafe_set bytes ((2 * i) + 1) (Char.unsafe_chr ((v lsr 8) land 0xff))
    done;
    if Unix.write out bytes 0 (4 * n) <> 4 * n then failwith "short write";
    written := !written + n
  done

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let error why = Console.eprint caps ("mini-play: " ^ why ^ "\n"); Exit.Err "play" in
  let run (stdout : bool) (limit : int) (file : string) : Exit.t =
    match FS.path file with
    | Error why -> error why
    | Ok path -> (
        match FS.read_opt caps path with
        | None -> error ("can't read " ^ file)
        | Some bytes -> (
            match Player.of_file file bytes with
            | Error why -> error (file ^ ": " ^ why)
            | Ok p -> (
                match if stdout then Some (Console.stdout_fd caps) else (try Some (FS.open_device_fd caps device) with Unix.Unix_error _ -> None) with
                | None -> error ("can't open " ^ device ^ " (-c: the samples to standard output)")
                | Some out -> (
                    match play out p limit with
                    | () -> Exit.OK
                    | exception Failure why -> error why
                    | exception Unix.Unix_error (e, _, _) -> error (Unix.error_message e)))))
  in
  (* mini-ml's collector copies all that is alive each time, and what
   * is alive here is the song (a MOD's instruments, a float a sample):
   * 37 of a hundred instructions of a MOD were its copying, measured on
   * arm (2026-10-13; the author, of tune.mod on the Pi 1: "not playing
   * smoothly"). A heap eight times what is alive is collected an eighth
   * as often (Plan9_loop's, for a game's floats). OCaml's own collector
   * takes the number as a hint and is not changed by it. *)
  Gc.set { (Gc.get ()) with Gc.space_overhead = 700 };
  let rec args (stdout : bool) (limit : int) (l : string list) : Exit.t =
    match l with
    | "-c" :: rest -> args true limit rest
    | "-s" :: seconds :: rest -> (
        match float_of_string_opt seconds with
        | Some s when s >= 0. -> args stdout (Signal.samples s) rest
        | _ -> error usage)
    | [ file ] when file <> "" && file.[0] <> '-' -> run stdout limit file
    | _ -> error usage in
  args false max_int (List.tl (Array.to_list argv))

(* the last argument, when it is a film: its kind and its bytes *)
let film_of (caps : < Cap.open_in; .. >) (argv : string array) : Film.t option =
  let last = argv.(Array.length argv - 1) in
  if Array.length argv < 2 || last = "" || last.[0] = '-' then None
  else
    match FS.path last with
    | Error _ -> None
    | Ok path -> (
        match File_kind.of_path caps path with
        | exception Sys_error _ -> None
        | kind when not (Film.is_film kind) -> None
        | kind -> (
            match Option.map (Film.read ~kind) (FS.read_opt caps path) with
            | Some (Ok film) -> Some film
            | Some (Error why) -> failwith (last ^ ": " ^ why)
            | None -> None))

let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             let argv = CapSys.argv caps in
             match film_of caps argv with
             | Some film ->
                 Film.run caps film;
                 Exit.OK
             | None -> main caps argv)))
