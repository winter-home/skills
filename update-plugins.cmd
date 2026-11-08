@echo off
setlocal
title Install or update plugins

for %%C in (claude codex) do (
    call :marketplace %%C winter-home/skills winter-home-skills
    if errorlevel 1 goto failed
    call :marketplace %%C anthropics/skills anthropic-agent-skills
    if errorlevel 1 goto failed

    for %%P in (wt@winter-home-skills document-skills@anthropic-agent-skills example-skills@anthropic-agent-skills discernment-nudge@anthropic-agent-skills) do (
        call :plugin %%C %%P
        if errorlevel 1 goto failed
    )
)

echo.
echo Install/update complete. Restart Codex and Claude Code, or start new sessions.
pause
exit /b 0

:failed
echo.
echo Install/update failed. Check the error above and try again.
pause
exit /b 1

:marketplace
echo [%~1] Preparing marketplace %~3...
if "%~1"=="codex" (
    call :codex_has_entry %~3
) else (
    call :has_entry claude marketplace %~3
)
if errorlevel 2 exit /b 1
if errorlevel 1 (
    call %~1 plugin marketplace add %~2
    if errorlevel 1 exit /b 1
)
if "%~1"=="codex" (
    call codex plugin marketplace upgrade %~3
) else (
    call claude plugin marketplace update %~3
)
exit /b %errorlevel%

:plugin
echo [%~1] Installing or updating %~2...
if "%~1"=="codex" (
    call codex plugin add %~2
    exit /b
)
call :has_entry claude "" %~2
if errorlevel 2 exit /b 1
if errorlevel 1 (
    call claude plugin install %~2 --scope user
) else (
    call claude plugin update %~2 --scope user
)
exit /b %errorlevel%

:codex_has_entry
rem Read registration from Codex configuration without opening the marketplace cache.
rem Exit 3 means absent. PowerShell startup errors must not trigger registration.
powershell.exe -NoProfile -NonInteractive -Command ^
    "$ErrorActionPreference = 'Stop'; $name = '%~1';" ^
    "Add-Type -AssemblyName System.Web.Extensions;" ^
    "$json = [Web.Script.Serialization.JavaScriptSerializer]::new();" ^
    "function Read-Reply($Server, [int]$Id) {" ^
    "    $timer = [Diagnostics.Stopwatch]::StartNew();" ^
    "    do {" ^
    "        $pending = $Server.StandardOutput.ReadLineAsync();" ^
    "        $remaining = [Math]::Max(0, 15000 - [int]$timer.ElapsedMilliseconds);" ^
    "        if (-not $pending.Wait($remaining) -or $null -eq $pending.Result) {" ^
    "            throw 'Codex app server stopped responding.';" ^
    "        }" ^
    "        $reply = $json.DeserializeObject($pending.Result);" ^
    "    } until ($reply['id'] -eq $Id);" ^
    "    if ($reply['error']) { throw $reply['error']['message']; }" ^
    "    if ($null -eq $reply['result']) { throw 'Codex app server returned no result.'; }" ^
    "    return $reply['result'];" ^
    "}" ^
    "$startInfo = [Diagnostics.ProcessStartInfo]::new(" ^
    "    $env:ComSpec, '/d /c codex app-server --stdio --disable plugins --disable remote_plugin');" ^
    "$startInfo.UseShellExecute = $false; $startInfo.CreateNoWindow = $true;" ^
    "$startInfo.RedirectStandardInput = $true; $startInfo.RedirectStandardOutput = $true;" ^
    "$startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8;" ^
    "$server = $null; $status = 2;" ^
    "try {" ^
    "    $previousEncoding = [Console]::InputEncoding;" ^
    "    try {" ^
    "        [Console]::InputEncoding = [Text.UTF8Encoding]::new($false);" ^
    "        $server = [Diagnostics.Process]::Start($startInfo);" ^
    "    } finally { [Console]::InputEncoding = $previousEncoding; }" ^
    "    $client = @{name = 'wt-marketplace-registration'; version = '1.0'};" ^
    "    $initialize = @{id = 1; method = 'initialize'; params = @{clientInfo = $client}};" ^
    "    $server.StandardInput.WriteLine($json.Serialize($initialize));" ^
    "    $null = Read-Reply $server 1;" ^
    "    $server.StandardInput.WriteLine($json.Serialize(@{method = 'initialized'}));" ^
    "    $request = @{id = 2; method = 'config/read'; params = @{includeLayers = $false}};" ^
    "    $server.StandardInput.WriteLine($json.Serialize($request));" ^
    "    $result = Read-Reply $server 2;" ^
    "    $marketplaces = $result['config']['marketplaces'];" ^
    "    if ($marketplaces -isnot [Collections.IDictionary]) { throw 'Codex configuration did not include a marketplace map.'; }" ^
    "    $status = if ($marketplaces.ContainsKey($name)) { 0 } else { 3 };" ^
    "} catch {" ^
    "    [Console]::Error.WriteLine(('Could not check Codex marketplace {0}: {1}' -f $name, $_.Exception.Message));" ^
    "} finally {" ^
    "    if ($server) {" ^
    "        $server.StandardInput.Close();" ^
    "        if (-not $server.WaitForExit(3000)) { $server.Kill(); }" ^
    "        $server.Dispose();" ^
    "    }" ^
    "}" ^
    "exit $status"
if "%errorlevel%"=="0" exit /b 0
if "%errorlevel%"=="3" exit /b 1
exit /b 2

:has_entry
rem Return 0 for present, 1 for absent, and 2 for a failed query.
powershell.exe -NoProfile -Command "$json = & $env:ComSpec /d /c '%~1 plugin %~2 list --json'; if ($LASTEXITCODE -ne 0) { exit 2 }; try { $entries = ConvertFrom-Json -InputObject ($json -join [Environment]::NewLine) -ErrorAction Stop; if ('%~2' -eq 'marketplace') { $found = @($entries | Where-Object { $_.name -eq '%~3' }).Count } else { $found = @($entries | Where-Object { $_.id -eq '%~3' -and $_.scope -eq 'user' }).Count }; if ($found) { exit 0 }; exit 1 } catch { Write-Error $_; exit 2 }"
exit /b %errorlevel%
