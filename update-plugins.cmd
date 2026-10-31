@echo off
setlocal
title Update dw plugin

echo [1/4] Updating Claude marketplace...
call claude plugin marketplace update winter-home-skills
if errorlevel 1 goto failed

echo [2/4] Updating Claude plugin...
call claude plugin update dw@winter-home-skills
if errorlevel 1 goto failed

echo [3/4] Updating Codex marketplace...
call codex plugin marketplace upgrade winter-home-skills
if errorlevel 1 goto failed

echo [4/4] Updating Codex plugin...
call codex plugin add dw@winter-home-skills
if errorlevel 1 goto failed

echo.
echo Update complete. Restart Codex and Claude Code, or start new sessions.
pause
exit /b 0

:failed
echo.
echo Update failed. Check the error above and try again.
pause
exit /b 1
