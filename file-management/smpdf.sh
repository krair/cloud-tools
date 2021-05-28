#!/bin/bash

# Small script to optimize pdf's quickly
# Depends on ghostscript
# Written by Kit Rairigh - https://github.com/krair - https://rair.dev

set -e

# Check for number of files given, add to variable
if (( $# > 0 )); then
## TODO - Add a check to make sure file is a PDF, file(s) exist, etc.
files=("$@")
else
echo "Please provide at least 1 valid filename"
fi

# Create a subdirectory titled small_pdf to store the downsized pdfs
if [[ ! -d "./small_pdf" ]]; then
mkdir ./small_pdf
fi

# Downsize each file, save in above directory, add _small to the end of the filename
for ((i = 0; i < ${#files[@]}; i++))
do
	# If a name is not a valid file, continue
	if [[ ! -f "${files[$i]}" ]];then continue
	fi
	# get filename
	fname=$(basename "${files[$i]}" .pdf)
  # use ghostscript with reasonable balance between size and quality
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=./small_pdf/"${fname}"_small.pdf "${files[$i]}"

	echo "${files[$i]} resized"

done
