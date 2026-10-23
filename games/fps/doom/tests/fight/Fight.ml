(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-doom's fights, tic by tic, without the playground: the player
 * put somewhere of E1M1, firing or not, and what the monsters do,
 * printed (their states, where they are, the player's health): what
 * the frames do not say. *)

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
      let wad =
        Wad.parse
          (FS.read caps
             (Fpath.v (arg "wad" "games/fps/doom/data/freedoom.wad")))
      in
      let textures = Textures.load wad in
      let texture (name : string) : int =
        let k = Textures.texture textures name in
        if k = 0 then -1 else k
      in
      let level = Level.load wad "E1M1" texture (Textures.flat textures) in
      let ai = if arg "ai" "id" = "ways" then World.Ways else World.Id in
      let t = Play.create level textures true ai in
      Play.place t
        (float_of_string (arg "x" "600"))
        (float_of_string (arg "y" "420"))
        (float_of_string (arg "angle" "0") *. World.pi /. 180.);
      let tics = int_of_string (arg "tics" "600")
      and fire = int_of_string (arg "fire" "40") in
      let near (m : Things.mobj) : bool =
        m.actor <> None && m.kind.monster
        && Float.abs (m.mx -. t.player.x) +. Float.abs (m.my -. t.player.y)
           < 1200.
      in
      for k = 1 to tics do
        Play.tic t
          {
            forward = 0;
            side = 0;
            turn = 0;
            use = false;
            attack = k >= 30 && k < 30 + fire;
            change = None;
          };
        t.sounds <- [];
        if k mod 50 = 0 then begin
          Console.print caps
            (Printf.sprintf "tic %d: health %d, ammo %d, kills %d\n" k
               t.player.health t.player.clips t.kills);
          List.iter
            (fun (m : Things.mobj) ->
              if near m then
                Console.print caps
                  (Printf.sprintf
                     "  %s at %.0f,%.0f %s hp %d, heard %b, sees %b\n"
                     m.kind.sprite m.mx m.my
                     (match m.state with Some st -> st.sname | None -> "-")
                     m.health t.heard.(m.sector.index)
                     (Enemy.sees t m Things.The_player)))
            t.things
        end
      done)
