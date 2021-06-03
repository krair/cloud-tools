#############################################################################
# Windows Powershell Script to change Wireguard interfaces from the Public to
# Private network category.
#
# Written by: Kit Rairigh - https://github.com/krair - https://rair.dev
#############################################################################

# The first part looks for Administrator privileges, as this change can only
# be accomplished as Administrator
param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

# Get a list of the Wireguard interface names
$wgcfg = Split-Path 'C:\Program Files\Wireguard\Data\Configurations\*' -leaf -Resolve | ForEach-Object {$_.Split('.')[0]}

# Set any active Public Wireguard Adapters to Private
Try {
    # List all active Internet adapters set to 'Public'
    Get-NetConnectionProfile -NetworkCategory 'Public' -ErrorAction stop |
    ForEach-Object {
        # Check if Public adapter is also a Wireguard interface
        if ( $_.InterfaceAlias -in $wgcfg ) {
            # Set profile object to Private
	        $_.NetworkCategory = "Private"
            # Use modified profile object to set in Windows
	        Set-NetConnectionProfile -InputObject $_
          }
       }
    }
# Catch if no adapters are in the public space
Catch {
        echo "No 'Public' adapters found"
        Exit
      }
