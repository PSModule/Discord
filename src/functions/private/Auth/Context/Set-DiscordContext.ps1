#Requires -Modules @{ ModuleName = 'Context'; ModuleVersion = '8.1.3' }

function Set-DiscordContext {
    <#
        .SYNOPSIS
        Save a verified connection in the Discord vault.

        .DESCRIPTION
        Keep the vault key separate from UserID and optionally select the saved connection.

        .EXAMPLE
        Set-DiscordContext -Context $connection -Default

        .OUTPUTS
        None

        The connection is persisted without emitting credentials.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # A connection whose identity has already been verified.
        [Parameter(Mandatory)]
        [DiscordContext] $Context,

        # Select this saved context as the module default.
        [Parameter()]
        [switch] $Default
    )

    Assert-DiscordContext -Context $Context
    if ($Context.UserID -cnotmatch '^\d{1,20}$' -or [string]::IsNullOrWhiteSpace($Context.UserName)) {
        throw [System.InvalidOperationException]::new('A verified Discord user ID and username are required before saving a context.')
    }

    if ($PSCmdlet.ShouldProcess($Context.Name, 'Save Discord context')) {
        $Context.ID = $Context.Name
        $parameters = @{
            ID          = $Context.Name
            Context     = $Context
            Vault       = $script:Discord.ContextVault
            ErrorAction = 'Stop'
            Verbose     = $false
            Debug       = $false
            Confirm     = $false
        }
        Set-Context @parameters
        if ($Default) {
            Set-DiscordConfig -DefaultContext $Context.Name -Confirm:$false
        }
    }
}
