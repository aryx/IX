(* Scan: the edges made spans, scanline by scanline, top to bottom
 * (Quake's r_edge.c, R_ScanEdges): Quake's answer to which face is in
 * front at each pixel, with no z-buffer and no pixel drawn twice.
 *
 * On a scanline, the active edges are sorted by u. Walking them left
 * to right, a leading edge pushes its surface on a stack sorted by key
 * (nearest on top), a trailing edge pops it; whenever the top changes,
 * the old top's run of pixels since it became the top is a span:
 *
 *   u:      0     40        120     200       319
 *   edges:  |head  A(lead)  B(lead)  B(trail)  A(trail)  tail|
 *   stack:  bg     A,bg     B,A,bg   A,bg      bg
 *                           (B nearer than A)
 *   spans:  bg 0-39, A 40-119, B 120-199, A 200-..., bg ...-319
 *
 * Then the edges step to the next scanline (u += u_step), those out of
 * order are moved back in place (an insertion sort of a list almost
 * sorted), the new ones merged in, the finished ones taken out.
 *
 * The keys come from the BSP's walk, front to back: a face reached
 * first is never behind one reached later, so the key alone orders
 * the world's faces. Two surfaces of the same key are brush models'
 * in one leaf (a door, a button): those are ordered by their 1/z at
 * the edge's pixel, the nearer on top.
 *
 * history:
 * The edge list, sorted spans and the surface stack are the
 * scanline algorithms of Wylie, Romney, Evans and Erdahl (1967) and
 * Watkins (1970), the hidden-surface methods before the z-buffer won;
 * Abrash tells why Carmack chose them for Quake (Graphics Programming
 * Black Book, chapters 66-67, "Quake's Hidden-Surface Removal"): a
 * level's worst views drew fewer pixels, each once.
 *
 * Where it stands in mini-quake: Render calls it once a frame, after
 * Bsp filed the edges; it calls Spans' drawing when the spans' table
 * is full, and at the end. *)

(* [scan_edges e v draw]: the spans of the frame, each surface's; draw
 * called to draw (and empty) the spans' table *)
val scan_edges : Edges.t -> View.t -> (unit -> unit) -> unit
