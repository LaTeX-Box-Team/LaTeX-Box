#!/bin/bash
#Helper script for synctex backward search with zathura
# $1 : v:progname
# $2 : v:servername
# $3 : %{page+1}
# $4 : %{output}
zathura -s -x "$1 --servername $2 --remote-expr 'LatexBox_Synctex_Backward(\"%{input}\",%{line})'" -P $3 $4
