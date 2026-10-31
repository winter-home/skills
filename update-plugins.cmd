@echo off
setlocal
title Install or update plugins

for %%C in (claude codex) do (
    call :marketplace %%C winter-home/skills winter-home-skills
    if errorlevel 1 goto failed
    call :marketplace %%C anthropics/skills anthropic-agent-skills
    if errorlevel 1 goto failed

    for %%P in (dw@winter-home-skills document-skills@anthropic-agent-skills example-skills@anthropic-agent-skills discernment-nudge@anthropic-agent-skills) do (
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
call :has_entry %~1 marketplace %~3
if errorlevel 2 exit /b 1
if errorlevel 1 (
    call %~1 plugin marketplace add %~2
    if errorlevel 1 exit /b 1
)
if "%~1"=="claude" (
    call claude plugin marketplace update %~3
) else (
    call codex plugin marketplace upgrade %~3
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

:has_entry
rem Return 0 for present, 1 for absent, and 2 for a failed query.
powershell.exe -NoProfile -Command "$json = & $env:ComSpec /d /c '%~1 plugin %~2 list --json'; if ($LASTEXITCODE -ne 0) { exit 2 }; try { $entries = ConvertFrom-Json -InputObject ($json -join [Environment]::NewLine) -ErrorAction Stop; if ('%~2' -eq 'marketplace') { if ('%~1' -eq 'codex') { $entries = $entries.marketplaces }; $found = @($entries | Where-Object { $_.name -eq '%~3' }).Count } else { $found = @($entries | Where-Object { $_.id -eq '%~3' -and $_.scope -eq 'user' }).Count }; if ($found) { exit 0 }; exit 1 } catch { Write-Error $_; exit 2 }"
exit /b %errorlevel%
