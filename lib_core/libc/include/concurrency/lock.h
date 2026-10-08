/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
typedef struct Lock Lock;
struct Lock {
    long    key;
    long    sem;
};

extern  void    lock(Lock*);
extern  void    unlock(Lock*);
extern  int     canlock(Lock*);
