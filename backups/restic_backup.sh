#!/bin/bash

#########################################################################
# Restic backup script
#
# Written by: Kit Rairigh - https://github.com/krair - https://rair.dev
##########################################################################

# Set home directory used throughout the script
home=/home/restic

# Create logfiles
touch $home/restic.err
touch $home/restic.log

# Mark logfiles with date
echo -e "\n==== `date` ====\n" >> $home/restic.err
echo -e "\n==== `date` ====\n" >> $home/restic.log

# Get env variables for restic written into restic.env file
source $home/restic.env

# Backup using restic.files and restic.exclude, tagged, errors and output to log
$home/bin/restic backup --files-from=$home/restic.files --exclude-file=$home/restic.exclude --tag automated 2>> $home/restic.err >> $home/restic.log

# Pruning snapshots to only keep last 7 daily, last 4 weekly, 12 monthly, 10 yearly
#     - Will also repack using the --prune switch
$home/bin/restic forget -d 7 -w 4 -m 12 -y 10 --prune

# Double check data integrity (2.5% to reduce data transfer)
$home/bin/restic check --read-data-subset=2.5%

exit
