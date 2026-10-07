FNR == 2 { nextfile }
{ print FILENAME, FNR, $1 }
END { print NR }
