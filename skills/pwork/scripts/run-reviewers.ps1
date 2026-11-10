#Requires -Version 7.2
param(
    [Parameter(Mandatory)][string]$Spec,
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)][string]$BriefFile,
    [string]$Repo = (Get-Location).Path,
    [string]$CodexModel,
    [string]$ClaudeModel = 'opus',
    [ValidateSet('read-only', 'workspace-write', 'danger-full-access')][string]$CodexSandbox = 'read-only',
    [int]$TimeoutMinutes = 60,
    [ValidatePattern('^[0-9a-fA-F]{40,64}\.\.[0-9a-fA-F]{40,64}$')][string]$CommitRange,
    [switch]$Job,
    [string]$SourceDirsFile
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    $out = git -C $Repo @args
    if ($LASTEXITCODE -ne 0) { throw "git $args failed ($LASTEXITCODE)" }
    $out
}

# Detects tracked edits and added/removed untracked files; edits inside existing untracked files are not covered.
function Get-TreeFingerprint {
    $text = (@(Invoke-Git status --porcelain=v1 -uall) + @(Invoke-Git diff HEAD --binary)) -join "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
}

if ($Job -and $CommitRange) { throw 'Job and CommitRange cannot be combined; specify the target in the brief.' }
$counts = [ordered]@{ c = @(0, 0); s = @(0, 0); a = @(0, 0) }
if ($Job) {
    if (-not [regex]::IsMatch($Spec, '\A[0-2]{2}\z')) { throw 'Job requires two digits, each 0-2.' }
    $counts.c = @([int][string]$Spec[0], [int][string]$Spec[1])
}
elseif ([regex]::IsMatch($Spec, '\A[0-2]{3}\z')) {
    # Legacy order: Codex code, Claude code, Claude simplicity.
    $counts.c = @([int][string]$Spec[0], [int][string]$Spec[1])
    $counts.s = @(0, [int][string]$Spec[2])
}
elseif ([regex]::IsMatch($Spec, '\A(?:[csa][0-2]{2})+\z')) {
    $seen = @{}
    foreach ($groupMatch in [regex]::Matches($Spec, '([csa])([0-2])([0-2])')) {
        $key = $groupMatch.Groups[1].Value
        if ($seen.ContainsKey($key)) { throw "Duplicate reviewer group: $key" }
        $seen[$key] = $true
        $counts[$key] = @([int]$groupMatch.Groups[2].Value, [int]$groupMatch.Groups[3].Value)
    }
}
else { throw 'Review requires c/s/a groups such as c11s01a11, or three legacy digits.' }
$codexCount = 0
$claudeCount = 0
foreach ($pair in $counts.Values) {
    $codexCount += $pair[0]
    $claudeCount += $pair[1]
}
if ($codexCount + $claudeCount -eq 0) { throw "Spec $Spec requests no reviewers." }

