(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Particles.mli *)

open Model

type kind = Slowgrav | Fire | Explode | Explode2

type particle = {
  mutable org : vec;
  mutable vel : vec;
  mutable color : int;
  mutable ramp : float;
  die : float;
  kind : kind;
}

(* (the particles' own random numbers: Lehmer's, as the game's) *)
type t = { mutable all : particle list; mutable seed : int }

let create () : t = { all = []; seed = 1 }

let rand (p : t) : int =
  p.seed <- p.seed * 16807 mod 2147483647;
  p.seed land 0x7fff

(* -n to n - 1 *)
let around (p : t) (n : int) : float = float ((rand p mod (2 * n)) - n)

(* r_part.c's ramps of the palette *)
let ramp1 = [| 0x6f; 0x6d; 0x6b; 0x69; 0x67; 0x65; 0x63; 0x61 |]
let ramp2 = [| 0x6f; 0x6e; 0x6d; 0x6c; 0x6b; 0x6a; 0x68; 0x66 |]
let ramp3 = [| 0x6d; 0x6b; 6; 5; 4; 3 |]
let add (p : t) (x : particle) : unit = p.all <- x :: p.all

(* R_RunParticleEffect *)
let run_effect (p : t) (time : float) (org : vec) (color : int) (count : int)
    : unit =
  for _i = 1 to count do
    add p
      {
        org =
          {
            x = org.x +. around p 8;
            y = org.y +. around p 8;
            z = org.z +. around p 8;
          };
        vel = zero;
        color = (color land lnot 7) + (rand p land 7);
        ramp = 0.;
        die = time +. (0.1 *. float (rand p mod 5));
        kind = Slowgrav;
      }
  done

let blood (p : t) (time : float) (org : vec) (count : int) : unit =
  run_effect p time org 73 (2 * count)

let gunshot (p : t) (time : float) (org : vec) : unit =
  run_effect p time org 0 20

let explosion (p : t) (time : float) (org : vec) : unit =
  for i = 1 to 1024 do
    let r = float (rand p land 3) in
    add p
      {
        org =
          {
            x = org.x +. around p 16;
            y = org.y +. around p 16;
            z = org.z +. around p 16;
          };
        vel = { x = around p 256; y = around p 256; z = around p 256 };
        color = ramp1.(0);
        ramp = r;
        die = time +. 5.;
        kind = (if i land 1 = 0 then Explode else Explode2);
      }
  done

let trail (p : t) (time : float) (from : vec) (to_ : vec) (kind : int) : unit =
  let d = sub to_ from in
  let len = length d in
  if len > 0. then begin
    let step = scale (3. /. len) d in
    let o = ref from and left = ref len in
    while !left > 0. do
      let r =
        if kind = 2 then float ((rand p land 3) + 2) else float (rand p land 3)
      in
      add p
        {
          org =
            {
              x = !o.x +. around p 3;
              y = !o.y +. around p 3;
              z = !o.z +. around p 3;
            };
          vel = zero;
          color = ramp3.(int_of_float r);
          ramp = r;
          die = time +. 2.;
          kind = Fire;
        };
      o := Model.add !o step;
      left := !left -. 3.
    done
  end

(* R_DrawParticles' moves *)
let run (p : t) (time : float) (dt : float) : unit =
  let grav = dt *. 800. *. 0.05 in
  p.all <-
    List.filter
      (fun (x : particle) ->
        x.org <- Model.add x.org (scale dt x.vel);
        let alive =
          match x.kind with
          | Slowgrav ->
              x.vel <- { x.vel with z = x.vel.z -. grav };
              true
          | Fire ->
              x.ramp <- x.ramp +. (dt *. 5.);
              if x.ramp >= 6. then false
              else begin
                x.color <- ramp3.(int_of_float x.ramp);
                x.vel <- { x.vel with z = x.vel.z +. grav };
                true
              end
          | Explode ->
              x.ramp <- x.ramp +. (dt *. 10.);
              if x.ramp >= 8. then false
              else begin
                x.color <- ramp1.(int_of_float x.ramp);
                x.vel <- Model.add x.vel (scale (4. *. dt) x.vel);
                x.vel <- { x.vel with z = x.vel.z -. grav };
                true
              end
          | Explode2 ->
              x.ramp <- x.ramp +. (dt *. 15.);
              if x.ramp >= 8. then false
              else begin
                x.color <- ramp2.(int_of_float x.ramp);
                x.vel <- sub x.vel (scale dt x.vel);
                x.vel <- { x.vel with z = x.vel.z -. grav };
                true
              end
        in
        alive && time < x.die)
      p.all

(* D_DrawParticle: a square, 256 / z pixels wide (1 to 4 at 320
 * across), if nearer than what is there *)
let draw (v : View.t) (p : t) : unit =
  let k = float v.width /. 320. in
  List.iter
    (fun (x : particle) ->
      let t = View.transform v (sub x.org v.origin) in
      if t.z >= 8. then begin
        let u = int_of_float (v.xcenter +. (v.xscale *. t.x /. t.z)) in
        let w = int_of_float (v.ycenter -. (v.yscale *. t.y /. t.z)) in
        let zi = int_of_float (16777216. /. t.z) in
        let pix =
          max 1 (min (int_of_float (4. *. k)) (int_of_float (256. *. k /. t.z)))
        in
        for yy = w to w + pix - 1 do
          for xx = u to u + pix - 1 do
            if xx >= 0 && xx < v.width && yy >= 0 && yy < v.height then begin
              let i = (yy * v.width) + xx in
              if zi >= v.zbuffer.(i) then begin
                v.zbuffer.(i) <- zi;
                Bytes.set v.screen i (Char.chr x.color)
              end
            end
          done
        done
      end)
    p.all
