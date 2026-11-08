param([Parameter(Mandatory = $true)][string]$Name)

# Only exit 3 means absent. PowerShell itself can return 1 on startup errors.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$json = [Web.Script.Serialization.JavaScriptSerializer]::new()

function Read-Reply($Server, [int]$Id) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $pending = $Server.StandardOutput.ReadLineAsync()
        $remaining = [Math]::Max(0, 15000 - [int]$timer.ElapsedMilliseconds)
        if (-not $pending.Wait($remaining) -or $null -eq $pending.Result) {
            throw 'Codex app server stopped responding.'
        }
        $reply = $json.DeserializeObject($pending.Result)
    } until ($reply['id'] -eq $Id)

    if ($reply['error']) { throw $reply['error']['message'] }
    if ($null -eq $reply['result']) { throw 'Codex app server returned no result.' }
    return $reply['result']
}

$startInfo = [Diagnostics.ProcessStartInfo]::new(
    $env:ComSpec, '/d /c codex app-server --stdio --disable plugins --disable remote_plugin'
)
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8

$server = $null
$status = 2
try {
    # Windows PowerShell uses the console encoding for a process's stdin.
    $previousEncoding = [Console]::InputEncoding
    try {
        [Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
        $server = [Diagnostics.Process]::Start($startInfo)
    } finally {
        [Console]::InputEncoding = $previousEncoding
    }
    $server.StandardInput.WriteLine('{"id":1,"method":"initialize","params":{"clientInfo":{"name":"wt-marketplace-registration","version":"1.0"}}}')
    $null = Read-Reply $server 1
    $server.StandardInput.WriteLine('{"method":"initialized"}')
    $server.StandardInput.WriteLine('{"id":2,"method":"config/read","params":{"includeLayers":false}}')
    $result = Read-Reply $server 2
    $marketplaces = $result['config']['marketplaces']
    if ($marketplaces -isnot [Collections.IDictionary]) { throw 'Codex configuration did not include a marketplace map.' }
    $status = if ($marketplaces.ContainsKey($Name)) { 0 } else { 3 }
} catch {
    [Console]::Error.WriteLine("Could not check Codex marketplace '$Name': $($_.Exception.Message)")
} finally {
    if ($server) {
        $server.StandardInput.Close()
        if (-not $server.WaitForExit(3000)) { $server.Kill() }
        $server.Dispose()
    }
}
exit $status
