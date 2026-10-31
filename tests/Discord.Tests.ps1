#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.*' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'Required for Pester tests'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Required for Pester tests'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Noncredential values exercise public validation and WhatIf without authenticating.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Describe 'Discord client command surface' {
    It 'Exports the reusable client commands' {
        $commands = Get-Command -Module Discord -CommandType Function

        foreach ($name in @(
                'Connect-DiscordAccount'
                'Disconnect-DiscordAccount'
                'Get-DiscordContext'
                'Switch-DiscordContext'
                'Get-DiscordViewer'
                'Get-DiscordConfig'
                'Set-DiscordConfig'
                'Invoke-DiscordAPI'
            )) {
            ($commands.Name -contains $name) | Should-Be -Expected $true
        }
    }

    It 'Provides the connection aliases' {
        (Get-Alias -Name Connect-Discord).ResolvedCommand.Name | Should-Be -Expected 'Connect-DiscordAccount'
        (Get-Alias -Name Disconnect-Discord).ResolvedCommand.Name | Should-Be -Expected 'Disconnect-DiscordAccount'
    }

    It 'Does not export the template greeting' {
        @(Get-Command -Name Get-PSModuleTest -Module Discord -ErrorAction SilentlyContinue).Count | Should-Be -Expected 0
    }

    It 'Accepts credentials only as SecureStrings' {
        $command = Get-Command -Name Connect-DiscordAccount

        $command.Parameters.BotToken.ParameterType.FullName | Should-Be -Expected 'System.Security.SecureString'
        $command.Parameters.ClientSecret.ParameterType.FullName | Should-Be -Expected 'System.Security.SecureString'
        $command.Parameters.ContainsKey('Token') | Should-Be -Expected $false
    }
}

Describe 'Public client validation' {
    It 'Rejects unsafe REST destinations' -ForEach @(
        @{ Uri = 'http://discord.com/api/v10/users/@me' }
        @{ Uri = 'https://example.com/api/v10/users/@me' }
        @{ Uri = 'https://discord.com.example.com/api/v10/users/@me' }
        @{ Uri = 'https://discord.com:444/api/v10/users/@me' }
        @{ Uri = 'https://user@discord.com/api/v10/users/@me' }
        @{ Uri = 'https://discord.com/api/oauth2/token' }
        @{ Uri = 'https://discord.com/api/v10/../oauth2/token' }
        @{ Uri = 'https://discord.com/api/v10/users/@me#fragment' }
    ) {
        Should-Throw -ScriptBlock { Invoke-DiscordAPI -Uri $Uri }
    }

    It 'Rejects absolute paths supplied as an endpoint' {
        Should-Throw -ScriptBlock { Invoke-DiscordAPI -ApiEndpoint 'https://example.com/users/@me' }
    }

    It 'Rejects query bodies that are not dictionaries' {
        Should-Throw -ScriptBlock { Invoke-DiscordAPI -ApiEndpoint '/users/@me' -Body 'not-a-dictionary' }
    }

    It 'Rejects wildcard and reserved context names' -ForEach @(
        @{ Name = '*' }
        @{ Name = 'account?' }
        @{ Name = 'Module' }
    ) {
        Should-Throw -ScriptBlock { Get-DiscordContext -Context $Name }
    }

    It 'Requires identify and rejects installation scopes before user consent' -ForEach @(
        @{ Scope = @('guilds') }
        @{ Scope = @('identify', 'bot') }
        @{ Scope = @('identify', 'webhook.incoming') }
    ) {
        $connection = @{
            ClientID     = '123456789012345678'
            ClientSecret = ConvertTo-SecureString -String 'noncredential-test-value' -AsPlainText -Force
            Scope        = $Scope
            WhatIf       = $true
        }

        Should-Throw -ScriptBlock { Connect-DiscordAccount @connection }
    }

    It 'Rejects non-loopback, privileged, or ambiguous OAuth2 redirects' -ForEach @(
        @{ RedirectUri = 'http://example.com:53682/' }
        @{ RedirectUri = 'https://localhost:53682/' }
        @{ RedirectUri = 'http://localhost:80/' }
        @{ RedirectUri = 'http://localhost:53682/callback' }
        @{ RedirectUri = 'http://localhost:53682/?other=value' }
        @{ RedirectUri = 'http://localhost:53682/#fragment' }
    ) {
        $connection = @{
            ClientID     = '123456789012345678'
            ClientSecret = ConvertTo-SecureString -String 'noncredential-test-value' -AsPlainText -Force
            RedirectUri  = $RedirectUri
            WhatIf       = $true
        }

        Should-Throw -ScriptBlock { Connect-DiscordAccount @connection }
    }

    It 'Previews bot sign-in without contacting Discord or creating a context' {
        $token = ConvertTo-SecureString -String 'noncredential-test-value' -AsPlainText -Force

        @(Connect-DiscordAccount -BotToken $token -WhatIf).Count | Should-Be -Expected 0
    }

    It 'Previews a mutating REST call without requiring credentials' {
        $request = @{
            ApiEndpoint = '/users/@me'
            Method      = 'PATCH'
            Body        = @{ username = 'unused-preview-value' }
            WhatIf      = $true
        }

        @(Invoke-DiscordAPI @request).Count | Should-Be -Expected 0
    }
}
