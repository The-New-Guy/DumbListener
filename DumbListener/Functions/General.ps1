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

    <#

        .SYNOPSIS

            Accepts an array of objects and an array of console color values then writes to the console host the array objects with using the provided
            colors.

        .DESCRIPTION

            Accepts an array of objects and an array of console color values then writes to the console host the array objects with using the provided
            colors.

        .PARAMETER Objects

            The objects to be written to the console.

        .PARAMETER ForegroundColors

            The array of foreground colors you wish each object to have. The index of the object in the Objects array will indicate the index of the
            color in the Colors array that gets used. If there are more colors provided than there are objects, then the extra colors are ignored. If
            there are less colors (or none at all) provided then the extra objects will use the default foreground color. The $null value and an empty
            string can be used in place of a color to indicate the default color should be used.

        .PARAMETER BackgroundColors

            The array of background colors you wish each object to have. The index of the object in the Objects array will indicate the index of the
            color in the Colors array that gets used. If there are more colors provided than there are objects, then the extra colors are ignored. If
            there are less colors (or none at all) provided then the extra objects will use the default background color. The $null value and an empty
            string can be used in place of a color to indicate the default color should be used.

    #>

    [CmdletBinding()]

    param([Parameter(ValueFromPipeline)] [Object[]]$Objects,
          [Alias('Colors')] [string[]]$ForegroundColors,
          [string[]]$BackgroundColors,
          [switch]$NoNewline)

    begin {
        $Index = 0
    }

    process {

        foreach ($obj in $Objects) {

            if ((($ForegroundColors.Count -gt 0) -and ($ForegroundColors[$Index].Length -gt 0)) -and
                (($BackgroundColors.Count -gt 0) -and ($BackgroundColors[$Index].Length -gt 0))) {
                Write-Host $obj -Foreground $ForegroundColors[$Index] -BackgroundColor $BackgroundColors[$Index] -NoNewline
            } elseif ((($ForegroundColors.Count -gt 0) -and ($ForegroundColors[$Index].Length -gt 0)) -and
                      (($BackgroundColors.Count -eq 0) -or ($BackgroundColors[$Index].Length -eq 0))) {
                Write-Host $obj -Foreground $ForegroundColors[$Index] -NoNewline
            } elseif ((($ForegroundColors.Count -eq 0) -or ($ForegroundColors[$Index].Length -eq 0)) -and
                      (($BackgroundColors.Count -gt 0) -and ($BackgroundColors[$Index].Length -gt 0))) {
                Write-Host $obj -Background $BackgroundColors[$Index] -NoNewline
            } else {
                Write-Host $obj -NoNewline
            }

            $Index++
        }

        if (!$NoNewline) {
            Write-Host
        }

    }

}

#endregion Write-HostColor

#endregion Private Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>