# Docker tools

*update-containers*
Script to go through sub-folders and find docker-compose files. Run a docker pull and up.
- Currently all of my apps are separated into subfolders, each containing specific config files and the .yml docker-compose file. I run this script from the top level folder.
- The script ignores traefik.yaml and any hidden folders. So if I wish to not start (or update) a docker service, I simply rename the folder to .folder.
- TODO:
  - Add an easy reversion script - if something broke from the update, easily revert to old container.
    - System prune before? update to remove old containers, updating only keeps the most recent ones.
  - Find and pull out log files from old containers
    - MAYBE symlink (or similar) docker logs into /var/log so I can use something like logwatch to summarize easily.
