BEGIN { RS = "" }
{ print NR ": " $1 "-" $NF " (" NF ")" }
