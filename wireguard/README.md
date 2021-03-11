# ***Wireguard***

A few scripts to help automate the setup and management of a Wireguard VPN with a Pi-Hole DNS.

The goal is to make it as simple as possible so even my mother could use it...

*What it does:*
- Using default wg0.conf file and location, generates new profiles
- Asks for a profile name, or sets a default (wg-peer-2 for example) based upon number of registered peers
- Generates profile named config and asks user if they want a qr code which they can scan with mobile.
- Uses ```wg syncconf``` to gently reload the new config without dropping current connections

*Limitations:*
- Not for setup of new server config
- Cannot remove a peer
- Only tested on a Fedora Server
- Does not find available IP's if a peer was removed
- Limited to /24 subnet
- IPv4 only

**Planned additions:**

*Soon*
- Backup old working config, revert if error(s)
- Remove a peer by name or IP
- Disable/enable peer by name or IP
- Non-Pihole DNS
- Detect removed peer when adding a new peer, insert into empty (slot)
- Ask if the profile is to be used for DNS only or for full VPN mode
- Test on Ubuntu/Debian

*Later*
- Install and configure full Wireguard setup including firewalld/nftables config
- IPv6
- Larger/different subnet
- GUI, remote management (web-based?)