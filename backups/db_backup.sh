#!/bin/bash

##########################################################################
# Simple script to backup docker based docker_databases
#    Currently supports MariaDB, PostgreSQL, MongoDB (basic).
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

## TODO - Nextcloud container name - add in configfile?
## TODO - Proper logging instead of echo statements
## TODO - Break into multiple scripts ( create, backup, delete )
## TODO - More complex mongodb setups ( select database(s), password protection )

# Set container environment
cenv=/usr/bin/podman

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
while read -r dbtype container user database password; do

# Create filename (container_name-database_name-YearMonthDay-HourMinute)
dbbkfile=$container-$database-`date +%Y%m%d-%H%M`
  
  # Nextcloud Maintenance mode (more flexibility needed here for container name)
  if [[ $database == "nextcloud" ]]; then
    ${cenv} exec -u www-data nextcloud php occ maintenance:mode --on
  fi

  ### Backup depending on database type

  # MariaDB
  if [[ $dbtype == "mysql" ]]; then
    # set password to correct env var if "file" or "env"
    if [[ $password == "file" ]]; then
      password='`cat $MARIADB_PASSWORD_FILE`'
    elif [[ $password == "env" ]]; then
      password='$MARIADB_PASSWORD'
    fi
    # set file extension
    ext=.sql.gz
    # create the backup file
    ${cenv} exec ${container} bash -c 'mariadb-dump --single-transaction -u '"${user}"' -p'"${password}"' '"${database}"'' | gzip > $dbbkdir/$dbbkfile$ext

  # PostgreSQL
  elif [[ $dbtype == "pgsql" ]]; then
    # set file extension
    ext=.bak.gz
    # create the backup file
    ${cenv} exec ${container} bash -c 'pg_dump '"$database"' -U '"$user"'' | gzip > $dbbkdir/$dbbkfile$ext

  # MongoDB
  elif [[ $dbtype == "mongo" ]]; then
    # set file extension
    ext=.mdb.gz
    # create the backup file
    ${cenv} exec ${container} bash -c 'umask 077; mongodump; tar -czf '"$dbbkfile$ext"' /dump'
    ${cenv} cp ${container}:/${dbbkfile}${ext} ${dbbkdir}
    ${cenv} exec ${container} bash -c 'rm '"$dbbkfile$ext"''


  # catch errors and wrong types
  else
    echo "Sorry, I don't know how to backup $dbtype. Did you mean 'mysql', 'pgsql', or 'mongo'?"
  fi

  # Check backup success (file exists and is non-zero)
  if [ $(stat -c %s $dbbkdir/$dbbkfile$ext) -gt 1000 ]; then
    echo "*******$container-$database backup is good***********"
  else
    echo "========ERROR WITH $container-$database========"
    ## Send ntfy notification for bad db backups
    # curl -H tags:warning -H prio:high -d "Restic DB ${container}-${database} backup failed" ntfy.sh/backups
  fi

  # Nextcloud maintenance mode off
  if [[ $database == "nextcloud" ]]; then
    ${cenv} exec -u www-data nextcloud php occ maintenance:mode --off
  fi
done

# Perform restic backup via script
/bin/bash $home/restic_backup.sh
# OR use the following to get ntfy notifications (change the ntfy.sh link to your preference)
#/bin/bash $home/restic_backup.sh \
#  && curl -H prio:low -d "Restic backup succeeded" ntfy.sh/backups \
#  || curl -H tags:warning -H prio:high -d "Restic backup failed" ntfy.sh/backups
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
