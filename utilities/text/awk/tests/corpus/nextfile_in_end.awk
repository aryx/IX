# nextfile in END: ends the action (Plan 9 checks only break, next and
# continue there)
{ print "record", $0 }
END { print "end"; nextfile; print "after" }
