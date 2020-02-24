#!/bin/bash
if [ $# -ne 2 ];
then
 echo "Syntax: $(basename $0) <username> <password>"
 exit 1
fi

lftp -c "set ftp:list-options -a;
open ftp://$1:$2@ftp.koumbit.net; 
lcd ~/xenolalia/XenoPi/snapshots;
mirror --reverse --use-cache --allow-chown --allow-suid --no-umask --parallel=2 --exclude-glob .git"
