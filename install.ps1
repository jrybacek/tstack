<#
.SYNOPSIS
Installs the tstack skills for Claude Code and Codex.

.DESCRIPTION
Copies each folder in this repo's skills/ folder into the skills folder of every
harness that is installed. A harness counts as installed when its command
(claude or codex) is on PATH, or its config folder (~/.claude or ~/.codex)
exists. Harnesses that are not installed are skipped.

Running it again updates the skills in place: the repo's files are copied
over the installed ones. Files the repo has since deleted stay in the installed
copy; delete that skill's folder first for a clean copy. Other skills in those
folders are left alone.

Works in Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS, and Linux.

.PARAMETER Harness
Which harnesses to install for: Claude, Codex, or both. The default is every
one that is installed. Naming a harness that is not installed is an error.

.PARAMETER Skill
Which skills to install, by folder name. The default is all of them.

Both lists also accept one comma-separated string, so they work through
`powershell -File install.ps1 -Skill file-pr,pr-host`.

.EXAMPLE
./install.ps1 -WhatIf
Shows what would be installed and where, without changing anything.

.EXAMPLE
./install.ps1
Installs every skill for every harness that is installed.

.EXAMPLE
./install.ps1 -Harness Claude -Skill babysit-pr, pr-host
Installs two skills for Claude Code only.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ArgumentCompleter({ 'Claude', 'Codex' })]
    [string[]] $Harness,

    [string[]] $Skill
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# `powershell -File` passes "a,b" as one string. Split lists the way PowerShell
# would have, then validate.
function Split-List([string[]] $Value) {
    @($Value | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
if ($Harness) { $Harness = Split-List $Harness }
if ($Skill) { $Skill = Split-List $Skill }
$badHarness = @($Harness | Where-Object { $_ -and @('Claude', 'Codex') -notcontains $_ })
if ($badHarness.Count -gt 0) {
    throw "Unknown harness: $($badHarness -join ', '). Use Claude, Codex, or both."
}

$source = Join-Path $PSScriptRoot 'skills'
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "No skills folder next to this script: $source"
}

$available = @(Get-ChildItem -LiteralPath $source -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') })
if ($Skill) {
    $names = @($available | ForEach-Object { $_.Name })
    $unknown = @($Skill | Where-Object { $names -notcontains $_ })
    if ($unknown.Count -gt 0) {
        throw "Unknown skill: $($unknown -join ', '). Available: $($names -join ', ')"
    }
    $available = @($available | Where-Object { $Skill -contains $_.Name })
}

# $HOME is the user profile in every PowerShell, unlike ~ in some shells.
$harnesses = @(
    [pscustomobject]@{ Name = 'Claude'; Label = 'Claude Code'; Command = 'claude'; Config = Join-Path $HOME '.claude' }
    [pscustomobject]@{ Name = 'Codex';  Label = 'Codex';       Command = 'codex';  Config = Join-Path $HOME '.codex' }
)

$targets = @()
foreach ($h in $harnesses) {
    $command = Get-Command $h.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $reason = $null
    if ($command) {
        $reason = "found $($h.Command) at $($command.Source)"
    } elseif (Test-Path -LiteralPath $h.Config -PathType Container) {
        $reason = "found $($h.Config)"
    }

    $wanted = (-not $Harness) -or ($Harness -contains $h.Name)
    if (-not $wanted) { continue }
    if (-not $reason) {
        if ($Harness) { throw "$($h.Label) is not installed: no $($h.Command) on PATH and no $($h.Config)." }
        Write-Host "Skipping $($h.Label): not installed (no $($h.Command) on PATH, no $($h.Config))."
        continue
    }
    Write-Host "$($h.Label): $reason"
    $targets += [pscustomobject]@{ Label = $h.Label; Skills = Join-Path $h.Config 'skills' }
}

if ($targets.Count -eq 0) {
    Write-Warning 'Neither Claude Code nor Codex is installed, so nothing was installed.'
    return
}

$results = @()
foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Skills -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($t.Skills, 'Create skills folder')) {
            New-Item -ItemType Directory -Path $t.Skills -Force -Confirm:$false | Out-Null
        }
    }
    foreach ($s in $available) {
        $dest = Join-Path $t.Skills $s.Name
        $action = if (Test-Path -LiteralPath $dest) { 'Update' } else { 'Add' }
        $done = $false
        if ($PSCmdlet.ShouldProcess($dest, "$action skill $($s.Name) for $($t.Label)")) {
            # Copy file by file, so an update never nests skills/<name>/<name>.
            # Skip Python bytecode caches at any depth. -Confirm:$false keeps
            # -Confirm to the one prompt per skill above.
            $root = $s.FullName.TrimEnd('\', '/')
            New-Item -ItemType Directory -Path $dest -Force -Confirm:$false | Out-Null
            foreach ($file in Get-ChildItem -LiteralPath $s.FullName -Recurse -File -Force) {
                $relative = $file.FullName.Substring($root.Length + 1)
                if (($relative -split '[\\/]') -contains '__pycache__') { continue }
                $target = Join-Path $dest $relative
                $folder = Split-Path $target -Parent
                if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force -Confirm:$false | Out-Null }
                Copy-Item -LiteralPath $file.FullName -Destination $target -Force -Confirm:$false
            }
            $done = $true
        }
        $results += [pscustomobject]@{
            Harness = $t.Label
            Skill   = $s.Name
            Action  = if ($done) { $action } elseif ($WhatIfPreference) { "Would $($action.ToLower())" } else { 'Skipped' }
            Path    = $dest
        }
    }
}

$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($WhatIfPreference) {
    Write-Host 'Nothing was changed. Run without -WhatIf to install.'
} else {
    Write-Host 'Done. Start a new Claude Code or Codex session if a skill does not show up.'
}
