#!/bin/bash

##########################################################################
# Simple script to backup docker based docker_databases
#    Currently supports MYSQL (and MariaDB) and PostgreSQL
#
#    Special treatment for Nextcloud - maintenance mode
#
# Written by: Kit Rairigh - https://github.com/krair - https://rair.dev
##########################################################################

# Following the example set in the restic docs to create a separate user:
# https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root

# This script relies on a separate docker_databases file to input
#    a list of which databases you would like backed up. Please make sure
#    that file exists in the same directory as this script

## TODO - Add support for more password context (secret, env, other)
## TODO - Nextcloud container name - add in configfile?
## TODO - Proper logging instead of echo statements

# Set home directory - see restic user setup per the restic link above
home=/home/restic
# Select config file
configfile=$home/docker_databases
[ $# -gt 0 ] && [ -r "$1" ] && configfile="$1"

# For added security, reduce permissions
umask 077

# Set database backup directory
mkdir /tmp/dbbackup
dbbkdir=/tmp/dbbackup

# Strip white space and comments from config file before passing it
sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "$configfile" |
# grab vars from config file
while read -r dbtype container user database; do
# Create filename (container_name-database_name-YearMonthDay-HourMinute)
dbbkfile=$container-$database-`date +%Y%m%d-%H%M`
  # Nextcloud Maintenance mode (more flexibility needed here for container name)
  if [[ $database == "nextcloud" ]]; then
    /usr/bin/docker exec -u www-data nextcloud php occ maintenance:mode --on
  fi
  ### Backup depending on database type
  # MySQL & MariaDB (using docker secrets)
  if [[ $dbtype == "mysql" ]]; then
    ext=.sql.gz
    /usr/bin/docker exec ${container} bash -c 'mysqldump --single-transaction -u '"${user}"' -p`cat "$MYSQL_PASSWORD_FILE"` '"${database}"'' | gzip > $dbbkdir/$dbbkfile$ext
  # PostgreSQL
  elif [[ $dbtype == "pgsql" ]]; then
    ext=.bak.gz
    /usr/bin/docker exec ${container} bash -c 'pg_dump '"$database"' -U '"$user"'' | gzip > $dbbkdir/$dbbkfile$ext
  # catch errors and wrong types
  else
    echo "Sorry, I don't know how to backup $dbtype"
  fi
  # Check backup success (file exists and is non-zero)
  if [[ -s $dbbkdir/$dbbkfile$ext ]]; then
    echo "*******$container-$database backup is good***********"
  else
    echo "========ERROR WITH $container-$database========"
  fi
  # Nextcloud maintenance mode off
  if [[ $database == "nextcloud" ]]; then
    /usr/bin/docker exec -u www-data nextcloud php occ maintenance:mode --off
  fi
done

# Perform restic backup via script
(exec $home/restic_backup.sh)
echo "============backup complete============"

# Delete database dump for security
rm -r $dbbkdir
if [[ -d $dbbkdir ]]; then
  echo "========TEMP BACKUPS NOT DELETED!======="
else
  echo "*********$dbbkdir successfully deleted***********"
fi
echo "=========FINISHED========"

exit
