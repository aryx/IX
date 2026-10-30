# mini-maps

A map moved and zoomed, fetched from the internet
([docs/plans/plan_maps.md](../../docs/plans/plan_maps.md)).

    mini-maps                       the world
    mini-maps lat=47.39 lon=0.69    a place, zoom=12 unless said

Drag or the arrows move it; the wheel, a double click, `+` and `-` zoom it.

| Module | What it is |
|---|---|
| `Mercator` | a latitude and a longitude to a pixel and back |
| `Tiles` | the pyramid: which tiles a window needs, zooming about a point |
| `Tile_worker` | the tiles fetched beside the window |
| `Map_window` | the window: its place, the tiles in memory, the picture |

`Worker_spawn` is mini-netscape's (`browsers/netscape`), copied by the
build. A coarse picture of a tile not there yet is made from an ancestor
(`Tiles.enlarged`).

The tiles are OpenStreetMap's, under their
[policy](https://operations.osmfoundation.org/policies/tiles/): the
credit always on the map, a User-Agent of our own, only what is in view.
`tiles=URL` asks another server, as the tests do.

Tests: `tests/Test.ml`, the arithmetic; `tests/frames.sh`, the window's
frames against `mini-httpd`, with tiles made by `tests/Make_tiles.ml`.
