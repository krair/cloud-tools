# ***Restic Backups***

The files here are used in conjunction to create an off-site s3 backup.

This is still a work in progress, and is what I use on a daily basis via a cron job.

As I write an article on https://rair.dev on Intermediate level backups for Nextcloud,
these files will be updated to be more flexible with more installations.

This is heavily based upon the example given in the restic docs:
https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root

## restic_backup.sh

This is the main backup script. Nothing fancy here. Requires:
- User named restic
- A **restic.env** file with the required access keys, passwords, and URL
- A **restic.files** file - these are the files and directories to be backed up
- A **restic.exclude** file - these are the files we want to exclude during our backup

## db_backup.sh

Script to automate backing up of any docker database.

For now the script is set to only use docker secrets stored in *_FILE environment
variables. I plan to add more flexibility to this soon.

For now the script only supports MariaDB (MySQL), PostgreSQL and mongodb databases. They
must be set manually in the **docker_databases** file.
- For MariaDB or MySQL, use "mysql" as the Db-type
- For PostgreSQL, use "pgsql" as the Db-type
- For MongoDB, use "mongo"as the Db-type

## Usage

Follow the link above. You should have a user named `restic` with a home directory
located at `/home/restic`.

You should have the `restic` binary located in `/home/restic/bin/`.

Give your `restic` user access to docker containers by adding the user to the
`docker` group.

Ensure the companion files (listed above) are completed and correct. I have some
examples in each file to give you an idea of what is required.

The current iteration of the **db_backup.sh** script already calls the
**restic_backup.sh** as part of it to ensure the databases are backed up, and then
deleted after to not leave raw databases accessible to anyone.

All of the files here should be in the `/home/restic/`.

Create a `cron` job for the `restic` user to run the script daily like:

`0 2 * * * /home/restic/db_backup.sh 2>&1 | /usr/bin/logger -t resticdbbkup`

This will run a backup at 2AM daily using the db_backup.sh script. It will also
log everything to `syslog` and is easy to find as it is tagged with `resticdbbkup`
