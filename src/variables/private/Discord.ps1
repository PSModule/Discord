$script:Discord = [pscustomobject]@{
    ContextVault  = 'PSModule.Discord'
    DefaultConfig = [DiscordConfig]::new()
    Config        = $null
}

$script:UserAgent = 'DiscordBot (https://github.com/PSModule/Discord, {0})' -f $ExecutionContext.SessionState.Module.Version
