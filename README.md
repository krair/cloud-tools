# Cloud-tools
A small repository of scripts and tools I use for managing my personal cloud servers

Note: Most are only tested on my own cloud servers. Despite that, I tried to add some flexibility to them but have not had a chance to test most of them on multiple environments. Presented AS-IS. In each I will do my best to describe the limitations of the scripts/code and plans to imporove them. Any suggestions are welcome!

## Wireguard
- set of tools to easily manage a Wireguard server and automate simple tasks like adding profiles

## Backups
- Example scripts to backup docker databases to a `restic` repository
- Primarily written for Nextcloud and other similar self-hosted apps, but can easily be modified to fit other circumstances.

## File-management
- Set of tools for managing files like reducing PDF size

## Docker
- Scripts to help speed up some repetitive tasks with docker

## Log-Notify
- Simple python program to parse and send system notifications (like logins and security alerts) from the `audit` daemon to a matrix homeserver.
