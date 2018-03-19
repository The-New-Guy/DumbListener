#Requires -Version 3.0

# This is the module script file that will be executed first upon importing this module. For simplicity this file should remain fairly minimalistic
# and should mostly just dot source other files to bring in definitions for this module.

#====================================================================================================================================================

######################
# Add Custom Content #
######################

# ~~~ Functions ~~~ #

# Include any functions to be defined. These functions are where most will want to add custom content.

. "$PSScriptRoot\Functions\DumbHTTPListener.ps1"
. "$PSScriptRoot\Functions\DumbUDPListener.ps1"
. "$PSScriptRoot\Functions\General.ps1"
