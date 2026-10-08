/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */

/* What convM2D.c and convD2M.c need of Plan 9's fcall.h: the sizes and
 * the bytes of the format fstat and fwstat speak, as principia's. */

#define BIT8SZ		1
#define BIT16SZ		2
#define BIT32SZ		4
#define BIT64SZ		8
#define QIDSZ		(BIT8SZ+BIT32SZ+BIT64SZ)
/* the part of fixed length: a count, a Qid, the mode, two times, the
 * length, and the lengths of the four strings that follow */
#define STATFIXLEN	(BIT16SZ+QIDSZ+5*BIT16SZ+4*BIT32SZ+1*BIT64SZ)

#define GBIT8(p)	((p)[0])
#define GBIT16(p)	((p)[0]|((p)[1]<<8))
#define GBIT32(p)	((p)[0]|((p)[1]<<8)|((p)[2]<<16)|((p)[3]<<24))
#define GBIT64(p)	((uint)((p)[0]|((p)[1]<<8)|((p)[2]<<16)|((p)[3]<<24)) |\
			 ((uvlong)((p)[4]|((p)[5]<<8)|((p)[6]<<16)|((p)[7]<<24)) << 32))

#define PBIT8(p,v)	(p)[0]=(v)
#define PBIT16(p,v)	do{(p)[0]=(v);(p)[1]=(v)>>8;}while(0)
#define PBIT32(p,v)	do{(p)[0]=(v);(p)[1]=(v)>>8;(p)[2]=(v)>>16;(p)[3]=(v)>>24;}while(0)
#define PBIT64(p,v)	do{(p)[0]=(v);(p)[1]=(v)>>8;(p)[2]=(v)>>16;(p)[3]=(v)>>24;\
			 (p)[4]=(v)>>32;(p)[5]=(v)>>40;(p)[6]=(v)>>48;(p)[7]=(v)>>56;}while(0)

extern uint	convM2D(uchar*, uint, Dir*, char*);
extern uint	convD2M(Dir*, uchar*, uint);
extern uint	sizeD2M(Dir*);
extern int	statcheck(uchar*, uint);
