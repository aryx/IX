(* Sprites: the things, and what is seen through (Doom's r_things.c).
 *
 * As the tree is walked, the things of each sector reached are
 * projected (R_AddSprites, R_ProjectSprite): the thing's place in the
 * eye's frame, its scale, the columns its picture covers (the
 * picture's offsets: its feet at the thing's place), the rotation seen
 * (eighths of a turn between the eye's angle to it and its own), the
 * light (its sector's by its scale; a bright frame at full light): a
 * vissprite. After the walls and the planes (R_DrawMasked) they are
 * drawn farthest first, each clipped column by column by the drawsegs
 * in front of it (R_DrawSprite: a seg nearer than the thing, by its
 * scale or by the side the thing is on, clips it from above or below,
 * as its silhouette says), each column its posts, transparent between
 * (R_DrawMaskedColumn).
 *
 * A two-sided line's middle texture (a grate, a window's bars) is
 * drawn the same way, its columns read as posts (R_RenderMaskedSegRange:
 * a column of one patch is that patch's; one of several has no posts,
 * and shows what is there, the "medusa"), after the things behind it
 * and before those in front.
 *
 * Where it stands in mini-doom: Render calls project_sprite from its
 * walk and draw_masked at the end of a frame. *)

(* [project_sprite r sprites tic thing]: a vissprite of the thing, if
 * it can be seen *)
val project_sprite : View.t -> Things.sprites -> int -> Things.mobj -> unit

(* R_DrawMasked: the vissprites, farthest first, then the masked
 * middle textures left *)
val draw_masked : View.t -> Textures.t -> Level.t -> unit
