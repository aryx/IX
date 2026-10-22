/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* The reference's platform (build.sh): id's Doom (9front's
 * sys/src/games/doom, linuxdoom of 1997 made 64-bit clean) with no
 * window, no sound and no clock but its own, for ../compare.sh. Its
 * i_main.c, i_video.c and i_sound.c are this file.
 *
 * At tic REF_TIC (10 by default) of the level, the player is put at
 * (REF_X, REF_Y) looking at REF_ANGLE degrees, still, on the floor
 * under his box (P_TeleportMove: as a move finds it, as mini-doom's
 * Play.place); the view made the whole screen (no status bar), no
 * weapon; the lights that flicker held at their level (mini-doom's
 * generator is not id's table); the level's time 0 from then on (the
 * animated flats at their first frame, as mini-doom's first frame); with
 * REF_NOTHINGS, no thing but the player. Two frames later the screen,
 * through the palette, is written as a PPM to REF_OUT, and the program
 * ends. */

#include "doomdef.h"
#include "doomstat.h"
#include "m_argv.h"
#include "d_main.h"
#include "i_system.h"
#include "i_video.h"
#include "i_sound.h"
#include "v_video.h"
#include "r_main.h"
#include "p_local.h"
#include "g_game.h"
#include "s_sound.h"
#include "p_spec.h"

void T_FireFlicker(void *, void *);
extern int leveltime;

/* a 35th of a second each time it is asked: the game never waits */
static long long fake;
long long nsec(void) { fake += 1000000000LL / TICRATE; return fake; }

static byte pal[768];
void I_InitGraphics(void) {}
void I_ShutdownGraphics(void) {}
void I_SetPalette(byte *p) { memcpy(pal, p, 768); }
void I_UpdateNoBlit(void) {}
void I_MouseEnable(int on) {}
void I_ReadScreen(byte *scr) { memcpy(scr, screens[0], SCREENWIDTH*SCREENHEIGHT); }
void I_BeginRead(void) {}
void I_EndRead(void) {}
void I_WaitVBL(int c) {}
void I_StartFrame(void) {}

static int placed = 0;

static void
hold(sector_t *s, int maxlight, thinker_t *th)
{
	s->lightlevel = maxlight;
	th->function = NULL;
}

void I_StartTic(void)
{
	char *t = getenv("REF_TIC");
	thinker_t *th;
	mobj_t *mo;

	/* (the animated textures and flats at their first frame, at each tic) */
	if (placed)
		leveltime = 0;
	if (gamestate != GS_LEVEL || placed || gametic < (t ? atoi(t) : 10))
		return;
	mo = players[0].mo;
	P_TeleportMove(mo, atoi(getenv("REF_X")) << FRACBITS, atoi(getenv("REF_Y")) << FRACBITS);
	mo->z = mo->floorz;
	mo->angle = (angle_t)(atof(getenv("REF_ANGLE")) / 360.0 * 4294967296.0);
	mo->momx = mo->momy = mo->momz = 0;
	players[0].viewheight = VIEWHEIGHT;
	players[0].deltaviewheight = 0;
	players[0].psprites[0].state = NULL;
	players[0].psprites[1].state = NULL;
	R_SetViewSize(11, 0);
	leveltime = 0;
	for (th = thinkercap.next; th != &thinkercap; th = th->next) {
		if (th->function == (think_t)T_LightFlash) hold(((lightflash_t *)th)->sector, ((lightflash_t *)th)->maxlight, th);
		else if (th->function == (think_t)T_StrobeFlash) hold(((strobe_t *)th)->sector, ((strobe_t *)th)->maxlight, th);
		else if (th->function == (think_t)T_Glow) hold(((glow_t *)th)->sector, ((glow_t *)th)->maxlight, th);
		else if (th->function == (think_t)T_FireFlicker) hold(((fireflicker_t *)th)->sector, ((fireflicker_t *)th)->maxlight, th);
		else if (getenv("REF_NOTHINGS") && th->function == (think_t)P_MobjThinker && (mobj_t *)th != mo)
			P_RemoveMobj((mobj_t *)th);
	}
	placed = 1;
}

void I_FinishUpdate(void)
{
	static int after = 0;
	FILE *f;
	int i;

	if (!placed || ++after != 3)
		return;
	f = fopen(getenv("REF_OUT"), "wb");
	fprintf(f, "P6\n%d %d\n255\n", SCREENWIDTH, SCREENHEIGHT);
	for (i = 0; i < SCREENWIDTH*SCREENHEIGHT; i++)
		fwrite(pal + 3*screens[0][i], 1, 3, f);
	fclose(f);
	exit(0);
}

void I_InitSound(void) {}
void I_UpdateSound(void) {}
void I_SubmitSound(void) {}
void I_ShutdownSound(void) {}
void I_SetChannels(void) {}
int I_GetSfxLumpNum(sfxinfo_t *s) { return 0; }
int I_StartSound(int id, int vol, int sep, int pitch, int prio) { return 0; }
void I_StopSound(int h) {}
int I_SoundIsPlaying(int h) { return 0; }
void I_UpdateSoundParams(int h, int vol, int sep, int pitch) {}
void I_InitMusic(void) {}
void I_ShutdownMusic(void) {}
void I_SetMusicVolume(int v) {}
void I_PauseSong(int h) {}
void I_ResumeSong(int h) {}
void I_PlaySong(musicinfo_t *m, int loop) {}
void I_StopSong(int h) {}
int I_RegisterSong(void *data) { return 0; }
void I_UnRegisterSong(int h) {}
int I_QrySongPlaying(int h) { return 0; }
void I_SetSfxVolume(int v) {}

int main(int argc, char **argv) { myargc = argc; myargv = argv; D_DoomMain(); return 0; }
