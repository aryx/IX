# Plan: video, the historical formats, played by mini-play (`lib_graphics/videos/`)

The author (2026-10-30), after plan_apps.md: "support mpeg and play them
with 'play' or via the new file manager"; "I think the ~/playground has
code to play simple videos; we don't have in IX to support all formats,
but the historical one, that have great teaching value, we should
definitely do".

**Status: stages 1 and 2 done, stage 3 counted but not run on a board** (`lib_graphics/videos/`, `apps/music/play/Film`). The file manager that opens these
files is [`plan_files.md`](done/plan_files.md).

## The measure

Not the films a user has (H.264 and later, for which they still have
mpv on Linux), but the formats that found each idea. plan_apps.md held
this against video as a catch; the author's answer is that teaching
value is the reason. A film of one's own is converted once:

    ffmpeg -i film.mp4 -c:v mpeg1video -c:a mp2 -f mpeg film.mpg

## The formats

| Format | Year | What it teaches | In the playground |
|---|---|---|---|
| Y4M | 2001 | how big raw video is; YCbCr, colour at a quarter of the resolution | yes |
| animated GIF | 1989 | a frame as a patch on the one before | already in ix (`Gif.frames`) |
| FLI, FLC | 1989 | delta frames, DOS's cut-scenes | yes |
| AVI, Motion JPEG | 1992 | a container apart from its codec; sound interleaved | yes |
| MPEG-1 video | 1993 | motion compensation; I, P and B frames; stored order against shown order | yes |
| MPEG-1 system stream, `.mpg` | 1993 | picture and sound multiplexed, kept in step by clocks | yes |

Later, each only if it teaches what these do not:

- **Cinepak** (1991-92), vector quantization, the CD-ROM era's codec:
  the one idea here none of the above shows. Not in the playground.
- **H.264** (2003), "the leap": intra prediction, an integer transform,
  a deblocking filter, CABAC. Large, and a plan of its own if ever.

Not taken: H.261 (MPEG-1 is its skeleton and more), MPEG-2 (mostly
interlace and higher rates, no new idea), and the others after H.264,
which refine it.

## What is copied

From the playground's `libs/graphics/videos/` (2,573 lines with their
`.mli`, counted 2026-10-30, at `f115b73e`):

| Module | Lines, `.ml` + `.mli` | Taken |
|---|---|---|
| `Yuv`, `Psnr` | 119 + 75, 25 + 24 | yes (`Psnr` for the tests) |
| `Y4m` | 104 + 51 | yes |
| `Movie`, a film as a player sees it | 64 + 54 | yes |
| `Fli` | 389 + 81 | reading only |
| `Avi` | 186 + 72 | reading only |
| `Mpeg1`, `Mpeg1_vlc` | 453 + 114, 117 + 35 | yes |
| `Mpeg_system` | 75 + 59 | yes |
| `Mpeg1_encode`, `Motion` | 310 + 48, 70 + 48 | not at first |

Its unit tests come too (`Unit_mpeg1`, `Unit_avi`, `Unit_fli`,
`Unit_movie`), and its clips: `ball_and_square.mpg` is 71,680 bytes and
its `.expected.y4m` 86,496, ffmpeg's encoding of a clip the playground
drew, checked in as data, so `make test` needs no ffmpeg. From
`apps/media/`: `Media` (shared with plan_files.md), and of
TinyMediaPlayer (521 lines) what shows a film and the analyzer.

The encoder is left out by the rule of copying what is needed: a player
does not call it. It is the first thing to add afterwards, since motion
search is half of the subject's teaching, and it would let ix make its
own clips.

The folder gets its README (copied, changed, what remains), from
`scripts/playground_copies.sh`.

## mini-play with a window

`mini-play film.mpg` is what one types, as the author asks. mini-play
today is a filter of sound, with no window and no `lib_playground`.

    the file's kind --> sound: as today, to /dev/audio or -c
                    --> film:  a window, a Playground program:
                               the picture, its sound through Audio

