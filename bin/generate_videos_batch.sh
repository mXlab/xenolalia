#!/bin/bash
if [ $# -ne 1 ];
then
 echo "Syntax: $(basename $0) <batchfile>"
 exit 1
fi

batchfile=$1
basedir="./XenoPi/snapshots/"

for id in `cat $batchfile`; do
  echo "# $id #"
  expdir="${basedir}/${id}"
  bash generate_videos.sh $expdir $id
done