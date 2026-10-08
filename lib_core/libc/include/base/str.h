/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
/*
 * string routines (provided by system <string.h>)
 */

// memxxx equivalent, but with special handling for '\0' (no need pass ulong)

extern  long    strlen(char*);
extern  int     strcmp(char*, char*);
extern  char*   strcpy(char*, char*);
extern  char*   strchr(char*, int);
extern  char*   strdup(char*);
extern  char*   strstr(char*, char*);
extern  char*   strcat(char*, char*);
extern  char*   strrchr(char*, int);
extern  char*   strncpy(char*, char*, long);
extern  int     cistrcmp(char*, char*);

// copies in [s1, e1), a 0 always before e1; gives where the 0 is
extern  char*   strecpy(char*, char*, char*);

extern  int     strncmp(char*, char*, long);
extern  int     tokenize(char*, char**, int);
extern  int     gettokens(char*, char**, int, char*);

