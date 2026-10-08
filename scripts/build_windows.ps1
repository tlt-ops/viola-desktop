# Run on Windows with .NET SDK 10.0.x. No installed app or user profile is changed.
[CmdletBinding()]
param(
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
# Native exit codes are checked explicitly, including on PowerShell 7.
$PSNativeCommandUseErrorActionPreference = $false

if ($env:OS -ne "Windows_NT") {
    throw "Windows is required to build and run the WPF release checks."
}
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $RepositoryRoot "windows/Viola.Windows.csproj"
if (-not (Test-Path -LiteralPath $Project -PathType Leaf)) {
    throw "Project not found: $Project"
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "Install .NET SDK 10.0.x, then run this script again."
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot "build/windows"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$BuildId = [Guid]::NewGuid().ToString("N")
$StageRoot = Join-Path $OutputDirectory "staging-$BuildId"
$PublishDirectory = Join-Path $StageRoot "win-x64"
$LogDirectory = Join-Path $StageRoot "logs"
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

Push-Location $RepositoryRoot
try {
    & dotnet --version
    if ($LASTEXITCODE -ne 0) { throw "dotnet --version failed: $LASTEXITCODE" }
    & dotnet publish $Project --configuration Release --framework net10.0-windows `
        --runtime win-x64 --self-contained true --output $PublishDirectory `
        -p:UseAppHost=true -p:PublishSingleFile=false
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed: $LASTEXITCODE" }

    # Ask MSBuild for the actual executable name rather than assuming a filename.
    $AssemblyName = (& dotnet msbuild $Project -nologo -getProperty:AssemblyName | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($AssemblyName)) {
        throw "Could not read the project's AssemblyName."
    }
    $Executable = Join-Path $PublishDirectory "$AssemblyName.exe"
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "Published executable is missing: $Executable"
    }

    function Invoke-ReleaseCheck {
        param([string]$Name, [string[]]$Arguments)
        $Process = Start-Process -FilePath $Executable -ArgumentList $Arguments `
            -WorkingDirectory $PublishDirectory -PassThru `
            -RedirectStandardOutput (Join-Path $LogDirectory "$Name.stdout.log") `
            -RedirectStandardError (Join-Path $LogDirectory "$Name.stderr.log")
        # Retain a handle before waiting so ExitCode remains available for WinExe.
        $null = $Process.Handle
        if (-not $Process.WaitForExit(60000)) {
            $Process.Kill()
            throw "$Name timed out after 60 seconds. Logs: $LogDirectory"
        }
        # Refresh the process object before inspecting the WinExe exit code.
        $Process.Refresh()
        if ($Process.ExitCode -ne 0) {
            Get-Content -LiteralPath (Join-Path $LogDirectory "$Name.stderr.log")
            throw "$Name failed with exit code $($Process.ExitCode). Logs: $LogDirectory"
        }
        Write-Host "PASS: $Name (exit code 0)"
    }

    Invoke-ReleaseCheck -Name "self-test" -Arguments @("--self-test")
    $SmokeImage = Join-Path $StageRoot "smoke.png"
    # Start-Process joins its ArgumentList; quote the absolute path for spaces.
    Invoke-ReleaseCheck -Name "smoke-test" -Arguments @("--smoke-test", ('"' + $SmokeImage + '"'))
    if (-not (Test-Path -LiteralPath $SmokeImage -PathType Leaf)) {
        throw "Smoke test did not create its PNG: $SmokeImage"
    }
    $ImageBytes = [System.IO.File]::ReadAllBytes($SmokeImage)
    $PngSignature = @(137, 80, 78, 71, 13, 10, 26, 10)
    if ($ImageBytes.Length -le 8) { throw "Smoke PNG is empty or truncated." }
    for ($Index = 0; $Index -lt $PngSignature.Length; $Index++) {
        if ($ImageBytes[$Index] -ne $PngSignature[$Index]) {
            throw "Smoke test output does not have a PNG signature."
        }
    }
    Write-Host "PASS: smoke PNG exists and has a valid PNG signature"

    $ZipName = "viola-windows-win-x64.zip"
    $StageZip = Join-Path $StageRoot $ZipName
    Compress-Archive -Path (Join-Path $PublishDirectory "*") -DestinationPath $StageZip

    # Preserve previous generated outputs rather than deleting existing files.
    foreach ($Name in @("win-x64", $ZipName, "smoke.png", "logs")) {
        $Destination = Join-Path $OutputDirectory $Name
        if (Test-Path -LiteralPath $Destination) {
            $Previous = Join-Path $OutputDirectory "previous-$BuildId-$Name"
            Move-Item -LiteralPath $Destination -Destination $Previous
            Write-Host "Previous output retained: $Previous"
        }
        Move-Item -LiteralPath (Join-Path $StageRoot $Name) -Destination $Destination
    }
    Write-Host "Published app: $(Join-Path $OutputDirectory ('win-x64/' + $AssemblyName + '.exe'))"
    Write-Host "Release archive: $(Join-Path $OutputDirectory $ZipName)"
    Write-Host "Smoke image: $(Join-Path $OutputDirectory 'smoke.png')"
} finally {
    Pop-Location
}
