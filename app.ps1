<# Automation Toolkit

Invokes scripts named in the task inventory file for 
all hostnames contained in the host inventory file.

Parameters:
	-Hosts	: path to host inventory file (default: 'config\hosts.ini')
	-Tasks	: path to task inventory file (default: 'config\tasks.ini')
#>

param (
	[string]$Hosts = "$PSScriptRoot\config\hosts.ini",
    [string]$Tasks = "$PSScriptRoot\config\tasks.ini"
)

$DEFAULT_SCRIPT_DIR = "$PSScriptRoot\script"

function Get-Inventory {
    # Reads basic Ansible inventory file into referenced
    # variables for storing assigned groups with content
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

# Server inventory
$grpServers = @{}
$dtaServers = @{}

Get-Inventory -iniFile $Hosts -grpVar ([ref]$grpServers) -dtaVar ([ref]$dtaServers)

# Script inventory
$grpCommand = @{}
$dtaCommand = @{}

Get-Inventory -iniFile $Tasks -grpVar ([ref]$grpCommand) -dtaVar ([ref]$dtaCommand)

# Loop thru groups server belongs to
# and start scripts defined in group 
$dtaServers[$(hostname)] | ForEach-Object {
    $grpCommand[$_] | ForEach-Object {
        $script = $_
        . "$DEFAULT_SCRIPT_DIR\$script"
    }
}
