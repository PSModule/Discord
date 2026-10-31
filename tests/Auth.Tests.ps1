#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.*' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Required for Pester tests'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'The framework injects the CI secret through TestData; it is secured immediately without logging.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Describe 'Live Discord client foundation' -Tag 'Integration' {
    BeforeAll {
        $rawToken = [Environment]::GetEnvironmentVariable('DISCORD_BOT_TOKEN')
        if ([string]::IsNullOrWhiteSpace($rawToken)) {
            throw 'Set the DISCORD_BOT_TOKEN repository secret and pass it through workflow TestData to run the live tests.'
        }
        $token = ConvertTo-SecureString -String $rawToken -AsPlainText -Force
        $rawToken = $null
        $runID = [Environment]::GetEnvironmentVariable('GITHUB_RUN_ID')
        if ([string]::IsNullOrWhiteSpace($runID)) {
            $runID = "Local-$PID"
        }
        $runnerOS = [Environment]::GetEnvironmentVariable('RUNNER_OS')
        if ([string]::IsNullOrWhiteSpace($runnerOS)) {
            $runnerOS = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription -replace '[^a-zA-Z0-9]', ''
        }
        $contextName = "DiscordClient-$runnerOS-$runID"
        $secondContextName = "$contextName-Second"
        $originalConfig = Get-DiscordConfig
        $context = Connect-DiscordAccount -BotToken $token -Name $contextName -NotDefault -PassThru
    }

    AfterAll {
        if ($contextName) {
            foreach ($saved in @(Get-DiscordContext -ListAvailable)) {
                if ($saved.Name -in @($contextName, $secondContextName)) {
                    Disconnect-DiscordAccount -Context $saved.Name -Confirm:$false
                }
            }
        }
        if ($null -ne $originalConfig) {
            $restore = @{
                DefaultContext = $originalConfig.DefaultContext
                RetryCount     = $originalConfig.RetryCount
                RetryInterval  = $originalConfig.RetryInterval
                TimeoutSeconds = $originalConfig.TimeoutSeconds
                Confirm        = $false
            }
            Set-DiscordConfig @restore
        }
        if ($null -ne $token) {
            $token.Dispose()
        }
    }

    It 'Authenticates a real bot and stores its verified identity securely' {
        $context.GetType().Name | Should-Be -Expected 'DiscordContext'
        $context.Name | Should-Be -Expected $contextName
        $context.Type | Should-Be -Expected 'Bot'
        $context.AuthType | Should-Be -Expected 'Bot'
        ($context.Token -is [securestring]) | Should-Be -Expected $true
        ($context.UserID -is [string]) | Should-Be -Expected $true
        ($context.UserID -cmatch '^\d{1,20}$') | Should-Be -Expected $true
        ([string]::IsNullOrWhiteSpace($context.UserName)) | Should-Be -Expected $false
    }

    It 'Returns the same authenticated identity through the public identity command' {
        $viewer = Get-DiscordViewer -Context $contextName

        $viewer.id | Should-Be -Expected $context.UserID
        $viewer.username | Should-Be -Expected $context.UserName
        $viewer.bot | Should-Be -Expected $true
    }

    It 'Reconstructs a separate typed context from the real encrypted Context store' {
        $restored = Get-DiscordContext -Context $contextName

        $restored.GetType().Name | Should-Be -Expected 'DiscordContext'
        [object]::ReferenceEquals($restored, $context) | Should-Be -Expected $false
        $restored.ID | Should-Be -Expected $contextName
        $restored.UserID | Should-Be -Expected $context.UserID
        ($restored.Token -is [securestring]) | Should-Be -Expected $true
        (Get-DiscordViewer -Context $restored).id | Should-Be -Expected $context.UserID
    }

    It 'Uses named and default connections without mixing their stored identity' {
        try {
            Connect-DiscordAccount -BotToken $token -Name $secondContextName -NotDefault
            Switch-DiscordContext -Context $secondContextName

            (Get-DiscordContext).Name | Should-Be -Expected $secondContextName
            (Get-DiscordViewer).id | Should-Be -Expected $context.UserID
            (Get-DiscordContext -Context $contextName).Name | Should-Be -Expected $contextName
            $available = @(Get-DiscordContext -ListAvailable).Name
            ($available -contains $contextName) | Should-Be -Expected $true
            ($available -contains $secondContextName) | Should-Be -Expected $true
            ($available -contains 'Module') | Should-Be -Expected $false
        } finally {
            Set-DiscordConfig -DefaultContext $originalConfig.DefaultContext -Confirm:$false
            if (@(Get-DiscordContext -ListAvailable).Name -contains $secondContextName) {
                Disconnect-DiscordAccount -Context $secondContextName -Confirm:$false
            }
        }
    }

    It 'Saves settings through the real Context API without exposing mutable cached state' {
        try {
            Set-DiscordConfig -RetryCount 0 -RetryInterval 2 -TimeoutSeconds 25
            $config = Get-DiscordConfig

            $config.RetryCount | Should-Be -Expected 0
            $config.RetryInterval | Should-Be -Expected 2
            $config.TimeoutSeconds | Should-Be -Expected 25
            $config.RetryCount = 8
            (Get-DiscordConfig).RetryCount | Should-Be -Expected 0
        } finally {
            $restore = @{
                RetryCount     = $originalConfig.RetryCount
                RetryInterval  = $originalConfig.RetryInterval
                TimeoutSeconds = $originalConfig.TimeoutSeconds
                Confirm        = $false
            }
            Set-DiscordConfig @restore
        }
    }

    It 'Returns parsed REST results without credential-bearing request metadata' {
        $result = Invoke-DiscordAPI -ApiEndpoint '/users/@me' -Context $contextName

        $result.StatusCode | Should-Be -Expected 200
        $result.Response.id | Should-Be -Expected $context.UserID
        ($result.PSObject.Properties.Name -join ',') | Should-Be -Expected 'Request,Response,Headers,StatusCode,StatusDescription'
        ($result.Request.PSObject.Properties.Name -join ',') | Should-Be -Expected 'Method,Uri'
        $result.Request.Uri.AbsoluteUri | Should-Be -Expected 'https://discord.com/api/v10/users/@me'
    }

    It 'Accepts a full official API URI and an explicit typed connection' {
        $result = Invoke-DiscordAPI -Uri 'https://discord.com/api/v10/users/@me' -Context $context

        $result.StatusCode | Should-Be -Expected 200
        $result.Response.id | Should-Be -Expected $context.UserID
    }

    It 'Raises a real HTTP error instead of returning a success-shaped result' {
        $request = @{
            ApiEndpoint = '/psmodule-client-nonexistent-route'
            Context     = $context
            RetryCount  = 0
        }

        Should-Throw -ScriptBlock { Invoke-DiscordAPI @request } -ExceptionMessage '*HTTP 404*'
    }

    It 'Removes only the selected local context without revoking the real bot token' {
        try {
            Connect-DiscordAccount -BotToken $token -Name $secondContextName -NotDefault
            Disconnect-DiscordAccount -Context $secondContextName -Confirm:$false

            (@(Get-DiscordContext -ListAvailable).Name -contains $secondContextName) | Should-Be -Expected $false
            (Get-DiscordViewer -Context $contextName).id | Should-Be -Expected $context.UserID
        } finally {
            if (@(Get-DiscordContext -ListAvailable).Name -contains $secondContextName) {
                Disconnect-DiscordAccount -Context $secondContextName -Confirm:$false
            }
        }
    }
}

