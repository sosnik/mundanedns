<#
.DESCRIPTION
Parse tailscale status information and create hosts file entries for tailnet hosts.
Read the README for the whys of it. 
Repo: github.com/sosnik/mundanedns

⚠️ Run this script as admin or otherwise fiddle with permissions on your hosts file for this to work.
#>
function Check-TailscaleStatusChange {
    $hashFilePath = Join-Path (Get-Location) "tailscale_status_hash.txt"
    $currentStatus = tailscale status --json | Out-String
    $currentHash = Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($currentStatus))) -Algorithm SHA256
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        if (Test-Path $hashFilePath) {
            $previousHash = Get-Content $hashFilePath
            if ($currentHash.Hash -eq $previousHash) {
                # Hash values are the same: do nothing
                Write-Host "$timestamp - No change in Tailscale status."
            } else {
                # Hash values are different: update hosts file and, if successful, save new hash value
                Write-Host "$timestamp - Tailscale state has changed. Attempting update of hosts file."
                $onlineNodes = Parse-TailscaleStatus -currentStatus $currentStatus
                Update-MundaneDNSHosts -Entries $onlineNodes
                Set-Content -Path $hashFilePath -Value $currentHash.Hash
            }
        } else {
            # Previous hash value does not exist, update hosts file and save the hash value 
            Write-Host "No tailscale state saved."
            $onlineNodes = Parse-TailscaleStatus -currentStatus $currentStatus
            Update-MundaneDNSHosts -Entries $onlineNodes
            Set-Content -Path $hashFilePath -Value $currentHash.Hash
        }
    } catch {
        if ($_ -match "access to the path") {
            Write-Host "Error: Permission denied. Please run as Administrator."
            # Optionally, prompt for elevated permissions
            Start-Process powershell -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
            exit
        } else {
            Write-Host "An unexpected error occurred: $_"
            exit
        }
    }
}

function Parse-TailscaleStatus {
    param (
        [string]$currentStatus
    )

    $tailscaleStatus = $currentStatus | ConvertFrom-Json
    $onlineNodesEntries = @()

    foreach ($nodeKey in $tailscaleStatus.Peer.PSObject.Properties.Name) {
        $node = $tailscaleStatus.Peer.$nodeKey
        if ($node.Online) {
            $FQDN = "$($node.DNSName).$($tailscaleStatus.User.$($node.UserID).LoginName).$($tailscaleStatus.CurrentTailnet.Name)"
            foreach ($ip in $node.TailscaleIPs) {
                $onlineNodesEntries += "{0,-24}{1}" -f $ip, $FQDN
            }
        }
    }

    return $onlineNodesEntries
}

function Update-MundaneDNSHosts {
    param (
        [string[]]$Entries
    )
    $hostsPath = "C:\Windows\System32\drivers\etc\hosts"

    try {
        $hostsContent = Get-Content -Path $hostsPath -ErrorAction Stop
    } catch {
        Write-Host "Failed to read hosts file: $_ Please ensure you have the necessary permissions."
        Exit
    }

    $startMarker = "# Start of mundanedns"
    $endMarker = "# End of mundanedns"
    $newHostsContent = @()
    $insideMundaneSection = $false

    foreach ($line in $hostsContent) {
        if ($line -eq $startMarker) {
            $insideMundaneSection = $true
        } elseif ($line -eq $endMarker) {
            $insideMundaneSection = $false
            # Skip adding the end marker here, it will be added with new entries
        } elseif (-not $insideMundaneSection) {
            $newHostsContent += $line
        }
    }

    # Add or replace the mundanedns section
    $newHostsContent += $startMarker
    foreach ($entry in $Entries) {
        $newHostsContent += $entry
    }
    $newHostsContent += $endMarker

    try {
        # Write the updated content back to the hosts file
        Set-Content -Path $hostsPath -Value $newHostsContent -Force
        Write-Host "Wrote mundanedns to hosts file."
    } catch {
        Write-Host "Failed to update the hosts file: $_ Please ensure you have the necessary permissions."
        Break
    }
}

# Start
Check-TailscaleStatusChange