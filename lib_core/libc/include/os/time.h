/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
typedef struct Tm Tm;
struct Tm {
    int sec;
    int min;
    int hour;

    int mday;
    int mon;
    int year;
    int wday;
    int yday;

    char    zone[4];
    int     tzoff;
};

extern  long    time(long*);
extern  vlong   nsec(void);

extern  Tm*     gmtime(long);
extern  Tm*     localtime(long);

extern  double  cputime(void);

extern  long    tm2sec(Tm*);

extern  char*   asctime(Tm*);
extern  char*   ctime(long);

/* alarm(ms): a note "alarm" in ms milliseconds, once; gives what was
 * left of the one before; 0 cancels. Plan 9's call. */
extern	long	alarm(ulong);
extern	int	sleep(long); //less: could be void (ulong). 0 means yield.
