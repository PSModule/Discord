#Requires -Modules @{ ModuleName = 'Context'; ModuleVersion = '8.1.3' }

function Disconnect-DiscordAccount {
    <#
        .SYNOPSIS
        Remove a local saved Discord connection.

        .DESCRIPTION
        Delete one context and clear the default if it selected that context.
        This does not refresh or remotely revoke tokens.

        .EXAMPLE
        ```powershell
        Disconnect-DiscordAccount
        ```

        .EXAMPLE
        ```powershell
        Get-DiscordContext -Context 'personal' | Disconnect-DiscordAccount
        ```

        .INPUTS
        System.String

        A saved context name.

        .INPUTS
        DiscordContext

        A saved connection.

        .OUTPUTS
        None

        The local connection is removed without returning credentials.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Disconnect-DiscordAccount/
    #>
    [Alias('Disconnect-Discord')]
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # A saved name or typed connection; omit to remove the default.
        [Parameter(ValueFromPipeline)]
        [Alias('Name')]
        [object] $Context
    )

    process {
        $resolved = Resolve-DiscordContext -Context $Context
        Assert-DiscordContextName -Name $resolved.Name
        if ($PSCmdlet.ShouldProcess($resolved.Name, 'Remove local Discord context')) {
            $parameters = @{
                ID          = $resolved.Name
                Vault       = $script:Discord.ContextVault
                ErrorAction = 'Stop'
                Verbose     = $false
                Debug       = $false
                Confirm     = $false
            }
            Remove-Context @parameters
            Initialize-DiscordConfig
            if ($script:Discord.Config.DefaultContext -eq $resolved.Name) {
                Set-DiscordConfig -DefaultContext '' -Confirm:$false
            }
        }
    }
}
