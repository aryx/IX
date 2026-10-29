# lib_playground/netcode: a game played on several computers

The author's playground's `libs/networking/netcode` (`~/playground`),
with two modules of its `libs/networking/protocols`: under `apis/`'s
`Multiplayer`, for `games/arcade/TinyTronscroll`. A library of its own
(`ix_netcode`; old: `lib_networking/netcode/`, moved here, its only
user the playground), over lib_networking's `tcp/Udp` and the
playground's `Lehmer`.

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_playground/netcode`'s.

## What was copied (2026-10-13)

Against the playground at `514f259c`: 7 modules, 626 lines of `.ml`
and 550 of `.mli` there, 617 and 551 here.

| module | there | what |
|---|---|---|
| `Wire` | `libs/networking/protocols` | a message's bytes: varints, zigzag, garbage refused |
| `Inputs` | `libs/networking/netcode` | the players' inputs exchanged, their acks and checksums |
| `Lockstep` | the same | wait for every input; an input delay |
| `Rollback` | the same | guess the missing ones, play again from a wrong guess |
| `Checksum` | the same | FNV-1a of a model's bytes: do two games agree |
| `Sim_net` | the same | a network in one program: latency, jitter, loss, from a seed |
| `Transport` | `libs/networking/protocols` | where a peer's packets go |

## What changed

`Rollback.create`'s two optional arguments are said; two
`Option.value ~default` in `Sim_net`. `Transport` is the playground's
type, and under it the playground's `unix/Udp`'s host and join over
ix's `Udp` (lib_networking's `tcp/`, its README): `connect` is called,
where a platform of the playground's installs it; no relay (a
WebSocket), no TLS.

## What remains in the playground

`Snapshot`, `Prediction`, `Interpolation` (a server that owns the
game: `netcode=server`, in one window only there too), the relay and
its server, their tests (`Unit_lockstep`, `Unit_rollback`,
`Unit_sim_net`, `Unit_wire`, `Unit_checksum`: here
`games/tests/frames.sh` has the playground's golden frames of the game
over them, and `games/tests/network.sh` two programs over UDP).
