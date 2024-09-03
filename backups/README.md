# ***Restic Backups***

The files here are used in conjunction to create an off-site s3 backup. This can of course be modified to be more flexible for other backup backends (like rclone for example.)

These scripts are what I use on a daily basis to create incremental backups via a `cron` job.

I wrote an article on https://rair.dev on incremental backups for Nextcloud running both on a bare-metal host as well as for a containerized installation.

This is heavily based upon the example given in the restic docs:
https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root

## restic_backup.sh

This is the main backup script. Nothing fancy here. Requires:
- A **restic.env** file with the required access keys, passwords, and URL
- A **restic.files** file - these are the files and directories to be backed up
- A **restic.exclude** file - these are the files we want to exclude during our backup

## db_backup.sh

Script to automate backing up of containerized databases.

The script can use secrets stored in "_FILE" environment variable, a plain env variable, or (not recommended) put directly into the `docker_databases` file.

For now the script only supports MariaDB , PostgreSQL and mongodb databases. They must be set manually in the **docker_databases** file.
- For MariaDB, use "mariadb" as the Db-type
- For PostgreSQL, use "pgsql" as the Db-type
- For MongoDB, use "mongo"as the Db-type

## Usage

### Docker Only

Give your `user` access to docker containers by adding the user to the `docker` group.

### Install Restic

You should have `restic` installed on your system. I prefer to use the latest version of the program, and thus install it directly into my user's home directory. For example: the binary could be located in `/home/user/restic/bin/`.

### Companion files

Ensure the companion files (listed above) are completed and correct. I have some examples in each file to give you an idea of what is required.

You can have multiple backup repositories, for example one repo that points to your databases, and another that points to personal files. Or you can combine them into one repo, up to you. This could look like:

```
/home/user/restic
├── bin
│ 	└── restic
├── databases
│ 	├── docker_databases
│ 	├── restic.env
│ 	├── restic.files
│ 	└── restic.exclude
├── personal
│ 	├── restic.env
│ 	├── restic.files
│ 	└── restic.exclude
├── db_backup.sh
└── restic_backup.sh
```

The current iteration of the **db_backup.sh** script already calls the **restic_backup.sh** as part of it to ensure the databases are backed up, and then deleted afterwards to not leave raw databases accessible to anyone.

### Create restic repo(s)

If you have not already, we need to initialize each Restic repo. First we can read the env file, followed by initializing the repo itself:
```
source restic.env
restic init
```

### Test run

You can call the `db_backup.sh` file directly to ensure that it works correctly. The one key component here if using multiple repos is to correctly set the `REPO_DIR` env variable. 

#### Single Repo

If you only have a single repo, you can set it permanently by either adding at the end of your user's `~/.bashrc` file:

```
export REPO_DIR=/home/user/restic
```

Or you can hard code it into the two shell scripts from this repo. But if you pull a new version, you'll have to re-hardcode them in!

For this test run, if you set the `REPO_DIR` env variable in the `restic.env` file, we can simply use `source` to grab the env variable. But this won't work for `cron` jobs (more on that later).

```
source restic.env
./db_backup.sh
```

If everything goes well, you should see messages appearing and finishing with the message:

`=========FINISHED========`

#### Multi-repo

If you decide to backup different things to different restic repositories, we simply need to set the directory where the companion files can be found. If you've set `REPO_DIR` in one of your `restic.env` files, we can simply `source` it for this test run (see above example), OR set it for this run:

```
REPO_DIR=/home/user/restic/databases ./db_backup.sh
```

If everything goes well, you should see messages appearing and finishing with the message:

`=========FINISHED========`

### Cron Jobs

Create a `cron` job for the `user` to run the backup script daily like:

```
0 2 * * * /home/user/restic/db_backup.sh 2>&1 | /usr/bin/logger -t resticdbbkup
```

This will run a backup at 2AM daily using the `db_backup.sh` script. It will also
log everything to `syslog` and is easy to find as it is tagged with `resticdbbkup`

**Note:**
If you are using multi-repos, you'll need to set the `REPO_DIR` variable as well:

```
0 2 * * * REPO_DIR=/home/user/restic/databases /home/user/restic/db_backup.sh 2>&1 | /usr/bin/logger -t resticdbbkup
0 3 * * 0 REPO_DIR=/home/user/restic/personal /home/user/restic/restic_backup.sh 2>&1 | /usr/bin/logger -t resticperbkup
```

The above would run a daily backup of your "databases" repo at 2AM, and a weekly backup of your "personal" repo (without databases) every Sunday at 3AM.