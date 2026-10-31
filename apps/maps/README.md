# mini-maps

A map moved and zoomed, fetched from the internet
([docs/plans/plan_maps.md](../../docs/plans/plan_maps.md)).

    mini-maps                       the world
    mini-maps tours                 a place, found
    mini-maps lat=47.39 lon=0.69    a place by its numbers, zoom=12 unless said

Drag or the arrows move it; the wheel, a double click, `+` and `-` zoom it;
`/` (or a click on the box at the top left) finds a place, on Enter; a click
on the map marks one; `w` shows the forecast of the place marked, or of the
window's centre; `r` starts a route from the place marked, to the next place
marked (`r` again takes it away).

    mini-maps weather tours         the forecast as lines, for a terminal
    mini-maps route tours to amboise  the way, road by road, and how many
                                      nodes A* and Dijkstra each settled

A route is computed here, by A*, over the roads Overpass gives for a box
around both places: half a degree at most, without the residential streets
past a tenth of a degree. So no route across France; times come from the
road's class, with no traffic and no turn restrictions.

Under Plan 9's rc, a flag is quoted (`'zoom=3'`): `name=value` is an
assignment there.

| Module | What it is |
|---|---|
| `Mercator` | a latitude and a longitude to a pixel and back |
| `Tiles` | the pyramid: which tiles a window needs, zooming about a point |
| `Place` | a name to a place, asked of Nominatim |
| `Weather` | a place's forecast, asked of Open-Meteo; the WMO's codes |
| `Weather_panel` | the forecast on the window, its pictures of the sky |
| `Map_look` | the window's letters |
| `Map_http` | a request, saying who is asking |
| `Tile_cache` | the tiles on disk, for as long as the server says |
| `Map_worker` | the tiles, and a place or a forecast, fetched beside the window |
| `Roads` | the roads of a box, asked of Overpass, as a graph |
| `Route` | the quickest way: A*, and Dijkstra with no guess |
| `Routing` | two places to a route: the extract kept, the words, the line |
| `Map_services` | where the services are, the cache's directory, the terminal's commands |
| `Map_window` | the window: its place, the tiles in memory, the picture |

`Worker_spawn` is mini-netscape's (`browsers/netscape`), copied by the
build. A coarse picture of a tile not there yet is made from an ancestor
(`Tiles.enlarged`).

The tiles are OpenStreetMap's, under their
[policy](https://operations.osmfoundation.org/policies/tiles/): the
credit always on the map, a User-Agent of our own, only what is in view.
`tiles=URL` asks another server, as the tests do. The cache is in
`~/.cache/mini-maps`, 32 MB (`cache=DIR` or `off`, `cache-size=MB`).
The forecast is Open-Meteo's, CC BY 4.0, credited under it; `places=URL` and
`forecast=URL` ask other servers.

Tests: `tests/Test.ml`, the arithmetic; `tests/frames.sh`, the window's
frames against `mini-httpd`, with tiles made by `tests/Make_tiles.ml`;
`tests/cache.sh`, what is asked of that server and what is not.
