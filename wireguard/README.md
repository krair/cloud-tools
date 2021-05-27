# ***Wireguard***

A few scripts to help automate the setup and management of a Wireguard VPN.

The goal is to eventually make it as simple as possible so even my mother could use it...

## Win_wg_adapters_to_private.ps1

A basic PowerShell script to change your Wireguard adapters from the 'Public' Network space to 'Private'. Must be run as Administrator.

*What it does:*
- Finds a list of installed Wireguard config files
- Gets a list of adapters in the 'Public' space
- Compares the lists, if a match, changes the adapter to the 'Private' space
- Catches the error if no adapters are in the 'Public' space

*Limitations:*
- I have very little experience with Powershell, so this is just a quick script I made for personal use while testing to speed up the process when I would create a new peer or change something in Wireguard and it would revert to 'Public'
- No output on successful change

*Future:*
- Automate the process so this script runs anytime a Wireguard adapter is modified
- Add this to a script for Internet Connection Sharing when I want to use NAT on clients.
- Add this to a script that fixes many of the Windows Networking "quirks" as listed in https://git.zx2c4.com/wireguard-windows/about/docs/netquirk.md

## new_wg_peer.sh

A simple shell script to quickly add Wireguard peers for Linux based Wireguard installs

*What it does:*
- Using default wg0.conf file and location, generates new profiles
- Asks for a profile name, or sets a default (wg-peer-2 for example) based upon number of registered peers
- Generates profile named config and asks user if they want a qr code which they can scan with mobile.
- Uses ```wg syncconf``` to gently reload the new config without dropping current connections

*Limitations:*
- Not for setup of new server config
- Cannot remove a peer
- Only tested on a Fedora Server & Ubuntu 20.04
- Does not find available IP's if a peer was removed
- Limited to /24 subnet
- IPv4 only

**Planned additions:**

*Soon*
- Backup old working config, revert if error(s)
- Remove a peer by name or IP
- Disable/enable peer by name or IP
- DNS "none" or "custom" options
- Detect removed peer when adding a new peer, insert into empty (slot)

*Later*
- Install and configure full Wireguard setup including firewalld/nftables config
- IPv6
- Larger/different subnet
- GUI, remote management (web-based?)
