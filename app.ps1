<# Powershell Automation Toolkit
19-MAY-2026 / github.com/muonato

Invoke scripts listed in task inventory groups
on all hostnames listed in related host groups

Parameters:
	-Host	: path to host inventory file (default: 'config\hosts.ini')
	-Task	: path to task inventory file (default: 'config\tasks.ini')
	-Repo	: path to task scripts folder (default: 'scripts')
#>
param (
    [string]$Host = "$PSScriptRoot\config\hosts.ini",
    [string]$Task = "$PSScriptRoot\config\tasks.ini"
	[string]$Repo = "$PSScriptRoot\scripts"
)

function Get-Inventory {
    # Reads basic inventory file to variables
    # for groups and their associated content
    #
    # $invgroups = @{}; $invdata = @{}
    # Get-Inventory -iniFile "inventory.ini" \
    #               -grpVar ([ref]$invgroup) \
    #               -dtaVar ([ref]$invdata)
    #
    param (
        [string]$iniFile,
        [ref]$grpVar,
        [ref]$dtaVar
    )
	
    if (-not (Test-Path $iniFile)) {
        return "File not found ($iniFile)"
    }

    $selected = "all"

    Get-Content -Path $iniFile | ForEach-Object {
        $line = $_.Trim()

        # Skip comments and empty lines or modifier blocks
        if ($line -match '^\s*$' -or $line -match '^[#;]') { return }
        if ($line -match ':(vars|children)\]') { $selected = $null; return }

        # Detect standard group header
        if ($line -match '^\[([\w-]+)\]$') {
            $selected = $Matches[1]
            if (-not $grpVar.Value.Contains($selected)) {
                $grpVar.Value[$selected] = [System.Collections.Generic.List[string]]::new()
            }
        } elseif ($null -ne $selected) {
            # Parse server entries within the verified active group
            # Extract data entry ignoring trailing inline variables
            if ($line -match '^([\w\.\-]+)(\s+|$)') {
                $dataEntry = $Matches[1]

                # Append the data to current selected group list
                $null = $grpVar.Value[$selected].Add($dataEntry)
            
                # Populate the reverse data-to-group map
                if (-not $dtaVar.Value.Contains($dataEntry)) {
                    $dtaVar.Value[$dataEntry] = [System.Collections.Generic.List[string]]::new()
                }
                if (-not $dtaVar.Value[$dataEntry].Contains($selected)) {
                    $null = $dtaVar.Value[$dataEntry].Add($selected)
                }
            }
        }
    }
}
# Server inventory init
$grpServers = @{"all" = [System.Collections.Generic.List[string]]::new()}
$dtaServers = @{$(hostname) = [System.Collections.Generic.List[string]]::new()}

# Add host to group 'all' by default
$grpServers["all"].Add($(hostname))
$dtaServers[$(hostname)].Add("all")

Get-Inventory -iniFile $Hosts -grpVar ([ref]$grpServers) -dtaVar ([ref]$dtaServers)

# Script inventory init
$grpCommand = @{"all" = [System.Collections.Generic.List[string]]::new()}
$dtaCommand = @{}

Get-Inventory -iniFile $Tasks -grpVar ([ref]$grpCommand) -dtaVar ([ref]$dtaCommand)

# Loop thru groups server belongs to
# and start scripts defined in group
# as own isolated child session each
$dtaServers[$(hostname)] | ForEach-Object {
    $grpCommand[$_] | ForEach-Object {
        $script = $_
        & "$Repo\$script"
    }
}
