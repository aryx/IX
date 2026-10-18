(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyAppTetris.ml on the host, by OCaml, with no machine: games played
 * by the game's own functions, from a seed and a script of keys and
 * frames, the well printed as text after each step (its rules), and
 * the sounds a step makes; then
 * the last model's picture, by TinyLibPlayground.ml and TinyKernelGraphics.ml,
 * written as tiny-machine -screen writes it.
 * usage: Host.exe font1.bin out.ppm *)
open TinyAppTetris

(* the well and the piece: a letter a kind, the falling piece's in
 * capitals; then the score, the rows, the next piece *)
let print (m : model) =
  let names = "ijlostz" in
  let falling = cells m.piece in
  for r = 0 to 19 do
    print_string "  |";
    for c = 0 to 9 do
      let k = m.board.well.((r * 10) + c) in
      print_char (if List.mem (c, r) falling then Char.uppercase_ascii names.[m.piece.kind] else if k = 0 then '.' else names.[k - 1])
    done;
    print_string "|\n"
  done;
  Printf.printf "  score %d, rows %d, next %c%s\n" m.board.score m.board.rows names.[m.board.next] (if m.over then ", over" else "")

(* the music a model wants: its pace, or none *)
let music (m : model) =
  match game.music m with
  | Some t -> Printf.printf "  music: %d ms an eighth\n" t.pace
  | None -> print_string "  music: none\n"

(* a script: l r u d the arrows, s the space, m the music off and on, a
 * number so many frames, p prints the well and the music *)
let play seed script =
  Printf.printf "seed %d: %s\n" seed script;
  let m = ref (game.init seed) in
  (* a step's sounds, said after it: each one's pitches and length *)
  let step f =
    let was = !m in
    m := f was;
    match game.sound was !m with
    | [] -> ()
    | sounds ->
        print_string "  heard:";
        List.iter (fun (snd : TinyLibPlayground.sound) -> Printf.printf " %d-%d Hz %d ms" snd.hz snd.to_hz snd.ms) sounds;
        print_newline () in
  List.iter (fun w ->
    match w with
    | "l" -> step (game.key 130)
    | "r" -> step (game.key 131)
    | "u" -> step (game.key 128)
    | "d" -> step (game.key 129)
    | "s" -> step (game.key 32)
    | "m" -> step (game.key 109)
    | "p" -> print !m; music !m
    | n -> for _ = 1 to int_of_string n do step game.frame done) (String.split_on_char ' ' script);
  !m

let () =
  (* the theme: each part's eighths (the parts go round together when they are as long) *)
  List.iter (fun (p : TinyLibPlayground.part) -> Printf.printf "theme: a part of %d notes, %d eighths\n" (List.length p.notes) (List.fold_left (fun n (_, k) -> n + k) 0 p.notes)) TinyAppTetris.theme;
  (* the first piece: falls by the clock, moves, stops at the sides, turns, is dropped *)
  ignore (play 1 "p 30 p l l l l l l l p u p r r r r r r r r r p u u u p s p");
  (* pieces dropped where they are until one cannot enter: the game over, where keys do nothing; the space, another game *)
  ignore (play 2 "s s s s s s s s s s s s p s p l 60 p s p m p m p");
  (* a row filled and removed: two I laid end to end and an O (seed 28's first pieces), whose top half comes down *)
  let m = play 28 "l l l s r s r r r r p s p s 45 p" in
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  let both = TinyLibDraw.d_image TinyLibPlayground.picture 0 0 game.width game.height 0 ^ TinyLibDraw.d_image TinyLibPlayground.ground 0 0 game.width game.height 0 in
  ignore (TinyCalls.u_write 3 both);
  TinyLibPlayground.show game [] (game.view m);
  TinyKernelGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyKernelGraphics.r = TinyKernelGraphics.rect 0 0 640 480; at = 0xf00000; repl = false } in
  let c = TinyKernelGraphics.connect screen (TinyKernelGraphics.font_mask 0x1000 (TinyKernelGraphics.alloc 16384)) in
  TinyKernelGraphics.messages c (Buffer.contents TinyCalls.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc -> output_string oc (TinyMemory.ppm ()))
