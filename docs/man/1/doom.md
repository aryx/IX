\title{doom}{1}{games}

# NAME
doom – a walk through a level of Doom's

# SYNOPSIS
**doom**
[ **wad=***file* ]
[ **map=***name* ]
[ **scale=***n* ]
[ **monsters** ]
[ **x=***x* **y=***y* **angle=***a* ]
[ **lumps** ]

# DESCRIPTION
*Doom* draws a level of a WAD, Doom's file of levels and pictures, as
id Software's game of 1993 drew it: its walls, floors and ceilings
textured, its sky, its light darker with the distance, its things.
The doors open, the lifts go down and up, the switches turn, and the
exit ends the level. No monster moves and no weapon fires.

The WAD is */lib/doom/freedoom.wad* by default, the first level of
Freedoom's, the free game of Doom's format.

In the window:

The arrows, `w`, `s`
:    Walk, turn; shift held, run.

`a`, `d` (Doom's `,` and `.`)
:    A step aside.

Space, `e`
:    Use: a door, a switch, a lift ahead.

**wad=**
:    Another WAD: Freedoom's whole one, or id's (*doom1.wad*, the
     shareware's).

**map=**
:    Its level of that name (*E1M2*, *MAP01*); the first by default.

**scale=**
:    Each of Doom's 320 by 200 pixels drawn *n* by *n* (1 to 4; 1 by
     default on Plan 9, 2 elsewhere). On the Raspberry Pi, 2 is a
     frame or two a second.

**monsters**
:    The level's monsters, standing.

**x=**, **y=**, **angle=**
:    The player there, looking that way, in degrees.

**lumps**
:    No window: the WAD's lumps, a line each, and the end.

# EXAMPLES
```
doom
doom wad=/lib/doom/doom1.wad 'map=E1M2'
```
(rc reads `=`: a word that has one is quoted.)

# DIFFERENCES
id's game has the monsters, the weapons, the sounds, the music, the
menus, the status bar, the saved games and the network; this one a
level, walked. Its pictures are id's but for a texel or a light level
here and there (its arithmetic is floats where id's was fixed point).

# SEE ALSO
\man{rio}{1}; 9front's *doom*(1)

# DIAGNOSTICS
A file that is no WAD, or a level not in it, is said, and the status is
1.
