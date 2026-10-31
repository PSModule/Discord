#Requires -Modules Discord

<#
    .SYNOPSIS
    Connect a bot and read its Discord identity.

    .DESCRIPTION
    Save a bot context without changing the selected default, then use both the identity command and REST client.

    .EXAMPLE
    $token = Read-Host -Prompt 'Bot token' -AsSecureString
    .\examples\General.ps1 -BotToken $token

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    The bot identity and its REST response.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # A raw bot token entered securely, not a normal account token.
    [Parameter(Mandatory)]
    [securestring] $BotToken
)

$ErrorActionPreference = 'Stop'

if ($PSCmdlet.ShouldProcess('Discord bot connection', 'Save context and read identity')) {
    $context = Connect-Discord -BotToken $BotToken -NotDefault -PassThru
    Get-DiscordViewer -Context $context
    $result = Invoke-DiscordAPI -ApiEndpoint '/users/@me' -Context $context
    $result.Response
}