**One program** (the author's "play"), so it links the graphics, and is
larger on the card; to be measured in stage 2. If that hurts, a second
program that mini-play starts, 9front's way, changes nothing for the
user. `-c` stays sound only.

**The sound's clock**: the picture follows the sound, not the other way
round, because a skipped frame is hardly seen and a skipped sound is
always heard. TinyMediaPlayer already does so (`Movie.index_at` from
the deck's position), and mini-rebirth already has sound and a window
together on mini-9pi. A film without sound runs on the frame's timer.

Keys: space pauses, the arrows seek (MPEG-1 by its groups of pictures;
why a decoder only goes forward is in `Movie.mli`).

**The analyzer**, the teaching: `d` dims what did not change, `a` draws
the macroblocks and their vectors, `r` shows what was sent. No other
player shows this, and it is why ix has video at all. These keep.

## Speed

Not measured on ix, and the plan's real risk: MPEG-1 at 320x240 and 25
frames a second is 300 macroblocks a frame on a Pi. Stage 3 measures
it, with the playground's `Mpg_bench` (demultiplexing, sound, frames
apart), on the Pi 2 first, then on the Pi 1; mini-qemu `-ips 200` before
the boards. Frames dropped by the sound's clock are the fallback, and a
slow Pi 1 showing few frames is acceptable. Optimizations come separately and
switchable, with their `old:` kept.

## Stages

1. **The simple ones**: `Yuv`, `Y4m`, `Movie`, `Fli`, `Avi` and animated
   GIF in `lib_graphics/videos/`; mini-play's window; recorded frames.
2. **MPEG-1**: `Mpeg1`, `Mpeg1_vlc`, `Mpeg_system`, with MP2 from
   `lib_audio` (`Mpeg_audio` reads layer II already), kept in step;
   tests against the clips' expected frames. On the card, a clip there.
3. **Speed**, measured as above.
4. **The analyzer's keys**, and seeking.
5. **Everyone opens them**: mini-files' table, and mini-netscape's
   built-in helper rule, `video/mpeg` and `video/x-msvideo` to mini-play.
6. **The encoder** (`Motion`, `Mpeg1_encode`), then Cinepak if wanted.

Everything is compiled by mini-ml from stage 1. Estimate: about 1,500
lines of `.ml` for the library, from the table, and 300 to 500 for the
window, an estimate. A real film converted by ffmpeg is tried by hand at
stage 2; the playground's clip is tiny and hides what a real stream does.

## Open questions

- MPEG-1 real streams: does the decoder read ffmpeg's and others' as
  they come? The playground's `ffmpeg_muxed.mpg` says yes for one.
- Which clips go on the card, and how big (a real film will not fit
  the card's budget as it is).

## Status

2026-10-30: plan written. Nothing built.

2026-10-31: stage 1 done. `Yuv`, `Psnr`, `Y4m`, `Movie`, `Fli`, `Avi` in
`lib_graphics/videos/` (its README says what changed), and `mini-play clip`
opens a window on a film by its first bytes, GIF too; space pauses, q
leaves. The picture follows the sound, a timer until the sound has begun, so
a machine with no sound does not stay on frame 0. `mini-play` is now one
program of 2.0 MB on Plan 9, by `mini-mk O=5 OS=plan9`.
Bytes are not the same from the two compilers on a JPEG: blue off by one in
681 pixels of a million, float IDCT and OCaml's fused multiply-add, so the AVI
frame's sum is recorded for dune's alone. Not run: a film under mini-rio on
mini-9pi; sound heard, here it is only dumped (`-dump-audio`).

Stage 2 done: `Mpeg1`, `Mpeg1_vlc`, `Mpeg_system`, and `mini-play film.mpg`
with its MP2, in step; `Bitstream` and `Vlc` moved to `lib_compression`,
shared by MPEG's sound and pictures; `/lib/videos/ball.mpg` on the card. The
open question answered for one more stream: a film ffmpeg made from the
Mandelbrot zoom (320 by 240, 25 frames a second, 800 kbit/s, I, P and B
frames, MP2) plays right, by eye and within 32.7 to 35.1 dB of ffmpeg's frames,
a lower bound since measured through the window's scaling. On this machine, the
first 71 of its frames, in a run of 170 screens with the window's drawing:
0.77 s by OCaml, 1.23 s by mini-ml, 60% more. Stage 3 is what matters: a Pi.
A film's sound is decoded whole when it opens, which a Pi will feel.

Stage 3, counted (`apps/music/play/Mpg_bench` under `mini-5i -s`, arm, a real
film of ffmpeg's, 320 by 240, 800 kbit/s; a part is a run less the run before):

| The part | Instructions |
|---|---|
| the file read and demultiplexed, a second of film | 4.3 million |
| its sound decoded, a second | 111.7 million |
| a picture, before | 82.1 million (frames 4 to 8) |
| a picture, whole-number colours | 66.4 million, 19.1% fewer |

`mini-prof` said colour conversion was 31% of a frame, floats boxed and a call
a byte: `Yuv.to_image_whole` (`Opti.enabled`; the floats kept beside it, within
one of them, tested). What is left is spread: motion prediction 19%, colours
14.4%, putting blocks 9.3%, the IDCT 8.9%, reading bits about 15%.

What it means, by arithmetic, not measured: 25 pictures a second is 1,660 million
instructions, before the drawing; at the 1,400 million a second that
plan_playground_speed.md guesses of a Pi 2's integers, some 21 pictures a
second, and fewer since its floats are slower and the IDCT is floats; at
mini-qemu's `-ips 200`, 3. So a 320 by 240 film will likely drop frames on a
Pi 2 and more on a Pi 1, which the sound's clock is there for. A minute's sound
decoded when the film opens is 6,700 million instructions, some 5 seconds of
waiting on a Pi 2: to decode it as it plays would be the next thing to do.
**Not run: `mini-qemu -ips 200`, a Pi.** mini-9pi could not be built while
another session's `debuggers/acid` was in progress.
