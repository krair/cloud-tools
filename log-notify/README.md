# Audit Log Notifier

## Intro:
In an attempt to add some security to my servers, and avoid using email notifications, I decided to write a simple auditd plugin to send end-to-end encrypted notifications via a Matrix "bot".

## Prerequisites:
 - auditd installed on server
 - working Matrix homeserver
 - Python3
 - [matrix-commander](https://github.com/8go/matrix-commander) installed and setup.

## Installation Process
TODO - Automate the process and improve the locations, but for now it's rough and hard coded into the python program. Suggestions welcome.

### Preparation:
1. On your Matrix homeserver:
  - Create new user for notifications
  - Create new private room for notifications, invite new user
    - Take note of room name

2. On your server you wish to get log notifications from:
  - Setup matrix-commander with the above user, password, and room name. This will create a `credentials.json` file and a `./store/` directory.
  - Send a test message to ensure the room is setup correctly.

3. As root/sudo on the notification server:
  - Copy `matrix-commander.py` and `audit-notify.py` into `/usr/sbin/` with correct permissions. *If using python 3.9, I had trouble with the auparse python package. You might need to find it and add it to the python PATH or copy it to a location it can be found*
  - Copy `matrix-notifications.conf` into `/etc/audit/plugins.d/` directory.
  - Create the directory: `/usr/local/share/matrix-commander/store/` - you can copy the created `/store/` directory if desired but it isn't required.
  - Copy your `credentials.json` into `/usr/local/share/matrix-commander/`
  - If using a blacklist, copy the `blacklist.example` file into the same directory as above and rename it to `blacklist`

4. Test to make sure everything is setup properly by running the following:
  - To get a set of test events, make sure you get some output from:
  ```
  sudo ausearch --start recent --raw | grep USER
  ```
  *if no output, we can expand the search to today:*
  ```
  sudo ausearch --start today --raw | grep USER
  ```
  - If you were shown some output logs from one of the two commands above, pass the same command into `audity-notify.py` by running:
  ```
  sudo ausearch --start recent --raw | grep USER | tail -n3 | audit-notify.py
  ```
  *This should send 3 messages (if you had at least 3 events) to your Matrix homeserver room created at the beginning*

## Enable the plugin(SELinux)
If you are using SELinux ([and you should be](https://stopdisablingselinux.com/)), you will have to set it to permissive mode temporarily while the program runs for the first time. Afterwards you can set your own policy to allow the `auditd` daemon to allow access to python3 and the files we have added.

While this may be a security risk to some, I am not an expert in this field and have not taken to time to write a proper SELinux policy for this program. Anyone with experience in this is welcome to contribute!!

### *Easy Example with `sealert` and `audit2allow`:*
```
# Set SELinux to permissive
[root]# setenforce 0
# Restart audit service to enable new plugin, run for 10s to gather logs
[root]# service auditd stop
[root]# service auditd start; sleep 10; service auditd stop
```
This will create 10 seconds of alerts which should pick up enough to see them in the logs. You can then use:
```
# Show summary of SELinux alerts
[root]# sealert -a /var/log/audit/audit.log
# Find denials related to our program, automatically create policies
[root]# ausearch -c 'python3' --raw | audit2allow -M my-python3
[root]# ausearch -c 'ldconfig' --raw | audit2allow -M my-ldconfig
# Load policy modules
[root]# semodule -i my-python3.pp
[root]# semodule -i my-ldconfig.pp
# Restart audit service and set SELinux to Enforcing
[root]# service auditd start; setenforce 1
```

### *Better Example with `semanage` and `restorecon`:*
TODO - Finish adding policy contexts - especially for allowing `auditd_t` to execute `ldconfig_exec_t`
```
# PID file created by matrix-commander
[root]# semanage fcontext -a -t auditd_var_run_t "/root/.run/matrix-commander.*"
[root]# restorecon -R /root/.run/
# Log file in /tmp/aunot.log
[root]# semanage fcontext -a -t auditd_log_t /tmp/aunot.log
[root]# restorecon /tmp/aunot.log
# Program files in /usr/local/share/matrix-commander
[root]# semanage fcontext -a -t auditd_var_run_t "/usr/local/share/matrix-commander(/.*)?"
[root]# restorecon -R /usr/local/share/matrix-commander/
```
This list is incomplete but a good starting point.

## Enable the plugin (No SELinux)
As I've so far only tested this on a Fedora 34 and Centos 8 Stream server, I haven't tried this yet. If everything from above was successful, it should be as simple restarting the `auditd` service:
```
[root]# service auditd stop
[root]# service auditd start
```