Describe 'Configured Discord read-only resources' -Tag 'Integration' {
    BeforeAll {
        $guildID = [Environment]::GetEnvironmentVariable('DISCORD_TEST_GUILD_ID')
        $channelID = [Environment]::GetEnvironmentVariable('DISCORD_TEST_CHANNEL_ID')
        $resourceContextName = "DiscordResources-$PID"
        $resourceContext = $null
        $resourceToken = $null
        if (-not [string]::IsNullOrWhiteSpace($guildID) -or -not [string]::IsNullOrWhiteSpace($channelID)) {
            $rawToken = [Environment]::GetEnvironmentVariable('DISCORD_BOT_TOKEN')
            if ([string]::IsNullOrWhiteSpace($rawToken)) {
                throw 'DISCORD_BOT_TOKEN is required to read the configured Discord test resources.'
            }
            $resourceToken = ConvertTo-SecureString -String $rawToken -AsPlainText -Force
            $rawToken = $null
            $resourceContext = Connect-DiscordAccount -BotToken $resourceToken -Name $resourceContextName -NotDefault -PassThru
        }
    }

    AfterAll {
        if ($null -ne $resourceContext) {
            Disconnect-DiscordAccount -Context $resourceContextName -Confirm:$false
        }
        if ($null -ne $resourceToken) {
            $resourceToken.Dispose()
        }
    }

    It 'Reads the configured guild with the supported with_counts query' {
        if ([string]::IsNullOrWhiteSpace($guildID)) {
            Set-ItResult -Skipped -Because 'The optional DISCORD_TEST_GUILD_ID repository variable is not configured.'
            return
        }

        $query = @{ with_counts = $true }
        $result = Invoke-DiscordAPI -ApiEndpoint "/guilds/$guildID" -Query $query -Context $resourceContext

        $result.Response.id | Should-Be -Expected $guildID
        $result.Request.Uri.Query | Should-Be -Expected '?with_counts=true'
        $query.Count | Should-Be -Expected 1
    }

    It 'Reads the configured channel without changing its contents' {
        if ([string]::IsNullOrWhiteSpace($channelID)) {
            Set-ItResult -Skipped -Because 'The optional DISCORD_TEST_CHANNEL_ID repository variable is not configured.'
            return
        }

        $result = Invoke-DiscordAPI -ApiEndpoint "/channels/$channelID" -Context $resourceContext

        $result.Response.id | Should-Be -Expected $channelID
        if (-not [string]::IsNullOrWhiteSpace($guildID)) {
            $result.Response.guild_id | Should-Be -Expected $guildID
        }
    }
}
