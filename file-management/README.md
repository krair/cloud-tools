# Basic File management

## smpdf

Simple tool that accepts multiple PDF files, downsizes them with reasonable ghostscript settings.

*Install*

Place the script in a location where it can be found with $PATH. I would recommend something simple like: ~/.local/bin

Ensure you have the ability to run it by ````chmod 755 smpdf.sh````

*Usage*

````smpdf <filename1.pdf> <file2.pdf> ... <fileN.pdf>````

*What it Does*
- Rename the new compressed PDF with _small at the end of the file name. Place in a subfolder called small_pdf

*Limitations*
- No checking to whether or not the file is actually a PDF to begin with
- Cannot guarantee that output file will be smaller than input depending on what it is
- Certain characters in the file name might cause the script to break
