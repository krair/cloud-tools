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
