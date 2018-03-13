<#

    The DumbHTTPListener will setup a standard System.Net.HTTPListener server and respond.

#>

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

######################
## Public Functions ##
######################

#region Public Functions

#====================================================================================================================================================
############################
## Start-DumbHTTPListener ##
############################

#region Start-DumbHTTPListener

function Start-DumbHTTPListener {
    <#

        .SYNOPSIS

            Creates a new HTTP Listener accepting request, displaying them to console/log and responding with success (200 OK).

        .DESCRIPTION

            Creates a new HTTP Listener accepting request, displaying them to console/log and responding with success (200 OK).

            Send a web request to allow the listener to stop since it will be blocked waiting for a request.

        .PARAMETER Hostname

            The hostname/IP address that will be used in the HTTP request. The default is '*' which will listen to any hostname.

        .PARAMETER Port

            The port to open the HTTP listener on. The default is 8888.

        .PARAMETER Url

            The url to listen for. If not provided the default will be '/'.

        .PARAMETER AuthenticationMethod

            The authentication method required by the listener. The default is Anonymous. Possible values can be found by looking at the [System.Net.AuthenticationSchemes] enumeration. The authentication is handled by the System.Net.HttpListener class. For cases such as Basic authentication any username and password can be used as this module does not provide any additional checks on authentication unless the RestrictRequestToRunAsUser switch is given. If the RestrictRequestToRunAsUser switch is given the listener will verify that the authenticated username is the same as the user running the listener but will ignore the password. If any authentication method other than None or Anonymous are given and authentication fails, the listener will return a 403 Forbidden code.

        .PARAMETER CertificateThumbprint

            The thumbprint of a certificate that can be used for SSL communications. 

        .PARAMETER ResponseStatusCode

            The default HTTP status code to return for each request. The default is 200 OK.

        .PARAMETER ResponseBody

            The default response body to return for each request. The default is no response body.

        .PARAMETER StopCode

            The code used to stop the listener.

            For the DumbHTTPListener the StopCode must be sent via a standard HTTP request to the listener as part of the query string. See below for an example of sending a StopCode of "StopListener" to terminate the listener.

                Invoke-WebRequest -Uri 'http://localhost:8888/?StopListener='

            The default is "StopListener".

        .PARAMETER StopCodeValue

            The value that must be associated with the StopCode to stop the listener.

            For the DumbHTTPListener the StopCode must be sent via a standard HTTP request to the listener
            as part of the query string. The StopCodeValue must be the value used in the query string. See 
            below for an example of sending a StopCode of "StopListener" and a StopCodeValue of "Exit" to 
            terminate the listener.

                Invoke-WebRequest -Uri 'http://localhost:8888/?StopListener=Exit'

            The default is an empty string and therefore the StopCode on its own is enough to terminate the
            listener as all values provided are ignored.

        .PARAMETER RestrictRequestToRunAsUser

            Restricts HTTP requests to those who have authenticated as the user that started the listener.

    #>

    [CmdletBinding(DefaultParameterSetName = 'ErrorRecord')]

    param([ValidateNotNullOrEmpty()] [string]$Hostname = '*',
          [int]$Port = 8888,
          [string]$Url = '',
          [System.Net.AuthenticationSchemes]$AuthenticationMethod = [System.Net.AuthenticationSchemes]::Anonymous,
          [string]$CertificateThumbprint = '',
          [System.Net.HttpStatusCode]$ResponseStatusCode = [System.Net.HttpStatusCode]::OK,
          [string]$ResponseBody = '',
          [string]$StopCode = 'StopListener',
          [string]$StopCodeValue = '',
          [switch]$RestrictRequestToRunAsUser)

    begin {

        # The user running starting the listener.
        $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent())

        # We must be an admin to register an listener.
        if ( -not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
            Write-Error 'This script must be executed from an elevated PowerShell session' -ErrorAction 'Stop'
        }

        # Create the listener.
        $Listener = New-Object System.Net.HttpListener

        Write-Verbose "Listener will run under the following user context: $($CurrentPrincipal.Identity.Name)"

    }

    process {

        $ErrorActionPreference = 'Stop'

        # Add a slash to the end of the URL to listen for.
        if ($Url.Length -gt 0 -and -not $Url.EndsWith('/')) {
            $Url += "/"
        }

        # Protocol (HTTP/HTTPS)
        $protocol = 'http'

        # Bind certificate to port if provided.
        if ($CertificateThumbprint.Length -gt 0) {

            # Get certificate and list of DNS names that can be used with the certificate.
            $cert = Get-ChildItem -Recurse Cert:\LocalMachine | Where-Object { $_.Thumbprint -eq $CertificateThumbprint } | Select-Object -First 1
            if ($cert -eq $null) { Write-Error "Cannot find certificate $CertificateThumbprint." -ErrorAction 'Stop' }
            $dnsNames = $cert.DnsNameList.Unicode
            $certPath = $cert.PSParentPath.Replace('Microsoft.PowerShell.Security\Certificate::LocalMachine\','')

            # Check if provided hostname is in the list of DNS names.
            if (($Hostname -ne '*') -and ($dnsNames -notcontains $Hostname)) {
                Write-Error 'The provided hostname is not included on the provided certificate.' -ErrorAction 'Stop'
            }

            # Bind the certificate to port.
            $certBindingAppId = (New-Guid).Guid
            if ($Hostname -as [ipaddress]) {
                $netshResponse = & netsh http add sslcert "ipport=${Hostname}:$Port" "certhash=$CertificateThumbprint" "appid={$certBindingAppId}" "certstorename=$certPath"
            } elseif ($Hostname -ne '*' -and $Hostname.Length -gt 0) {
                $netshResponse = & netsh http add sslcert "hostnameport=${Hostname}:$Port" "certhash=$CertificateThumbprint" "appid={$certBindingAppId}" "certstorename=$certPath"
            } elseif ($Hostname -eq '*') {
                $netshResponse = & netsh http add sslcert "ipport=0.0.0.0:$Port" "certhash=$CertificateThumbprint" "appid={$certBindingAppId}" "certstorename=$certPath"
            }

            # Check for binding errors.
            if ($netshResponse -notcontains 'SSL Certificate successfully added') {
                Write-Error ("Could not bind certificate to ${Hostname}:$Port.`n" +
                             "Error returned: $netshResponse")
                return
            }

            Write-Verbose "Certificate bound to: ${Hostname}:$Port"
            $protocol = 'https'

        }

        # HTTP prefix (HTTP/HTTPS + Hostname/IP + Port + URI)
        $prefixes = @()
        $prefixes += "${protocol}://${Hostname}:$Port/$Url"
        # Maybe I will add the ability to use multiple prefixes to listen on at some point.
        # See Issue #1 on repository.

        # Add each prefix to the listener.
        foreach ($prefix in $prefixes) {
            $Listener.Prefixes.Add($prefix)
            Write-Verbose "Listening on URI: $prefix"
        }

        # Add the authentication method (something from the .NET enumeration [System.Net.AuthenticationSchemes])
        $Listener.AuthenticationSchemes = $AuthenticationMethod

        try {

            #Start the listener.
            $Listener.Start()

            # We will wait forever...or until someone sends a message to stop...
            while ($true) {

                # Set the default HTTP Status Code and Response Body (Default is 200 OK)
                $statusCode = $ResponseStatusCode
                $body = $ResponseBody

                Write-Warning "`n"
                Write-Warning 'Note that thread is blocked waiting for a request.  You need to send a valid HTTP request to stop the listener cleanly.'
                Write-Warning "Sending `"?$StopCode=$StopCodeValue`" at the end of the URI request as a part of the query string will cause the listener to stop."
                Write-Warning "`n"

                # Wait for a request and retrieve it from the listener context as well as the response object.
                $context = $Listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                $output = $response.OutputStream

                Show-HTTPRequest -Request $request

                # If using authentication other than None or Anonymous we should be authenticated at this point.
                if ((-not $request.IsAuthenticated) -and ($AuthenticationMethod -ne [System.Net.AuthenticationSchemes]::None) -and ($AuthenticationMethod -ne [System.Net.AuthenticationSchemes]::Anonymous)) {
                    Write-Warning 'Rejected request as user was not authenticated.'
                    $statusCode = 403 # Forbidden
                    $body = 'Forbidden'
                } else {

                    $identity = $context.User.Identity

                    Write-Host "Request authenticated as user $($identity.Name)" -ForegroundColor Cyan

                    # If requested, restrict all requests to users authenticated as the user that started the listener.
                    if ($RestrictRequestToRunAsUser) {
                        if ($identity.Name -ne $CurrentPrincipal.Identity.Name) {
                            Write-Warning "Rejected request user ($($identity.Name)) doesn't match current security principal of listener ($($CurrentPrincipal.Identity.Name))."
                            $statusCode = 401 # Unauthorized
                            $body = 'Unauthorized'
                        }
                    }
                }

                # Setup response to the request.
                $response.StatusCode = $statusCode

                # Create buffer to write out the body of the response if one exists.
                if ($body) {

                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $response.ContentLength64 = $buffer.Length
                    $output.Write($buffer,0,$buffer.Length)

                }

                # Write the response to console before sending.
                Show-HTTPResponse -Response $response

                # Send the response to the request, close and wait for the next request.
                $output.Close()

                # Stop the listener if requested.
                if (($StopCodeValue.Length -eq 0) -and ($request.QueryString.Keys -contains $StopCode)) {
                    Write-Warning 'Recieved command to exit listener.'
                    return
                } elseif (($StopCodeValue.Length -gt 0) -and ($request.QueryString.Get($StopCode) -eq $StopCodeValue)) {
                    Write-Warning 'Recieved command to exit listener.'
                    return
                }

            }

        } finally {
            # Stop the listener.
            $Listener.Stop()

            # Remove certificate bindings if set.
            if ($certBindingAppId -ne $null) {
                if ($Hostname -as [ipaddress]) {
                    $netshResponse = & netsh http delete sslcert "ipport=${Hostname}:$Port"
                } elseif ($Hostname -ne '*' -and $Hostname.Length -gt 0) {
                    $netshResponse = & netsh http delete sslcert "hostnameport=${Hostname}:$Port"
                } elseif ($Hostname -eq '*') {
                    $netshResponse = & netsh http delete sslcert "ipport=0.0.0.0:$Port"
                }

                if ($netshResponse -notcontains 'SSL Certificate successfully deleted') {
                    Write-Error ("Could not remove certificate binding on ${Hostname}:$Port.`n" +
                                 "Error returned: $netshResponse")
                }
            }
        }

    }
}

