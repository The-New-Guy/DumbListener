<#

    The DumbUDPListener will setup a standard System.Net.Sockets.UdpClient as a listener.

#>

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

######################
## Public Functions ##
######################

#region Public Functions

#====================================================================================================================================================
###########################
## Start-DumbUDPListener ##
###########################

#region Start-DumbUDPListener

function Start-DumbUDPListener {
    <#

        .SYNOPSIS

            Starts a UDP listener to capture logging information to the given file.

        .DESCRIPTION

            Starts a UDP listener to capture logging information to the given file.

            The logger will expect data to be sent in the following format:

                <filename>:<message>

        .PARAMETER Port

            Specifies the port for which the logger will listen on.

        .PARAMETER LogPath

            Specifies the path that log files will be created it. Each remote host will have its own folder located here.

        .PARAMETER MaxLogSize

            Maximum size in bytes that each log file will become before it is rotated out.

        .PARAMETER MaxArchiveFiles

            Maximum number of rotated logs to keep before deleting them. A value of zero will disable deletion
            of old log files. The oldest log files will have the highest numbered extension.

        .PARAMETER LogErrors

            If specified this switch will enable the logging of errors to "ScriptLogs" directory under the provided LogPath. All
            errors will be logged in a file named after the date in which the error occurred.

        .PARAMETER LogDebug

            If specified this switch will enable the logging of debug info to "ScriptLogs" directory under the provided LogPath. All
            debug info will be logged in a file named after the date in which the debug info occurred.

            Warning: Enabling this switch will log all actions taken and all messages received. This can fill up the file quickly.

        .NOTES

            Note that if this script is killed or otherwise ends prematurely it may leave the socket open
            preventing future connections to the same port. To clear this you must first find the process
            ID and kill that process. (Note: This issue has actually been fixed but I am leaving this here
            just in case it is needed)

            The following will list the open port and the process ID:

            netstat -ano | find ":<port>"

            Use the process ID to find out which process is holding the port open:

            tasklist /SVC /FI "PID eq <PID>"

    #>

    [CmdletBinding()]

    param([Parameter(Mandatory=$false)] [int]$Port = 2000,
          [Parameter(Mandatory=$false)] [ValidateScript({ Test-Path $_ -IsValid })] [string]$LogPath = $PWD,
          [Parameter(Mandatory=$false)] [int]$MaxLogSize = 1MB,
          [Parameter(Mandatory=$false)] [int]$MaxArchiveFiles = 0,
          [Parameter(Mandatory=$false)] [switch]$LogErrors = $true,
          [Parameter(Mandatory=$false)] [switch]$LogDebug = $false)

    begin {

        ###########################################################################################################################################
        ##################s
        # Initialization #
        ##################

        # Set the console to capture CTRL+C as input so we can prevent improper shutdown of the script
        [Console]::TreatControlCAsInput = $true

        # Strip trailing slashes from LogPath
        $LogPath = $LogPath -replace '^(.*?)\\$','$1'

        # Create log path if it doesn't already exist
        if (-not (Test-Path $LogPath)) {

            Write-Debug "Root log path does not exist. Creating root log path directory : $LogPath`n`n"

            New-Item -Path $LogPath -ItemType Directory -ErrorAction Stop | Out-Null

        }

        # Create ScriptLogs folder if needed
        if (($LogErrors -or $LogDebug) -and (-not (Test-Path ($LogPath + '\ScriptLogs')))) {

            Write-Debug "Creating ScriptLogs directory : $($LogPath + '\ScriptLogs')`n`n"

            New-Item -Path ($LogPath + '\ScriptLogs') -ItemType Directory -ErrorAction Stop | Out-Null

        }

        # Create errors folder if needed
        if ($LogErrors -and (-not (Test-Path ($LogPath + '\ScriptLogs\Errors')))) {

            $scriptErrorsPath = ($LogPath + '\ScriptLogs\Errors')

            Write-Debug "Creating Errors directory : $scriptErrorsPath`n`n"

            New-Item -Path $scriptErrorsPath -ItemType Directory -ErrorAction Stop | Out-Null

        }

        # Create debug folder if needed
        if ($LogDebug -and (-not (Test-Path ($LogPath + '\ScriptLogs\Debug')))) {

            $scriptDebugPath = ($LogPath + '\ScriptLogs\Debug')

            Write-Debug "Creating Debug directory : $scriptDebugPath`n`n"

            New-Item -Path $scriptDebugPath -ItemType Directory -ErrorAction Stop | Out-Null

        }

        # If Debug switch has been enabled, set it to continue
        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }

        # Initialize variables
        $RemoteHosts = @{}

        ###########################################################################################################################################

        ####################
        # Helper Functions #
        ####################

        # Helper function that will wait for the next datagram and return an object representing the remote host and its content
        function _Get-NextMessage {

            param([Parameter(Mandatory=$true)] [System.Net.Sockets.UdpClient]$UDPClient)

            # Initialize message received variable
            $messageReceived = $null

            # Initialize remote endpoint variable. Any IP and any port. Will be overwritten when data is received.
            $remoteEndpoint = New-Object System.Net.IPEndPoint ([IPAddress]::Any, [System.Net.IPEndPoint]::MinPort)

            try {

                # Wait for communication
                $content = $UDPClient.Receive([ref]$remoteEndpoint)

                # Build an object containing the content and remote host info
                $messageReceived = New-Object PSObject -Property @{
                                                                    RemoteIP   = $remoteEndpoint.Address.IPAddressToString
                                                                    RemotePort = $remoteEndpoint.Port
                                                                    Content    = [Text.Encoding]::ASCII.GetString($content)
                                                                  }
            } catch {

                Write-Error "Failed to receive message from listening socket on UDP port $Port : `n$($_.Exception)"
                if ($LogErrors) { "[Error] : Failed to receive message from listening socket on UDP port $Port : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

            }

            # Return message received
            return $messageReceived
        }


        # Helper function that will log the contents of a received message
        function _Log-Message {

            param([Parameter(Mandatory=$true)] $ReceivedMessage)

            # Debugging info
            Write-Debug ('Remote Host : ' + $ReceivedMessage.RemoteIP)
            Write-Debug ('Remote Port : ' + $ReceivedMessage.RemotePort)
            Write-Debug ('Message : ' + $ReceivedMessage.Content + "`n")
            if ($LogDebug) { "[Debug] : Remote Host : $($ReceivedMessage.RemoteIP)" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
            if ($LogDebug) { "[Debug] : Remote Port : $($ReceivedMessage.RemotePort)" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
            if ($LogDebug) { "[Debug] : Message : $($ReceivedMessage.Content)`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

            # Parse message. <filename>:<message>
            $file = ($ReceivedMessage.Content -split ':')[0]
            $message = $ReceivedMessage.Content -replace "^${file}:(.*)$",'$1'

            # Verify the file is even a valid file name before doing anything
            if (-not (Test-Path $file -IsValid)) {

                # Filename is not a valid filename.
                Write-Warning "Received message from remote host, $($ReceivedMessage.RemoteIP), contained an invalid filename : $file. `n`n"
                if ($LogErrors) { "[Warning] : Received message from remote host, $($ReceivedMessage.RemoteIP), contained an invalid filename : $file. `n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                return
            }

            # Have we already received logs previously from the remote host
            if ($RemoteHosts.Keys -contains $ReceivedMessage.RemoteIP) {

                $dir = $RemoteHosts[$ReceivedMessage.RemoteIP]

            } else {

                $dir = ($LogPath + '\' + $ReceivedMessage.RemoteIP)
                $RemoteHosts[$ReceivedMessage.RemoteIP] = $dir

                try {
                    # Make new directory for new remote host if it doesn't already exist
                    if (-not (Test-Path $dir)) {
                        New-Item -Path $dir -ItemType Directory -ErrorAction Stop | Out-Null

                        Write-Debug "Created new remote host directory : $dir`n`n"
                        if ($LogDebug) { "[Debug] : Created new remote host directory : $dir`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                    }

                } catch {
                    Write-Error "Failed to create folder for remote host $($ReceivedMessage.RemoteIP): `n$($_.Exception)"
                    if ($LogErrors) { "[Error] : Failed to create folder for remote host $($ReceivedMessage.RemoteIP): `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                    return
                }
            }

            $filePath = $dir + '\' + $file

            # If current log file exists, check to see if it has reached max log size
            if ((Test-Path $filePath) -and ((Get-Item -Path $filePath).Length -gt $MaxLogSize)) {

                Write-Debug "File, $filePath, has reached max log size ($MaxLogSize bytes). Rotating logs.`n`n"
                if ($LogDebug) { "[Debug] : File, $filePath, has reached max log size ($MaxLogSize bytes). Rotating logs.`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                # Max log size reached. Rotate the logs
                _Rotate-LogFile -Directory $dir -Filename $file

                # Write to log file
                try {

                    # Write to log file
                    $message | Add-Content -Path $filePath -ErrorAction Stop

                    Write-Debug "Message written to file, $filePath : Current Log Size / Max Log Size = $((Get-Item $filePath).Length) / $MaxLogSize`n`n"
                    if ($LogDebug) { "[Debug] : Message written to file, $filePath : Current Log Size / Max Log Size = $((Get-Item $filePath).Length) / $MaxLogSize`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                } catch {

                    Write-Error "Failed to write to file $filePath : `n$($_.Exception)"
                    if ($LogErrors) { "[Error] : Failed to write to file $filePath : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                }

            # If remote host directory exists but log file doesn't exist or is below max log size, write to log file
            } elseif ((Test-Path $dir) -and (Test-Path $filePath -IsValid)) {

                try {

                    # Write to log file
                    $message | Add-Content -Path $filePath -ErrorAction Stop

                    Write-Debug "Message written to file, $filePath : Current Log Size / Max Log Size = $((Get-Item $filePath).Length) / $MaxLogSize`n`n"
                    if ($LogDebug) { "[Debug] : Message written to file, $filePath : Current Log Size / Max Log Size = $((Get-Item $filePath).Length) / $MaxLogSize`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                } catch {

                    Write-Error "Failed to write to file $filePath : `n$($_.Exception)"
                    if ($LogErrors) { "[Error] : Failed to write to file $filePath : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                }
            }
        }

        # Helper function to rotate log file
        function _Rotate-LogFile {

            param([string]$Directory, [string]$Filename)

            Write-Debug "Rotating file, $Filename, in directory, $Directory.`n`n"
            if ($LogDebug) { "[Debug] : Rotating file, $Filename, in directory, $Directory.`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

            if (Test-Path ($Directory + '\' + $Filename)) {

                # Get all previous recordings of the given file
                $previousFiles = @()
                $previousFiles += Get-ChildItem -Path $Directory -File | Where-Object { $_.Name -match "^$($Filename.Replace('.','\.'))\.\d+$" }
                $previousFilesCount = $previousFiles.Count

                Write-Debug "Found $previousFilesCount previous files for file, $Filename : "
                $previousFiles | foreach { Write-Debug "`t`t`t$($_.FullName)" }
                Write-Debug "(end)`n`n"
                if ($LogDebug) { "[Debug] : Found $previousFilesCount previous files for file, $Filename : " | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                if ($LogDebug) { $previousFiles | foreach { $_ | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') } }
                if ($LogDebug) { "[Debug] : (end)`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                # Remove oldest file if we have reached the max files allowed
                $deletedLogCount = 0
                if (($MaxArchiveFiles -gt 0) -and ($previousFilesCount -ge $MaxArchiveFiles) -and (Test-Path ($Directory + '\' + $Filename + '.' + $previousFilesCount))) {

                    try {

                        Get-Item -Path ($Directory + '\' + $Filename + '.' + $previousFilesCount) | Remove-Item -ErrorAction Stop

                        $deletedLogCount = 1

                        Write-Debug "Deleted $($Directory + '\' + $Filename + '.' + $previousFilesCount)`n`n"
                        if ($LogDebug) { "[Debug] : Deleted $($Directory + '\' + $Filename + '.' + $previousFilesCount)`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                    } catch {

                        Write-Error "Failed to delete old log file during rotation process : $($Directory + '\' + $Filename + '.' + $previousFilesCount) : `n$($_.Exception)"
                        if ($LogErrors) { "[Error] : Failed to delete old log file during rotation process : $($Directory + '\' + $Filename + '.' + $previousFilesCount) : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                        return
                    }
                }

                # Rename previous files to have an extension that is one more than what they are currently
                for ($i = $previousFilesCount - $deletedLogCount; $i -gt 0; $i--) {

                    if (Test-Path ($Directory + '\' + $Filename + '.' + $i)) {

                        try {

                            Rename-Item -Path ($Directory + '\' + $Filename + '.' + $i) -NewName ($Directory + '\' + $Filename + '.' + ($i + 1)) -ErrorAction Stop

                            Write-Debug "Renamed $($Directory + '\' + $Filename + '.' + $i) to $($Directory + '\' + $Filename + '.' + ($i + 1))`n`n"
                            if ($LogDebug) { "[Debug] : Renamed $($Directory + '\' + $Filename + '.' + $i) to $($Directory + '\' + $Filename + '.' + ($i + 1))`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                        } catch {

                            Write-Error "Failed to rename previous logfiles during rotation process : Old - $($Directory + '\' + $Filename + '.' + $i) : New - $($Directory + '\' + $Filename + '.' + ($i + 1)) : `n$($_.Exception)"
                            if ($LogErrors) { "[Error] : Failed to rename previous logfiles during rotation process : Old - $($Directory + '\' + $Filename + '.' + $i) : New - $($Directory + '\' + $Filename + '.' + ($i + 1)) : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                            return
                        }
                    }
                }

                try {

                    # Rename current file to <current file>.1
                    Rename-Item -Path ($Directory + '\' + $Filename) -NewName ($Directory + '\' + $Filename + '.1') -ErrorAction Stop

                    Write-Debug "Renamed current log file, $($Directory + '\' + $Filename) to $($Directory + '\' + $Filename + '.1')`n`n"
                    if ($LogDebug) { "[Debug] : Renamed current log file, $($Directory + '\' + $Filename) to $($Directory + '\' + $Filename + '.1')`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                } catch {

                    Write-Error "Failed to rename current log, $($Directory + '\' + $Filename), to $($Directory + '\' + $Filename + '.1') during rotation process : `n$($_.Exception)"
                    if ($LogErrors) { "[Error] : Failed to rename current log, $($Directory + '\' + $Filename), to $($Directory + '\' + $Filename + '.1') during rotation process : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                }
            }
        }
    }

    process {

        # Open a UDP socket on the given port
        try {
            $localEndpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $Port) -ErrorAction Stop
            $udpClient = New-Object System.Net.Sockets.UdpClient -ErrorAction Stop

            # Set socket options to allow reuse of local address in case of unexpected termination and the port is left open
            $udpClient.ExclusiveAddressUse = $false
            $udpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
            $udpClient.Client.Bind($localEndpoint)

            # Notify user of listening port
            Write-Output "`nUDP listening socket opened on port $Port. Press CTRL+Z and wait for new data to quit gracefully.`n"
            if ($LogDebug) { "[Debug] : UDP listening socket opened on port $Port. Press CTRL+Z and wait for new data to quit gracefully.`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

            # Use a loop to continuously listen for data from the open UDP socket.
            # Currently this is done synchronously and thus will block execution of the script while waiting
            # for new data. Pressing CTRL+Z will end the loop after the next datagram that comes in is processed.
            # Eventually this should be setup asynchronously so that CTRL+Z will end the loop right away.
            while ($true) {

                # Get next UDP datagram
                $receivedMessage = $null
                $receivedMessage = _Get-NextMessage -UDPClient $udpClient

                # Log the contents
                if ($receivedMessage -ne $null) {

                    Write-Debug "Message received from $($receivedMessage.RemoteIP) on port $($receivedMessage.RemotePort).`n`n"
                    if ($LogDebug) { "[Debug] : Message received from $($receivedMessage.RemoteIP) on port $($receivedMessage.RemotePort).`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }

                    _Log-Message -ReceivedMessage $receivedMessage

                }


                # Keys were pressed, check if it is CTRL+Z or CTRL+C and break if so
                if ([Console]::KeyAvailable) {

                    $keyInfo = [Console]::ReadKey($true) # $true turns off the echo of the key press

                    if (($keyInfo.Modifiers -band [ConsoleModifiers]'Control') -and (($keyInfo.Key -eq 'z') -or ($keyInfo.Key -eq 'c'))) {

                        Write-Output "Control interrupt detected. Closing connection and exiting.`n`n"
                        if ($LogDebug) { "[Debug] : Control interrupt detected. Closing connection and exiting.`n" | Add-Content ($scriptDebugPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
                        break

                    }
                }
            }

        } catch {

            Write-Error "Unknown error detected : `n$($_.Exception)" -ErrorAction Stop
            if ($LogErrors) { "[Error] : Unknown error detected : `n$($_.Exception)`n" | Add-Content ($scriptErrorsPath + '\' + (Get-Date -Format yyyy.MM.dd) + '.log') }
            return

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



#endregion Private Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>