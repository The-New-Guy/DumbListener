<#

    A set of general use tools used by this module.

#>

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

######################
## Public Functions ##
######################

#region Public Functions



#endregion Public Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#######################
## Private Functions ##
#######################

#region Private Functions

#====================================================================================================================================================
#####################
## Write-HostColor ##
#####################

#region Write-HostColor

function Write-HostColor {

    [CmdletBinding()]

    param([Object[]]$Objects, 
          [ConsoleColor[]]$Colors,
          [switch]$NoNewline = $false)

    for ($i = 0; $i -lt $Objects.Length; $i++) {
        Write-Host $Objects[$i] -Foreground $Colors[$i] -NoNewline
    }

    if (!$NoNewline) {
        Write-Host
    }
}

#endregion Write-HostColor

#endregion Private Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>