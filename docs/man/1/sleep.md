\title{sleep}{1}{processes}

# NAME
sleep – a time waited

# SYNOPSIS
**sleep**
*time*

# DESCRIPTION
*Sleep* waits *time* seconds, then ends. The seconds are waited one
at a time, so an interrupt ends it within one; after a point, the
thousandths: `sleep .5` is half a second. No *time* is no wait.

# EXAMPLES
```
{sleep 100; echo done}&
while(){ date; sleep 30 }
```

# DIFFERENCES
The seconds are decimal: Plan 9's reads `0x10` and `010` as C does.

# SEE ALSO
\man{time}{1}, \man{rc}{1}; Plan 9's *sleep*(1)
