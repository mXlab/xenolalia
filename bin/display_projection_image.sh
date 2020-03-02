#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 primary_screen_width image_file"
	echo "  NOTE: To get primary screen width run: xrandr"
	exit
fi

primary_screen_width="$1"
image_file="$2"

pqiv -f -P $primary_screen_width,0 $image_file
