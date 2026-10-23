(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-quake's fights, a tenth of a second at a time, without the
 * playground: the player put somewhere of the level, firing or not,
 * and what the monsters near do, printed (their sequences, their
 * health, the player's): what the frames do not say.
 *   usage: Fight.exe [x= y= z= angle=] [secs=15] [fire=0..secs]
 *          [weapon=1..7] [sounds=1] [ai=ways] [wake=1] [god=1] *)

open Model

let () =
  Cap.main (fun caps ->
      let argv = Array.to_list (CapSys.argv caps) in
      let arg (k : string) (d : string) : string =
        match
          List.find_opt
            (fun (a : string) ->
              String.length a > String.length k
              && String.sub a 0 (String.length k + 1) = k ^ "=")
            argv
        with
        | Some a ->
            String.sub a
              (String.length k + 1)
              (String.length a - String.length k - 1)
        | None -> d
      in
      let dir = "games/fps/quake/data" in
      let read (f : string) : string option =
        FS.read_opt caps (Fpath.v (Filename.concat dir f))
      in
      let level =
        Model.load
          (Bspfile.parse
             (FS.read caps (Fpath.v (Filename.concat dir "e0m1.bsp"))))
      in
      let play = Play.create level in
      let f (k : string) (d : string) : float = float_of_string (arg k d) in
      Play.place play
        { x = f "x" "440"; y = f "y" "-340"; z = f "z" "-230" }
        (f "angle" "135") 0.;
      let models (p : string) : Alias.t option =
        Option.map Alias.load (read p)
      in
      let g = Game.create level play models [] true (arg "ai" "" = "ways") in
      let w = g.world in
      (* (weapon=n: every weapon, n in hand: impulse 9, then n) *)
      let weapon = int_of_string (arg "weapon" "0") in
      if weapon > 0 then Game.give_all g;
      (* (god=1: the player's health beyond what they can take, Quake's
       * god mode) *)
      if arg "god" "" <> "" then w.client.phealth <- 1e9;
      (* (wake=1: every monster hunting the player from the start, as if
       * it had seen it: how many find their way to it) *)
      if arg "wake" "" <> "" then
        List.iter
          (fun (e : Edict.t) ->
            if e.mclass <> None then begin
              e.enemy <- Edict.The_player;
              Monster_ai.found_target w e
            end)
          w.ents;
      let fire = f "fire" "0" in
      let none : Play.command =
        {
          forward = false;
          back = false;
          left = false;
          right = false;
          strafe_left = false;
          strafe_right = false;
          jump = false;
          run = false;
          look_up = false;
          look_down = false;
          use_key = false;
        }
      in
      let steps = int_of_float (f "secs" "15" *. 60.) in
      for k = 1 to steps do
        Play.frame play (1. /. 60.) none;
        Game.frame g (1. /. 60.) (play.time < fire)
          (if k = 1 then weapon else 0);
        List.iter
          (fun (x : Edict.sound) ->
            if arg "sounds" "" <> "" then
              Console.print caps
                (Printf.sprintf "  %.2f s: %s\n" play.time x.sfx))
          (Game.sounds g);
        if k mod 60 = 0 then begin
          let near =
            List.length
              (List.filter
                 (fun (e : Edict.t) ->
                   e.mclass <> None && e.health > 0.
                   && length (sub e.origin play.body.origin) < 300.)
                 w.ents)
          in
          let ways, floor =
            List.fold_left
              (fun ((a, b) : int * int) (e : Edict.t) ->
                if e.mclass <> None && e.health > 0. then
                  ( (if Ways.direction w e <> None then a + 1 else a),
                    if Float.abs (e.origin.z -. play.body.origin.z) <= 24. then
                      b + 1
                    else b )
                else (a, b))
              (0, 0) w.ents
          in
          Console.print caps
            (Printf.sprintf "%.0f s: %s  NEAR %d  WAYS %d  FLOOR %d\n" play.time
               (Game.status g) near ways floor);
          List.iter
            (fun (e : Edict.t) ->
              if
                e.mclass <> None
                && length (sub e.origin play.body.origin) < 800.
              then
                Console.print caps
                  (Printf.sprintf
                     "  %s at %.0f,%.0f,%.0f %s.%d hp %.0f enemy %b\n"
                     e.classname e.origin.x e.origin.y e.origin.z e.seq e.step
                     e.health
                     (e.enemy = Edict.The_player)))
            w.ents
        end
      done)