$Repo = [IO.Path]::GetFullPath((git -C $Repo rev-parse --show-toplevel))
if ($CommitRange) {
    $rangeParts = $CommitRange -split '\.\.'
    [void](Invoke-Git rev-parse --verify "$($rangeParts[0])^{tree}")
    [void](Invoke-Git rev-parse --verify "$($rangeParts[1])^{commit}")
}
$BriefFile = (Resolve-Path -LiteralPath $BriefFile).Path
$sourceDirs = @()
if ($SourceDirsFile) {
    $sourcePaths = Get-Content -LiteralPath $SourceDirsFile -Raw -Encoding utf8 | ConvertFrom-Json -NoEnumerate
    if ($sourcePaths -isnot [array]) { throw 'SourceDirsFile must contain a JSON array of absolute directory paths.' }
    $sourceDirs = @($sourcePaths | ForEach-Object {
            if ($_ -isnot [string] -or -not [IO.Path]::IsPathFullyQualified($_)) { throw 'Source directory paths must be absolute strings.' }
            $directory = Get-Item -LiteralPath $_
            if (-not $directory.PSIsContainer) { throw "Source directory is not a directory: $_" }
            $directory.FullName
        } | Select-Object -Unique)
}
$sourceDirArgs = @(foreach ($directory in $sourceDirs) { '--add-dir'; $directory })
if ($Job -and [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $BriefFile -Raw -Encoding utf8))) {
    throw 'Job brief must contain a task request.'
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
if (($OutDir + '\').StartsWith($Repo + '\', [StringComparison]::OrdinalIgnoreCase)) {
    git -C $Repo check-ignore -q -- $OutDir
    if ($LASTEXITCODE -ne 0) { throw "OutDir inside the repository must be git-ignored: $OutDir" }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$briefNote = "Read the request brief at '$BriefFile' first, then read the requirement sources it identifies before reviewing. Use the review target version of repository sources. If a required source is unavailable, explicitly report an incomplete review rather than a pass."
$skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-ReviewerPrompt([string]$SkillName) {
    if ($Job) {
        # Keep the native CLI argument on one line for Windows .cmd wrappers.
        return @(
            "Read the task brief at '$BriefFile' and its requirement sources, then independently carry out its request in the project at '$Repo'. If a required source is unavailable, explicitly report the task as incomplete. Follow applicable project instructions and the brief's scope and verification permissions."
            'This is an analysis-only task. Use read-only inspection; do not modify project files or external resources, stage, commit, or checkout. Report requested actions outside this scope without performing them.'
            'Determine the target from the brief, not from Git diffs. A clean worktree is not a reason to skip the task. Do not invoke creview, sreview, or pjob.'
            'Return the requested result in Korean, with evidence (file:line or sources), assumptions, and unverified limitations. Do not claim checks you did not perform.'
        ) -join ' '
    }
    $skillFile = (Resolve-Path -LiteralPath (Join-Path $skillsRoot "$SkillName/SKILL.md")).Path
    $skillDirectory = Split-Path -Parent $skillFile
    $skillArguments = if ($CommitRange) { "$CommitRange $briefNote" } else { $briefNote }
    "Read and follow the $SkillName skill at '$skillFile'. Resolve its relative references from '$skillDirectory'. Skill arguments: $skillArguments"
}

$reviewers = [Collections.Generic.List[object]]::new()
function Add-Reviewer([string]$Name, [string]$Kind, [string[]]$Arguments) {
    $reviewers.Add([pscustomobject]@{
            Name = $Name; Kind = $Kind; Arguments = $Arguments
            Output = Join-Path $OutDir "$Name.md"; Log = Join-Path $OutDir "$Name.log"
            Process = $null; StdoutTask = $null; StderrTask = $null
            ExitCode = $null; TimedOut = $false; Seconds = 0; Error = $null; CostUsd = $null
        })
}

# Codex's Windows sandbox cannot launch the Microsoft Store pwsh (CreateProcessAsUserW error 5), so another pwsh goes first on codex's PATH.
$codexPath = $null
if ($IsWindows -and $codexCount -gt 0) {
    $candidates = @(Get-Command pwsh -All -CommandType Application -ErrorAction SilentlyContinue |
            Where-Object Source -NotMatch '\\WindowsApps\\' | ForEach-Object Source)
    $candidates += Join-Path $HOME '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
    $codexPwsh = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($codexPwsh) { $codexPath = (Split-Path -Parent $codexPwsh) + ';' + $env:PATH }
    else { Write-Warning 'No pwsh outside WindowsApps found; codex reviewers cannot run shell commands.' }
}

$codexModelArgs = @(if ($CodexModel) { '-m', $CodexModel })
$skills = @(
    @{ Key = 'c'; Name = $(if ($Job) { 'job' } elseif ($CommitRange) { 'ccreview' } else { 'creview' }) },
    @{ Key = 's'; Name = $(if ($CommitRange) { 'ssreview' } else { 'sreview' }) },
    @{ Key = 'a'; Name = $(if ($CommitRange) { 'aareview' } else { 'areview' }) }
)
foreach ($skill in $skills) {
    $pair = $counts[$skill.Key]
    for ($i = 1; $i -le $pair[0]; $i++) {
        $name = "codex-$($skill.Name)-$i"
        Add-Reviewer $name 'codex' (@('exec', '-C', $Repo) + $codexModelArgs + @('-s', $CodexSandbox,
                '--ephemeral', '--color', 'never', '-o', (Join-Path $OutDir "$name.md"), (Get-ReviewerPrompt $skill.Name)))
    }
    for ($i = 1; $i -le $pair[1]; $i++) {
        Add-Reviewer "claude-$($skill.Name)-$i" 'claude' (@('-p', (Get-ReviewerPrompt $skill.Name),
            '--model', $ClaudeModel, '--output-format', 'json', '--no-session-persistence',
            '--add-dir', $skillsRoot, '--add-dir', (Split-Path -Parent $BriefFile)) + $sourceDirArgs +
            @('--disallowedTools', 'Edit', 'Write', 'NotebookEdit'))
    }
}

$before = Get-TreeFingerprint

foreach ($r in $reviewers) {
    Remove-Item -LiteralPath $r.Output -ErrorAction SilentlyContinue
    try {
        $exe = (Get-Command $r.Kind -CommandType Application | Select-Object -First 1).Source
        $psi = [Diagnostics.ProcessStartInfo]::new($exe)
        foreach ($a in $r.Arguments) { $psi.ArgumentList.Add($a) }
        $psi.WorkingDirectory = $Repo
        if ($r.Kind -eq 'codex' -and $IsWindows) {
            if ($codexPath) { $psi.Environment['PATH'] = $codexPath }
            # A standalone CLI has no Windows package identity for the desktop app's registered core.
            [void]$psi.Environment.Remove('CODEX_WINDOWS_REGISTERED_CORE')
        }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
        $r.Process = [Diagnostics.Process]::Start($psi)
        $r.Process.StandardInput.Close()
        $r.StdoutTask = $r.Process.StandardOutput.ReadToEndAsync()
        $r.StderrTask = $r.Process.StandardError.ReadToEndAsync()
    }
    catch {
        $r.Error = "start failed: $_"
    }
}

$deadline = [DateTime]::UtcNow.AddMinutes($TimeoutMinutes)
foreach ($r in ($reviewers | Where-Object Process)) {
    $p = $r.Process
    $remaining = [int][Math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $p.WaitForExit($remaining)) {
        $r.TimedOut = $true
        $p.Kill($true)
    }
    $p.WaitForExit()
    $r.ExitCode = $p.ExitCode
    $r.Seconds = [int]($p.ExitTime - $p.StartTime).TotalSeconds
    $stdout = $r.StdoutTask.GetAwaiter().GetResult()
    $stderr = $r.StderrTask.GetAwaiter().GetResult()
    Set-Content -LiteralPath $r.Log -Value ($stderr + "`n----- stdout -----`n" + $stdout) -Encoding utf8NoBOM

    if ($r.Kind -eq 'claude') {
        try {
            $json = $stdout | ConvertFrom-Json
            $r.CostUsd = $json.total_cost_usd
            if ($json.is_error) { $r.Error = 'claude reported is_error' }
            elseif ($json.result) { Set-Content -LiteralPath $r.Output -Value $json.result -Encoding utf8NoBOM }
        }
        catch {
            $r.Error = 'claude output is not JSON'
        }
    }
}

$after = Get-TreeFingerprint

$summary = [ordered]@{
    spec              = $Spec
    repo              = $Repo
    commitRange       = $CommitRange
    sourceDirs        = $sourceDirs
    worktreeUnchanged = ($before -eq $after)
    reviewers         = @($reviewers | ForEach-Object {
            $hasOutput = (Test-Path -LiteralPath $_.Output) -and (Get-Item -LiteralPath $_.Output).Length -gt 0
            [ordered]@{
                name     = $_.Name
                ok       = (-not $_.Error) -and (-not $_.TimedOut) -and $_.ExitCode -eq 0 -and $hasOutput
                exitCode = $_.ExitCode
                timedOut = $_.TimedOut
                error    = $_.Error
                seconds  = $_.Seconds
                costUsd  = $_.CostUsd
                output   = $_.Output
                log      = $_.Log
            }
        })
}
$json = $summary | ConvertTo-Json -Depth 4
Set-Content -LiteralPath (Join-Path $OutDir 'summary.json') -Value $json -Encoding utf8NoBOM
$json
