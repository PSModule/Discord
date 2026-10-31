#Requires -Modules @{ ModuleName = 'Context'; ModuleVersion = '8.1.3' }

function Get-DiscordContext {
    <#
        .SYNOPSIS
        Get a saved Discord connection.

        .DESCRIPTION
        Restore the default, one named context, or all saved contexts from the encrypted Context vault.

        .EXAMPLE
        ```powershell
        Get-DiscordContext
        ```

        .EXAMPLE
        ```powershell
        Get-DiscordContext -Context 'automation'
        ```

        .EXAMPLE
        ```powershell
        Get-DiscordContext -ListAvailable
        ```

        .INPUTS
        None

        You can't pipe objects to Get-DiscordContext.

        .OUTPUTS
        DiscordContext

        Typed saved connections, sorted by name.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Context/Get-DiscordContext/
    #>
    [OutputType([DiscordContext])]
    [CmdletBinding(DefaultParameterSetName = 'Get default context')]
    param(
        # The exact saved name.
        [Parameter(Mandatory, ParameterSetName = 'Get named context')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $Context,

        # Return all saved connections, excluding module settings.
        [Parameter(Mandatory, ParameterSetName = 'List available contexts')]
        [switch] $ListAvailable
    )

    if ($PSBoundParameters.ContainsKey('Context')) {
        Assert-DiscordContextName -Name $Context
    }
    Initialize-DiscordConfig
    if ($ListAvailable) {
        $id = '*'
    } elseif ($PSBoundParameters.ContainsKey('Context')) {
        $id = $Context
    } else {
        $id = $script:Discord.Config.DefaultContext
        if ([string]::IsNullOrWhiteSpace($id)) {
            Write-Warning 'No default Discord context is selected. Run Connect-Discord or Switch-DiscordContext.'
            return
        }
        Assert-DiscordContextName -Name $id
    }

    $parameters = @{
        ID            = $id
        Vault         = $script:Discord.ContextVault
        ErrorAction   = 'Stop'
        WarningAction = 'Stop'
        Verbose       = $false
        Debug         = $false
    }
    $items = @(Get-Context @parameters | Where-Object { $_.ID -ne $script:Discord.DefaultConfig.ID })
    if (-not $ListAvailable -and $items.Count -eq 0) {
        throw [System.InvalidOperationException]::new("Discord context '$id' was not found. Run Connect-Discord to create it.")
    }

    foreach ($item in ($items | Sort-Object -Property Name)) {
        $restored = [DiscordContext]::new([pscustomobject] $item)
        Assert-DiscordContextName -Name $restored.Name
        if ($restored.ID -ne $restored.Name) {
            throw [System.InvalidOperationException]::new('A saved Discord context has an inconsistent ID. Run Connect-Discord again.')
        }
        $restored
    }
}
