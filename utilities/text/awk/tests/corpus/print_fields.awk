{ print }
{ print $1, $3 }
{ print $NF, $(NF-1), $(1+1), $NF-1 }
{ print NR, FNR, NF, FILENAME "|" }
END { print NR, $0 "|", NF }
