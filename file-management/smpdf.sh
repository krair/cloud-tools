#!/bin/bash

for file in `find *.pdf`

do

	fname=`basename $file | tr ' ' '_'`

	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=${fname}_small.pdf $file
	
	echo "${fname} resized"

done
