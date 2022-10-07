#!/bin/bash
if [ $# -ne 2 ];
then
 echo "Syntax: $(basename $0) <folder> <basename>"
 exit 1
fi

basedir=$1
basename=$2

# Bio only
python3 xeno_video.py --mode bio --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "${basename}_bio.gif"

#python3 xeno_video.py --mode ann --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "${basename}_ann_bw.gif"
# ANN only (white on black).
python3 xeno_video.py --mode ann --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,0,255   $basedir "${basename}_ann_bm.gif"
#python3 xeno_video.py --mode ann --fit-in-circle --ann-background 255,255,255 --ann-foreground 0,0,0 $basedir "${basename}_ann_wb.gif"

# Combination left-right.
python3 xeno_video.py --mode ann_bio_cat --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "${basename}_ann_bw_bio_cat.gif"
#python3 xeno_video.py --mode ann_bio_cat --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,0,255   $basedir "${basename}_ann_bm_bio_cat.gif"
#python3 xeno_video.py --mode ann_bio_cat --fit-in-circle --ann-background 255,255,255 --ann-foreground 0,0,0 $basedir "${basename}_ann_wb_bio_cat.gif"

#python3 xeno_video.py --mode ann_bio_seq --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,255,255 $basedir "${basename}_ann_bw_bio_seq.gif"
# Sequence with magenta image.
python3 xeno_video.py --mode ann_bio_seq --fit-in-circle --ann-background 0,0,0 --ann-foreground 255,0,255   $basedir "${basename}_ann_bm_bio_seq.gif"
#python3 xeno_video.py --mode ann_bio_seq --fit-in-circle --ann-background 255,255,255 --ann-foreground 0,0,0 $basedir "${basename}_ann_wb_bio_seq.gif"

