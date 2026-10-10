(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyTetris.ml on the host, by OCaml, with no machine: games played
 * by the game's own functions, from a seed and a script of keys and
 * frames, the well printed as text after each step (its rules); then
 * the last model's picture, by TinyPlayground.ml and TinyGraphics.ml,
 * written as tiny-machine -screen writes it.
 * usage: Host.exe font1.bin out.ppm *)
open TinyTetris

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

(* a script: l r u d the arrows, s the space, a number so many frames, p prints *)
let play seed script =
  Printf.printf "seed %d: %s\n" seed script;
  let m = ref (game.init seed) in
  List.iter (fun w ->
    match w with
    | "l" -> m := game.key 130 !m
    | "r" -> m := game.key 131 !m
    | "u" -> m := game.key 128 !m
    | "d" -> m := game.key 129 !m
    | "s" -> m := game.key 32 !m
    | "p" -> print !m
    | n -> for _ = 1 to int_of_string n do m := game.frame !m done) (String.split_on_char ' ' script);
  !m

let () =
  (* the first piece: falls by the clock, moves, stops at the sides, turns, is dropped *)
  ignore (play 1 "p 30 p l l l l l l l p u p r r r r r r r r r p u u u p s p");
  (* pieces dropped where they are until one cannot enter: the game over, where keys do nothing; the space, another game *)
  ignore (play 2 "s s s s s s s s s s s s p s p l 60 p s p");
  (* a row filled and removed: two I laid end to end and an O (seed 28's first pieces), whose top half comes down *)
  let m = play 28 "l l l s r s r r r r p s p s 45 p" in
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  let both = TinyDraw.d_image TinyPlayground.picture 0 0 game.width game.height 0 ^ TinyDraw.d_image TinyPlayground.ground 0 0 game.width game.height 0 in
  ignore (TinyCalls.u_write 3 both);
  TinyPlayground.show game [] (game.view m);
  TinyGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyGraphics.r = TinyGraphics.rect 0 0 640 480; at = 0xf00000; repl = false } in
  let c = TinyGraphics.connect screen (TinyGraphics.font_mask 0x1000 (TinyGraphics.alloc 16384)) in
  TinyGraphics.messages c (Buffer.contents TinyCalls.drawn);
  Out_channel.with_open_bin Sys.argv.(2) (fun oc -> output_string oc (TinyMemory.ppm ()))
