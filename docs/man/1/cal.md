\title{cal}{1}{time}

# NAME
cal – a calendar

# SYNOPSIS
**cal**
[ *month* ]
[ *year* ]

# DESCRIPTION
*Cal* writes a month's days under the days of the week, or a year's
twelve months, three a row. With nothing, this month. One argument
is a month of this year when it is 1 to 12 or a month's name (`jan`,
`january`, `sept`), or else a year, 1 to 9999, all of it; two are a
month and a year. A year is as typed: `cal 90` is the year 90.

The calendar is England's: Julian until September 1752, which goes
from the 2nd to the 14th, Gregorian after.

# EXAMPLES
```
cal
cal sep 1752
cal 2026
```

# DIFFERENCES
The same lines as Plan 9's, byte for byte. "This month" is GMT's:
`/env/timezone` is not read.

# SEE ALSO
\man{date}{1}; Plan 9's *cal*(1)
