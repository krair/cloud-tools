#!/bin/bash

#########################################################################
# Restic backup script
#
# Written by: Kit Rairigh - https://github.com/krair - https://rair.dev
##########################################################################

set -e

# Set repo directory (to allow for multiple backup repos)
#   Ex: /home/restic/files and /home/restic/photos
repo_dir=${REPO_DIR:-/home/restic}

# Get env variables for restic written into restic.env file
source $repo_dir/restic.env

# Set restic binary location - read RESTIC_BIN env var, or use default
restic_bin=${RESTIC_BIN:-/home/restic/bin/restic}

# Create logfiles
touch $repo_dir/restic.err
touch $repo_dir/restic.log

# Mark logfiles with date
echo -e "\n==== `date` ====\n" >> $repo_dir/restic.err
echo -e "\n==== `date` ====\n" >> $repo_dir/restic.log

# Ensure our repo is initialized and reachable - if unreachable, the script will give a non-zero exit code which we can use for notifications, etc.
$restic_bin cat config > /dev/null

# Backup using restic.files and restic.exclude, tagged, errors and output to log
$restic_bin backup --files-from=$repo_dir/restic.files --exclude-file=$repo_dir/restic.exclude --tag automated 2>> $repo_dir/restic.err >> $repo_dir/restic.log

# Pruning snapshots to only keep last 7 daily, last 4 weekly, 12 monthly, 10 yearly
#     - Will also repack using the --prune switch
$restic_bin forget -d 7 -w 4 -m 12 -y 10 --prune

# Double check data integrity (2.5% to reduce data transfer)
$restic_bin check --read-data-subset=2.5%

exit 0
