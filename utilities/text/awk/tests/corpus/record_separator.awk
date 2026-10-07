BEGIN { RS = ";" }
{ print NR, $0, NF }
