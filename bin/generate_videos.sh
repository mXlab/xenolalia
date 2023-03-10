#!/bin/bash
if [ $# -ne 1 ];
then
 echo "Syntax: $(basename $0) <basename>"
 exit 1
fi

basename=$1
basedir="./XenoPi/snapshots/$basename"
outputdir="./contents/$basename"

mkdir -p "$outputdir"

# Bio only
python3 xeno_video.py --mode bio --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "$outputdir/${basename}_bio.gif"

# ANN only (white on black).
python3 xeno_video.py --mode ann --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,0,255   $basedir "$outputdir/${basename}_ann.gif"

# Combination left-right.
python3 xeno_video.py --mode ann_bio_cat --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "$outputdir/${basename}_ann_bio_cat.gif"

# Sequence with magenta image.
python3 xeno_video.py --mode ann_bio_seq --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,0,255   $basedir "$outputdir/${basename}_ann_bio_seq.gif"

# Single images
python3 xeno_video.py --mode ann_single --fit-in-circle --ann-background 255,255,255 --ann-foreground 0,0,0   $basedir "$outputdir/${basename}_ann_final.png"
python3 xeno_video.py --mode bio_single --fit-in-circle $basedir "$outputdir/${basename}_bio_final.png"

# All single images.
python3 xeno_video.py --mode ann_all --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "$outputdir/${basename}_ann_%d.png"
python3 xeno_video.py --mode bio_all --fit-in-circle $basedir "$outputdir/${basename}_bio_%d.png"
