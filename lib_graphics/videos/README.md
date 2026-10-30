# lib_graphics/videos: films, as a player sees them

The author's playground's `libs/graphics/videos` (`~/playground`), for
[`plan_video.md`](../../docs/plans/plan_video.md): the formats that found
each idea, played by mini-play (`apps/music/play/Film`). The numbers are
`scripts/playground_copies.sh lib_graphics/videos`.

**Copied:** `Yuv`, `Psnr`, `Y4m`, `Movie`, `Fli`, `Avi`, and their unit tests.

**Changed:**

- `Fli` and `Avi` read only: a player writes nothing. FLI's writer moved to
  `tests/Fli_write`, what the tests read back. AVI's was left, so `Unit_avi`
  reads a clip of ffmpeg's (`tests/clips/make_clips.sh`; `make test` needs no
  ffmpeg), which also makes it a file of another writer.
- `Avi`'s sound is its rate and its samples: lib_graphics knows nothing of
  lib_audio. The player resamples.
- Pixels are `Bytes` here, ix's `Rgba_image`, not a Bigarray.
- For mini-ml: no `lazy` (`Yuv`'s two tables made at the start, 2,560 floats),
  no optional argument (`Y4m.to_string` says its chroma and range).

**Remains in the playground:** `Mpeg1`, `Mpeg1_vlc`, `Mpeg_system` (stage 2 of
the plan), `Motion` and `Mpeg1_encode` (its stage 6), and the tests of those.
