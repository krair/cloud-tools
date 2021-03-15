#!/bin/bash

##############################################
#                                            #
#    A simple cript for adding profile to    #
#    a wireguard running behind a Pi-hole    #
#                                            #
# version 0.0.1                              #
# Author: Kit Rairigh                        #
# github: krair/cloud-tools                  #
##############################################

## TODO - add option to install from scratch

## TODO - add option to remove a profile

## TODO - add some error checking, if something fails, revert to old config

# Check if user is running as root
if [ "$EUID" -ne 0 ]; then
	echo "Please run as root. Try with 'sudo'"
	exit 1
fi

## TODO - Check for existence of standard wg0.conf name and location

## TODO - better way to check for external IP? probably won't work with docker. verify with user
# Find external IPv4 of server
ip=`ip a | grep -e "inet.*eth0" | cut -d " " -f8`
port=`grep Listen /etc/wireguard/wg0.conf | cut -d " " -f3`

# Use default wireguard config location to determine gateway and subnet
gateway=`grep Address /etc/wireguard/wg0.conf | cut -d " " -f3 | cut -d "/" -f1`
base=`echo "${gateway}" | cut -d "." -f1-3`

## TODO - find assigned IPv4's, sort, insert if missing. eg. 2,3,5 assigned, use 4
## TODO - Add IPv6 support
# Find next available IPv4 address for new profile
octet=$(( 1 + `grep AllowedIP /etc/wireguard/wg0.conf | tail -1 | cut -d "." -f4 | cut -d "/" -f1`))
if [[ -z $octet ]]; then
	octet=2
elif (( $octet > 254 )); then
	echo "Too many clients for /24 subnet"
	exit 1
fi
address=${base}.${octet}
echo "	Using gateway: ${gateway}"
echo "	Assigning address: ${address}"

# Ask to provide a name for the new profile
echo "	Please give the peer connection a name:"
read name

# If no profile name given, warn and assign a default value
if [[ -z $name ]]
then
	name=wg-peer-${octet}
	echo "	====Warning===="
	echo "	No name given, reverting to default: wg-peer-${octet}"
fi
echo "	Creating profile for ${name}"

# Create subdirectory for new profile
echo "	Creating sub-directory /etc/wireguard/${name}"
mkdir /etc/wireguard/${name}
cd /etc/wireguard/${name}
umask 077

# Generate profile key and pre-shared key
echo "	Generating wireguard keys..."
wg genkey | tee "${name}.key" | wg pubkey > "${name}.pub"
wg genpsk > "${name}.psk"

# Add new profile to default wireguard config and restart wireguard service
echo "	Adding Peer to wg0.conf"
echo "[Peer] # ${name}" >> /etc/wireguard/wg0.conf
echo "PublicKey = $(cat "${name}.pub")" >> /etc/wireguard/wg0.conf
echo "PresharedKey = $(cat "${name}.psk")" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = ${address}/32, fd08:4711::${octet}/128" >> /etc/wireguard/wg0.conf

## TODO - Stop? Notify? if reload returns error
# Reload the config without having to restart the service and disrupt working connections
echo "	Reloading updated Wireguard config..."
wg syncconf wg0 <(wg-quick strip wg0)

# Generate profile config file
echo "	Generating profile config file"
echo "[Interface]" > "${name}.conf"
echo "Address = ${address}/32, fd08:4711::${octet}/128" >> "${name}.conf"
## TODO - Check for Pi-hole IP, or other DNS?
echo "DNS = ${gateway}" >> "${name}.conf"  # Your Pi-hole's IP
echo "PrivateKey = $(cat "${name}.key")" >> "${name}.conf"

## TODO - ask if only for DNS or for full VPN forwarding
echo "[Peer]" >> "${name}.conf"
echo "AllowedIPs = ${base}.0/24, fd08::/64" >> "${name}.conf" # Only sets Pi-hole DNS use
echo "Endpoint = ${ip}:${port}" >> "${name}.conf"
echo "PersistentKeepalive = 25" >> "${name}.conf"
echo "PublicKey = $(cat ../server.pub)" >> "${name}.conf"
echo "PresharedKey = $(cat "${name}.psk")" >> "${name}.conf"

echo "	Complete, peer config fie can be found under:"
echo "	/etc/wireguard/${name}/${name}.conf"

# Ask if completed config should be encoded into a scanable QR code output to stdout
read -e -p "	Would you like the output as a QR code (for mobile clients)? [y/N]" choice
[[ "$choice" == [Yy]* ]] && qrencode -t ansiutf8 -r "${name}.conf" || echo "	that was a no"

echo "	Finished!"
