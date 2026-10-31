# Discord

A PowerShell client for Discord, for people using the terminal and scripts using a bot.
The client provides authentication, encrypted saved contexts, the authenticated identity,
and a reusable REST command. It does not provide an MCP server, a Gateway client,
or server, channel, and message management commands.

## Requirements

- PowerShell 7.4 or later.
- [Context](https://github.com/PSModule/Context) 8.1.3 or later, installed as a module dependency.
- A Discord application and the credentials described below.

```powershell
Install-PSResource -Name Discord
Import-Module -Name Discord
```

## Connect as a bot

Create or select an application in the [Discord Developer Portal][applications].
On its **Bot** page, obtain the bot token. The token is not the application's client
secret and is not a normal Discord account token.

```powershell
$botToken = Read-Host -Prompt 'Bot token' -AsSecureString
Connect-Discord -BotToken $botToken
Get-DiscordViewer
```

The client validates the token with `GET /users/@me` before saving it. Installing
the bot in a server is not required for this identity lookup. Other REST operations
still require the bot's permissions and access to their resources.

## Connect interactively as a user

Configure an application you control in the [Developer Portal][applications]:

1. Copy the application ID, used as `ClientID`.
2. Obtain its **OAuth2 client secret**, not its bot token.
3. Under **OAuth2 > Redirects**, register exactly `http://localhost:53682/`.
   The scheme, host, port, path, and trailing slash must match the value passed to the command.

```powershell
$clientSecret = Read-Host -Prompt 'OAuth2 client secret' -AsSecureString
$connection = @{
    ClientID     = 'YOUR_APPLICATION_ID'
    ClientSecret = $clientSecret
    RedirectUri  = 'http://localhost:53682/'
}
Connect-Discord @connection
Get-DiscordViewer
```

The command starts a temporary loopback HTTP listener, opens the authorization
page, validates the returned state and issuer, and exchanges the authorization
code using S256 PKCE and the client secret. The listener closes on success,
failure, or timeout. Use `-NoBrowser` to open the displayed authorization URL
yourself in a browser on the same machine. `-TimeoutSeconds` controls the wait
for consent and defaults to 180 seconds.

The redirect URI must use HTTP on `localhost` or `127.0.0.1`, an explicit
nonprivileged port, and a path ending in `/`. If the port is occupied or the OS
does not permit the listener, select another port, register the new exact URI,
and pass it as `RedirectUri`.

The default OAuth2 scope is only `identify`. Additional supported user scopes
can be supplied with `-Scope @('identify', 'guilds')`. Installation scopes such
as `bot` and `webhook.incoming` are not accepted by this user sign-in command.
User access is limited to the granted scopes and Discord's supported OAuth2
endpoints. This is not a self-bot or normal-account session-token login.

[Discord's authorization server metadata][metadata] advertises S256 PKCE and
public-client token authentication. This client deliberately uses the documented
confidential application flow and requires a client secret; it does not assume
that every Discord application qualifies for secretless sign-in. Do not distribute
your application's client secret to other users or embed it in scripts.

## Saved contexts

Successful connections are saved in the Context vault `PSModule.Discord`.
Tokens, refresh tokens, and OAuth2 client secrets remain `SecureString` values
and are encrypted on disk by Context. Protect your local account and vault;
context objects and vault backups are sensitive even though normal output
does not display plaintext credentials.

The most recent connection becomes the default unless `-NotDefault` is used.
The default context and its settings are restored in later PowerShell sessions
without another sign-in. OAuth2 access tokens are refreshed automatically
when they expire or have 30 seconds or less remaining, and rotated credentials
are saved back to the same context.

```powershell
Connect-Discord -BotToken $botToken -Name 'automation'
Connect-Discord @connection -Name 'personal' -NotDefault

Get-DiscordContext
Get-DiscordContext -ListAvailable
Switch-DiscordContext -Context 'personal'
Get-DiscordViewer -Context 'automation'
```

Without a custom name, bot contexts are named `Bot-<user ID>` and user contexts
are named `User-<user ID>-<client ID>`. Discord user IDs are preserved as strings,
not rounded numbers. Different accounts and applications can coexist.

```powershell
Disconnect-Discord -Context 'personal'
```

Disconnect removes only that local saved context. It does not revoke the remote
grant or reset the bot token. Removing the default leaves no default selected;
use `Switch-DiscordContext` to choose another saved context.

## Call the REST API

```powershell
$result = Invoke-DiscordAPI -ApiEndpoint '/users/@me'
$result.Response
$result.StatusCode
$result.Headers

$query = @{ limit = 10 }
Invoke-DiscordAPI -ApiEndpoint '/users/@me/guilds' -Body $query -Context 'personal'
```

GET and HEAD dictionary bodies become URL-encoded query parameters, with
Boolean values encoded as `true` or `false`. Other
dictionary and object bodies become JSON by default. The `Query` alias for
`Body` is available for GET requests. The client does not add GitHub pagination
parameters or collect additional pages automatically.

Responses have `Request`, `Response`, `Headers`, `StatusCode`, and
`StatusDescription` properties. `Response` contains parsed JSON, or `$null` for
an empty response such as HTTP 204. `Request` contains only the method and URI,
not authorization headers, tokens, or request bodies.

Bot contexts use `Authorization: Bot ...`; user contexts use `Bearer ...`.
Only HTTPS requests to `discord.com` under `/api/v10/` are accepted, including
when using the full `-Uri` parameter. Redirects are not followed. API failures
throw errors instead of returning success-shaped results.

HTTP 429 responses are retried up to `RetryCount`, honoring Discord's
`retry_after` seconds or `Retry-After` header, including fractional seconds.
Other errors, including 401 and 403, are not retried. There is no cross-process
rate-limit scheduler.

```powershell
Get-DiscordConfig
Set-DiscordConfig -RetryCount 3 -RetryInterval 1 -TimeoutSeconds 100
```

`RetryInterval` is used only when a 429 response omits both delay fields, with a
warning. `TimeoutSeconds` in module configuration is the HTTP request timeout,
separate from the interactive consent timeout.

## Commands

| Command | Purpose |
| --- | --- |
| `Connect-DiscordAccount` (`Connect-Discord`) | Authenticate a bot or OAuth2 user and save its verified context. |
| `Disconnect-DiscordAccount` (`Disconnect-Discord`) | Remove a local saved context without revoking remote credentials. |
| `Get-DiscordContext` | Get the default, a named context, or all saved contexts. |
| `Switch-DiscordContext` | Select a saved context as the default. |
| `Get-DiscordViewer` | Retrieve the authenticated user or bot from `/users/@me`. |
| `Get-DiscordConfig` | Read client settings. |
| `Set-DiscordConfig` | Save client settings and the default context selection. |
| `Invoke-DiscordAPI` | Call the Discord REST API with a saved context or context object. |

Use `Get-Help -Name <Command> -Examples` for more examples. Commands that change
local state, and REST calls that change remote state, support `-WhatIf`.

## Development

Source follows the [PSModule/GitHub](https://github.com/PSModule/GitHub) layout:
typed public classes, private module variables, grouped public and private
functions, a header, import-time initialization, and a framework manifest overlay. The
[PSModule framework](https://github.com/PSModule/Process-PSModule) builds and
packages the module.

The framework builds and imports the module before running the tests. Tests do
not import or assemble the module themselves. Local contract tests exercise
public validation without replacing functions with mocks. Live integration
tests use real Discord credentials and read-only resources.

```powershell
$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
Invoke-ScriptAnalyzer -Path .\src -Recurse -Settings .\.github\linters\.powershell-psscriptanalyzer.psd1
```

The template greeting `Get-PSModuleTest` is not part of the client command surface.

### GitHub Actions credentials

The caller uses Process-PSModule `v8` and Pester 6.1. Its explicit `TestData`
payload exposes only the following values to the module test jobs:

| GitHub setting | Kind | Purpose |
| --- | --- | --- |
| `DISCORD_BOT_TOKEN` | Repository secret | Required for unattended live bot authentication, identity, REST, and encrypted Context tests. |
| `DISCORD_TEST_GUILD_ID` | Repository variable | Optional existing server to read with the REST client. |
| `DISCORD_TEST_CHANNEL_ID` | Repository variable | Optional existing channel to read; it must belong to the configured server when both IDs are supplied. |

Invite the bot to the test server with permission to view the selected channel.
These tests do not send messages or create, edit, or delete Discord resources.
They create and clean up only their own local Context entries. Missing bot
credentials fail the live test setup with an actionable error; optional resource
tests are reported as skipped when their IDs are absent.

The framework also needs its standard publishing and GitHub App credentials:
`PSGALLERY_API_KEY`, `SHELLY_CLIENT_ID`, and `SHELLY_PRIVATE_KEY`, supplied as
repository or available organization secrets. The old `APIKey` workflow input
is replaced by `PSGALLERY_API_KEY`.

The existing `release:major`, `release:minor`, `release:patch`, `release:skip`,
and `release:prerelease` repository labels are explicitly mapped to the v8
release settings. Legacy unprefixed labels remain accepted.

Initial user OAuth2 consent is interactive, not a CI login technique. A stored
user context supports unattended refresh after consent, but a disposable CI
runner cannot safely reuse a static refresh-token secret indefinitely when
Discord rotates it. Bot-based live CI avoids that rotation and matrix-concurrency
problem. User sign-in and consent remain a separate interactive check.

## References

- [Discord OAuth2][oauth2]
- [Authorization server metadata][metadata]
- [Current user and the `identify` scope][user]
- [Discord rate limits][rate-limits]

[applications]: https://discord.com/developers/applications
[oauth2]: https://docs.discord.com/developers/topics/oauth2
[metadata]: https://discord.com/.well-known/oauth-authorization-server
[user]: https://docs.discord.com/developers/resources/user
[rate-limits]: https://docs.discord.com/developers/topics/rate-limits
