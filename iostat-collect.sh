#!/usr/bin/env bash
# Description:	Script for iostat monitoring
# Author:	Epikhin Mikhail michael@nomanlab.org
# Revision 1:	Lesovsky A.V. lesovsky@gmail.com
#
#  Hacked to always do 3 iterations of 15 seconds, to give a longer sample size.

SECONDS=$2
TOFILE=$1
IOSTAT="/usr/bin/iostat"

# be portable regarding number format
LC_ALL=C ; export LC_ALL

[[ $# -lt 2 ]] && { echo "FATAL: some parameters not specified"; exit 1; }

DISK=$($IOSTAT -x 15 3 | awk 'BEGIN {check=0;} {if(check==1 && $1=="avg-cpu:"){check=0}if(check==1 && $1!=""){print $0}if($1=="Device" || $1=="Device:"){check=1}}' | tr '\n' '|' | tr '!' '_')
echo "$DISK" | sed 's/|/\n/g' > "$TOFILE"
exit 0
