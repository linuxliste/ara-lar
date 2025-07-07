#!/bin/bash
if [ -n "$1" ]
then
	userfile=$1
else
	userfile=user_list.txt
fi

if [ ! -f $userfile -o ! -r $userfile ]
then
	echo "error: unable to read $userfile"
	exit -1
fi

for u in $(grep -v '^#' $userfile)
do
	username="$(echo $u | cut -d: -f1)"
	password="$(echo $u | cut -d: -f2)"
	maxpwage="$(echo $u | cut -d: -f3)"
	supgroup="$(echo $u | cut -d: -f4)"

	useradd -G $supgroup -K PASS_MAX_DAYS=$maxpwage $username
	echo "$password" | passwd --stding $username
done

