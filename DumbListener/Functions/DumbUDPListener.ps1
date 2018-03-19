<#

    The DumbUDPListener will setup a standard System.Net.Sockets.UdpClient as a listener.

#>

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

######################
## Public Functions ##
######################

#region Public Functions

#====================================================================================================================================================
######################
## Send-UDPDatagram ##
######################

#region Send-UDPDatagram

function Send-UDPDatagram {
    <#

        .SYNOPSIS

            Sends a UDP datagram to the provided endpoint.

        .DESCRIPTION

            Sends a UDP datagram to the provided endpoint.

        .PARAMETER EndPoint

            The UDP endpoint to send the datagram to.

        .PARAMETER Port

            The port on the UDP endpoint to connect to.

        .PARAMETER Message

            The message to send to the UDP endpoint.

    #>

    [CmdletBinding()]

    param([string] $EndPoint,
          [int] $Port,
          [string] $Message)

    process {

        $ErrorActionPreference = 'Stop'

        try {

            $IPs = [System.Net.Dns]::GetHostAddresses($EndPoint)
            $Address = [System.Net.IPAddress]::Parse($IPs[0])
            $EndPoints = New-Object System.Net.IPEndPoint($Address, $Port)
            $Socket = New-Object System.Net.Sockets.UDPClient
            $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message)
            $null = $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints)

        } catch {
            throw  # Re-throw error.
        } finally {
            $Socket.Close()
        }

    }

}

Export-ModuleMember -Function 'Send-UDPDatagram'

#endregion Send-UDPDatagram

#====================================================================================================================================================
###########################
## Start-DumbUDPListener ##
###########################

#region Start-DumbUDPListener

function Start-DumbUDPListener {
    <#

        .SYNOPSIS

            Creates a new UDP Listener accepting datagrams and displaying them to console.

        .DESCRIPTION

            Creates a new UDP Listener accepting datagrams and displaying them to console.

        .PARAMETER Port

            Specifies the port for which the UDP listener will listen on.

        .NOTES

            If this command is terminated prematurely it may leave the UDP socket open preventing future connections to the same port. This should not typically happen but if it does use the following to first find the process ID and kill that process.

            The following will list the open port and the process ID:

                netstat -ano | find ":<port>"

            Use the process ID to find out which process is holding the port open:

                tasklist /SVC /FI "PID eq <PID>"

    #>

    [CmdletBinding()]

    param([Parameter(Mandatory=$false)] [int]$Port = 2000)

    begin {

        # We want to stop on all errors.
        $ErrorActionPreference = 'Stop'

        # Set the console to capture CTRL+C as input so we can prevent improper shutdown of the script.
        [Console]::TreatControlCAsInput = $true

    }

    process {

        # Open a UDP socket on the given port.
        try {

            $localEndpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $Port)
            $udpClient = New-Object System.Net.Sockets.UdpClient

            # Set socket options to allow reuse of local address in case of unexpected termination and the port is left open.
            $udpClient.ExclusiveAddressUse = $false
            $udpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
            $udpClient.Client.Bind($localEndpoint)

            Write-Verbose "Listening on UDP socket on port $Port."

            # Use a loop to continuously listen for data from the open UDP socket. Currently this is done synchronously and thus will block execution
            # of the script while waiting for new data. Pressing CTRL+Z will end the loop after the next datagram that comes in is processed.
            # Eventually this should be setup asynchronously so that CTRL+Z will end the loop right away.
            while ($true) {

                # Notify user of listening port.
                Write-Warning "`n"
                Write-Warning 'Note that this thread is blocked waiting for a UDP datagram. Press CTRL+Z and wait for new a new UDP datagram to quit gracefully.'
                Write-Warning "`n"
                Write-Warning 'Use the following command included with this module to send a UDP datagram to the listener.'
                Write-Warning "`n"
                Write-Warning "`t`tSend-UdpDatagram -EndPoint 127.0.0.1 -Port $Port -Message `"UDP Datagram Message Here`""
                Write-Warning "`n"

                # Get next UDP datagram.
                $receivedMessage = $null
                $receivedMessage = Get-NextUDPDatagram -UDPClient $udpClient

                Show-UDPDatagram -ReceivedMessage $receivedMessage

                # Keys were pressed, check if it is CTRL+Z or CTRL+C and break if so.
                if ([Console]::KeyAvailable) {

                    $keyInfo = [Console]::ReadKey($true) # $true turns off the echo of the key press.

                    if (($keyInfo.Modifiers -band [ConsoleModifiers]'Control') -and (($keyInfo.Key -eq 'z') -or ($keyInfo.Key -eq 'c'))) {

                        Write-Verbose 'Control interrupt detected. Closing connection and exiting.'
                        break

                    }
                }
            }

        } catch {

            Write-Error "Unknown error detected : `n$($_.Exception)"

        } finally {

            # This must always run.
            $udpClient.Close()

        }
    }
}

Export-ModuleMember -Function 'Start-DumbUDPListener'

#endregion Start-DumbUDPListener

#endregion Public Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#######################
## Private Functions ##
#######################

#region Private Functions

#====================================================================================================================================================
########################
## Get-NextUDPDatagram ##
########################

#region Get-NextUDPDatagram

# Helper function that will wait for the next datagram and return an object representing the remote host and its content.
function Get-NextUDPDatagram {

    param([Parameter(Mandatory=$true)] [System.Net.Sockets.UdpClient]$UDPClient)

    # Initialize message received variable.
    $datagramReceived = $null

    # Initialize remote endpoint variable. Any IP and any port. Will be overwritten when data is received.
    $remoteEndpoint = New-Object System.Net.IPEndPoint ([IPAddress]::Any, [System.Net.IPEndPoint]::MinPort)

    try {

        # Wait for communication. This blocks until a datagram is received.
        $content = $UDPClient.Receive([ref]$remoteEndpoint)

        # Build an object containing the content and remote host info.
        $datagramReceived = New-Object PSObject -Property @{
            RemoteIP   = $remoteEndpoint.Address.IPAddressToString
            RemotePort = $remoteEndpoint.Port
            Content    = [Text.Encoding]::ASCII.GetString($content)
        }
    } catch {

        Write-Error "Failed to receive message from listening socket on UDP port $Port : `n$($_.Exception)"

    }

    # Return message received.
    return $datagramReceived
}

#endregion Get-NextUDPDatagram

#====================================================================================================================================================
######################
## Show-UDPDatagram ##
######################

#region Show-UDPDatagram

# Helper function that will log the contents of a received message
function Show-UDPDatagram {

    param([Parameter(Mandatory=$true)] $ReceivedMessage)

    $padding = 14
    $headingColor = 'Yellow'
    $labelColor = 'Cyan'
    $seperatorColor = 'White'
    $valueColor = 'Green'

    Write-HostColor ("`nReceived message on", ' : ', "$(Get-Date)`n") -Colors ($headingColor, $seperatorColor, $labelColor)

    # Connection
    Write-HostColor ("RemoteIP".PadRight($padding), ' : ', $ReceivedMessage.RemoteIP) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("Content Length".PadRight($padding), ' : ', $ReceivedMessage.Content.Length) -Colors ($labelColor, $seperatorColor, $valueColor)

    # Content Body
    Write-Host # Newline
    Write-HostColor ("Content Body", " :`n") -Colors ($labelColor, $seperatorColor)
    Write-Host $ReceivedMessage.Content -ForegroundColor $valueColor
    Write-Host # Newline


}

#endregion Show-UDPDatagram

#endregion Private Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>