Export-ModuleMember -Function 'Start-DumbHTTPListener'

#endregion Start-DumbHTTPListener

#endregion Public Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#######################
## Private Functions ##
#######################

#region Private Functions

#====================================================================================================================================================
######################
## Show-HTTPRequest ##
######################

#region Show-HTTPRequest

function Show-HTTPRequest {

    param([System.Net.HttpListenerRequest]$Request)

    $padding = 18
    $headingColor = 'Yellow'
    $labelColor = 'Cyan'
    $seperatorColor = 'White'
    $valueColor = 'Green'

    Write-HostColor ("`nReceived request on", ' : ', "$(Get-Date)`n") -Colors ($headingColor, $seperatorColor, $labelColor)

    # Connection
    Write-HostColor ("RemoteEndpoint".PadRight($padding), ' : ', $Request.RemoteEndPoint) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("Request URL".PadRight($padding), ' : ', $Request.Url) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("HTTP Method".PadRight($padding), ' : ', $Request.HttpMethod) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("Content Type".PadRight($padding), ' : ', $Request.ContentType) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("Content Encoding".PadRight($padding), ' : ', $Request.ContentEncoding) -Colors ($labelColor, $seperatorColor, $valueColor)
    Write-HostColor ("Content Length".PadRight($padding), ' : ', $Request.ContentLength64) -Colors ($labelColor, $seperatorColor, $valueColor)

    # Headers
    Write-Host # Newline
    Write-HostColor ("Headers", " :`n") -Colors ($labelColor, $seperatorColor)
    if ($Request.Headers.Count -gt 0) { foreach ($key in $Request.Headers) { Write-HostColor ("`t$key", ' = ', $Request.Headers.Get($key)) -Colors ($labelColor, $seperatorColor, $valueColor) } }
    else { Write-Host "`tNo Additional Headers" -ForegroundColor $labelColor }

    # Query String
    Write-Host # Newline
    Write-HostColor ("Query String", " :`n") -Colors ($labelColor, $seperatorColor)
    if ($Request.QueryString.Count -gt 0) { foreach ($key in $Request.QueryString) { Write-HostColor ("`t$key", ' = ', $Request.QueryString.Get($key)) -Colors ($labelColor, $seperatorColor, $valueColor) } }
    else { Write-Host "`tNo Query String Keys" -ForegroundColor $labelColor }

    # Cookies
    Write-Host # Newline
    Write-HostColor ("Cookies", " :`n") -Colors ($labelColor, $seperatorColor)
    if ($Request.Cookies.Count -gt 0) { foreach ($key in $Request.Cookies) { Write-HostColor ("`t$key", ' = ', $Request.Cookies.Get($key)) -Colors ($labelColor, $seperatorColor, $valueColor) } }
    else { Write-Host "`tNo Cookies" -ForegroundColor $labelColor }

    # Certificate Info
    Write-Host # Newline
    Write-HostColor ("Certificate Information", " :`n") -Colors ($labelColor, $seperatorColor)
    $cert = $Request.GetClientCertificate()
    if ($cert -ne $null) {
        Write-HostColor ("`tCertificate Error", ' : ', $Request.ClientCertificateError, "`n") -Colors ($labelColor, $seperatorColor, $valueColor)
        $formatCertInfo = $cert | Format-List Subject,DnsNameList,Issuer,EnhancedKeyUsageList,Thumbprint,NotBefore,NotAfter,SerialNumber | Out-String | ForEach-Object { $_ -split "`n" }
        $formatCertInfo | ForEach-Object { Write-Host "`t$_" -ForegroundColor $valueColor }
    } else { Write-Host "`tNo Certificates" -ForegroundColor $labelColor }

    # Content Body
    Write-Host # Newline
    Write-HostColor ("Content Body", " :`n") -Colors ($labelColor, $seperatorColor)
    try {
        if ($Request.HasEntityBody) {
            $reader = New-Object System.IO.StreamReader ($Request.InputStream, $Request.ContentEncoding)
            $body = $reader.ReadToEnd()
            Write-Host $body -ForegroundColor $valueColor
            Write-Host # Newline
        } else { Write-Host "`tNo Content Body" -ForegroundColor $labelColor }
    } finally {
        if ($Request.InputStream -ne $null) { $Request.InputStream.Close() }
        if ($reader -ne $null) { $reader.Close() }
    }

}

#endregion Show-HTTPRequest

#====================================================================================================================================================
#######################
## Show-HTTPResponse ##
#######################

#region Show-HTTPResponse

function Show-HTTPResponse {

    param([System.Net.HttpListenerResponse]$Response)

    Write-Host "`n"
    Write-HostColor ('Sending response', ' : ') -Colors ('Yellow', 'Cyan')

    $Response | Format-List * | Out-String | Write-Host -ForegroundColor Green

}

#endregion Show-HTTPResponse

#endregion Private Functions

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>