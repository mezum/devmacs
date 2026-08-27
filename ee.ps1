# Windows entry point.
#
# Hands off to ./ee rather than reimplementing it: two launchers for the same
# job would drift apart, and the POSIX one is what CI exercises. Nothing extra
# needs installing - WSL is already required for wslc, and Git Bash covers the
# case where it is not.

$root = $PSScriptRoot
$ee = Join-Path $root 'ee'

if (-not (Test-Path $ee)) {
    [Console]::Error.WriteLine("ee: cannot find $ee")
    exit 1
}

# WSL first: wslc lives there, and Docker Desktop exposes its socket to it, so
# the runtime is reachable either way.
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $eePath = & wsl.exe wslpath -a "$ee" 2>$null
    if ($LASTEXITCODE -eq 0 -and $eePath) {
        # Invoked through sh because a file on the Windows filesystem does not
        # necessarily carry an executable bit that WSL honours.
        & wsl.exe -- sh "$eePath" @args
        exit $LASTEXITCODE
    }
}

$bash = Get-Command bash.exe -ErrorAction SilentlyContinue
if ($bash) {
    & $bash.Source "$ee" @args
    exit $LASTEXITCODE
}

[Console]::Error.WriteLine('ee: needs WSL or a POSIX shell (Git Bash, MSYS2)')
exit 1
