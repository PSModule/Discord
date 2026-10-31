function Invoke-DiscordRequest {
    <#
        .SYNOPSIS
        Send a resolved Discord HTTP request.

        .DESCRIPTION
        Handle JSON responses and bounded HTTP 429 retries. Never return credential-bearing transport objects.

        .EXAMPLE
        Invoke-DiscordRequest -Uri $uri -Method GET -AuthType Bot -Token $token

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The sanitized request and parsed response envelope.

        .LINK
        https://psmodule.io/Discord/Functions/API/Invoke-DiscordAPI/
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # The validated destination.
        [Parameter(Mandatory)]
        [uri] $Uri,

        # The resolved HTTP method.
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS')]
        [string] $Method,

        # The resolved authorization scheme; token exchange does not attach an access token.
        [Parameter()]
        [ValidateSet('Bot', 'Bearer')]
        [string] $AuthType,

        # The access token, kept secure until the HTTP boundary.
        [Parameter()]
        [securestring] $Token,

        # An already serialized body, or a form dictionary whose secret fields are SecureStrings.
        [Parameter()]
        [AllowNull()]
        [object] $Body,

        # The content type for the resolved body.
        [Parameter()]
        [string] $ContentType = 'application/json',

        # Additional attempts for HTTP 429 only.
        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $RetryCount = 0,

        # Fallback delay when Discord provides no retry delay.
        [Parameter()]
        [ValidateRange(0, 86400)]
        [double] $RetryInterval = 1,

        # Per-request network timeout.
        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds = 100
    )

    $headers = @{ Accept = 'application/json' }
    $form = $null
    try {
        if ($null -ne $Token) {
            $plainToken = ConvertFrom-SecureString -SecureString $Token -AsPlainText
            if ([string]::IsNullOrWhiteSpace($plainToken) -or $plainToken -match '[\x00-\x20\x7f-\uffff]') {
                throw [System.ArgumentException]::new('Supply a raw, nonempty Discord token without a scheme prefix or whitespace.')
            }
            if ([string]::IsNullOrEmpty($AuthType)) {
                throw [System.ArgumentException]::new('An authentication scheme is required with an access token.')
            }
            $headers.Authorization = "$AuthType $plainToken"
            $plainToken = $null
        }

        $parameters = @{
            Uri                = $Uri
            Method             = $Method
            Headers            = $headers
            UserAgent          = $script:UserAgent
            ContentType        = $ContentType
            TimeoutSec         = $TimeoutSeconds
            MaximumRedirection = 0
            MaximumRetryCount  = 0
            SkipHttpErrorCheck = $true
            ErrorAction        = 'Stop'
            Verbose            = $false
            Debug              = $false
        }
        if ($PSBoundParameters.ContainsKey('Body')) {
            if ($Body -is [System.Collections.IDictionary]) {
                $form = @{}
                foreach ($key in $Body.Keys) {
                    if ($Body[$key] -is [securestring]) {
                        $form[$key] = ConvertFrom-SecureString -SecureString $Body[$key] -AsPlainText
                    } else {
                        $form[$key] = $Body[$key]
                    }
                }
                $parameters.Body = $form
            } else {
                $parameters.Body = $Body
            }
        }

        for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
            Write-Verbose "Sending Discord $Method request."
            try {
                $response = Invoke-WebRequest @parameters
            } catch [System.Net.Http.HttpRequestException], [System.Net.WebException], [System.Threading.Tasks.TaskCanceledException] {
                $failure = $_
                $message = 'Discord HTTP transport failed ({0}). Check connectivity and the request timeout.' -f
                $failure.Exception.GetType().Name
                throw [System.Net.Http.HttpRequestException]::new($message)
            }

            $status = [int] $response.StatusCode
            $content = $response.Content
            if ($content -is [byte[]]) {
                $content = [System.Text.Encoding]::UTF8.GetString($content)
            }
            $parsed = $null
            $responseType = $response.Headers['Content-Type'] -join ','
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                if ($responseType -match 'json') {
                    try {
                        $parsed = ConvertFrom-Json -InputObject $content -Depth 100 -ErrorAction Stop
                    } catch [System.ArgumentException] {
                        throw [System.FormatException]::new("Discord returned invalid JSON (HTTP $status).")
                    }
                } else {
                    $parsed = $content
                }
            }

            if ($status -eq 429 -and $attempt -lt $RetryCount) {
                $delayValue = $null
                if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties['retry_after']) {
                    $delayValue = $parsed.retry_after
                } elseif ($response.Headers['Retry-After']) {
                    $delayValue = @($response.Headers['Retry-After'])[0]
                }

                $delay = $RetryInterval
                if ($null -eq $delayValue) {
                    Write-Warning 'Discord omitted its rate-limit delay. Using the configured RetryInterval.'
                } else {
                    $text = [System.Convert]::ToString($delayValue, [cultureinfo]::InvariantCulture)
                    if (-not [double]::TryParse(
                            $text, [System.Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref] $delay
                        ) -or -not [double]::IsFinite($delay) -or $delay -lt 0) {
                        throw [System.InvalidOperationException]::new('Discord returned an invalid rate-limit delay.')
                    }
                }
                Write-Verbose 'Waiting for the Discord rate limit before retrying.'
                Start-Sleep -Seconds $delay
                continue
            }

            if ($status -lt 200 -or $status -ge 300) {
                $message = "Discord request failed (HTTP $status). Check credentials, scopes, permissions, and request parameters."
                throw [System.Net.Http.HttpRequestException]::new($message, $null, [System.Net.HttpStatusCode] $status)
            }

            $responseHeaders = [ordered]@{}
            foreach ($key in ($response.Headers.Keys | Sort-Object)) {
                if ($key -notin @('Authorization', 'Proxy-Authorization', 'Set-Cookie')) {
                    $responseHeaders[$key] = $response.Headers[$key] -join ', '
                }
            }

            [pscustomobject]@{
                Request           = [pscustomobject]@{ Method = $Method; Uri = $Uri }
                Response          = $parsed
                Headers           = [pscustomobject] $responseHeaders
                StatusCode        = $status
                StatusDescription = [string] $response.StatusDescription
            }
            return
        }
    } finally {
        $headers.Remove('Authorization')
        $plainToken = $null
        if ($null -ne $form) {
            $form.Clear()
        }
    }
}
