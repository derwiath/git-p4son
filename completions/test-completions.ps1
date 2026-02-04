#!/usr/bin/env pwsh
# Test script for git-p4son PowerShell completions.
#
# Run: pwsh completions/test-completions.ps1
#
# Tests the completion logic by simulating tab-completion calls and
# verifying the returned CompletionResult items.

$ErrorActionPreference = 'Stop'
$script:TestsPassed = 0
$script:TestsFailed = 0

# Source the completion script
. "$PSScriptRoot/git-p4son.ps1"

# Set up test alias fixtures in a temporary git repo
$script:TestRepo = Join-Path ([System.IO.Path]::GetTempPath()) "git-p4son-test-$$"
New-Item -ItemType Directory -Path $script:TestRepo -Force | Out-Null
Push-Location $script:TestRepo
git init --quiet 2>$null
$aliasDir = Join-Path $script:TestRepo ".git-p4son" "changelists"
New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null
Set-Content -Path (Join-Path $aliasDir "myfeature") -Value "12345"
Set-Content -Path (Join-Path $aliasDir "bugfix") -Value "67890"

function Complete {
    param(
        [string]$CommandLine,
        [string]$WordToComplete = ''
    )
    # Simulate what PowerShell passes to a native argument completer.
    # We parse the command line into tokens and call _GitP4sonCompleter
    # with the p4son-relevant args (skipping "git-p4son").
    # Filter out empty strings to match CommandElements behavior (the AST
    # doesn't include trailing empty tokens from trailing whitespace).
    $tokens = @($CommandLine -split '\s+' | Where-Object { $_ -ne '' })
    $p4sonArgs = @($tokens | Select-Object -Skip 1)

    $results = @(_GitP4sonCompleter $WordToComplete $null 0 $p4sonArgs)
    return $results
}

function Get-CompletionTexts {
    param([array]$Results)
    return @($Results | ForEach-Object { $_.CompletionText })
}

function Assert-Contains {
    param(
        [string]$TestName,
        [array]$Results,
        [string]$Expected
    )
    $texts = Get-CompletionTexts $Results
    if ($texts -contains $Expected) {
        $script:TestsPassed++
    } else {
        $script:TestsFailed++
        Write-Host "FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Expected '$Expected' in: [$($texts -join ', ')]"
    }
}

function Assert-NotContains {
    param(
        [string]$TestName,
        [array]$Results,
        [string]$Unexpected
    )
    $texts = Get-CompletionTexts $Results
    if ($texts -contains $Unexpected) {
        $script:TestsFailed++
        Write-Host "FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Did not expect '$Unexpected' in: [$($texts -join ', ')]"
    } else {
        $script:TestsPassed++
    }
}

function Assert-Equals {
    param(
        [string]$TestName,
        [array]$Results,
        [array]$Expected
    )
    $texts = @(Get-CompletionTexts $Results | Sort-Object)
    $sorted = @($Expected | Sort-Object)
    $match = ($texts.Count -eq $sorted.Count)
    if ($match) {
        for ($i = 0; $i -lt $texts.Count; $i++) {
            if ($texts[$i] -ne $sorted[$i]) {
                $match = $false
                break
            }
        }
    }
    if ($match) {
        $script:TestsPassed++
    } else {
        $script:TestsFailed++
        Write-Host "FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Expected: [$($sorted -join ', ')]"
        Write-Host "  Got:      [$($texts -join ', ')]"
    }
}

function Assert-Empty {
    param(
        [string]$TestName,
        [array]$Results
    )
    if ($Results.Count -eq 0) {
        $script:TestsPassed++
    } else {
        $texts = Get-CompletionTexts $Results
        $script:TestsFailed++
        Write-Host "FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Expected empty, got: [$($texts -join ', ')]"
    }
}

# ── Top-level command completion ──────────────────────────────────────

Write-Host "`n=== Top-level command completion ===" -ForegroundColor Cyan

$r = Complete 'git-p4son '
Assert-Contains 'top: has sync' $r 'sync'
Assert-Contains 'top: has new' $r 'new'
Assert-Contains 'top: has update' $r 'update'
Assert-Contains 'top: has list-changes' $r 'list-changes'
Assert-Contains 'top: has alias' $r 'alias'
Assert-Equals 'top: exactly 5 commands' $r @('sync','new','update','list-changes','alias')

$r = Complete 'git-p4son s' 's'
Assert-Contains 'top partial: has sync' $r 'sync'
Assert-NotContains 'top partial: no new' $r 'new'

$r = Complete 'git-p4son li' 'li'
Assert-Contains 'top partial li: has list-changes' $r 'list-changes'

# ── Top-level global flags ────────────────────────────────────────────

Write-Host "`n=== Global flags ===" -ForegroundColor Cyan

$r = Complete 'git-p4son --' '--'
Assert-Contains 'global: has --version' $r '--version'
Assert-NotContains 'global: no --sleep' $r '--sleep'

$r = Complete 'git-p4son -' '-'
Assert-NotContains 'global: no -s' $r '-s'

# ── sync command ──────────────────────────────────────────────────────

Write-Host "`n=== sync command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son sync '
Assert-Contains 'sync pos: has latest' $r 'latest'
Assert-Contains 'sync pos: has last-synced' $r 'last-synced'

$r = Complete 'git-p4son sync la' 'la'
Assert-Contains 'sync partial: has latest' $r 'latest'
Assert-Contains 'sync partial: has last-synced' $r 'last-synced'

$r = Complete 'git-p4son sync -' '-'
Assert-Contains 'sync flags: has -f' $r '-f'
Assert-Contains 'sync flags: has --force' $r '--force'
Assert-NotContains 'sync flags: no -s' $r '-s'
Assert-NotContains 'sync flags: no --sleep' $r '--sleep'

$r = Complete 'git-p4son sync --' '--'
Assert-Contains 'sync --flags: has --force' $r '--force'

# ── new command ───────────────────────────────────────────────────────

Write-Host "`n=== new command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son new -' '-'
Assert-Contains 'new flags: has -m' $r '-m'
Assert-Contains 'new flags: has --message' $r '--message'
Assert-Contains 'new flags: has -b' $r '-b'
Assert-Contains 'new flags: has --base-branch' $r '--base-branch'
Assert-Contains 'new flags: has -f' $r '-f'
Assert-Contains 'new flags: has --force' $r '--force'
Assert-Contains 'new flags: has -n' $r '-n'
Assert-Contains 'new flags: has --dry-run' $r '--dry-run'
Assert-Contains 'new flags: has --no-edit' $r '--no-edit'
Assert-Contains 'new flags: has --shelve' $r '--shelve'
Assert-Contains 'new flags: has --review' $r '--review'
Assert-Contains 'new flags: has -s' $r '-s'
Assert-Contains 'new flags: has --sleep' $r '--sleep'

$r = Complete 'git-p4son new --r' '--r'
Assert-Contains 'new partial --r: has --review' $r '--review'
Assert-NotContains 'new partial --r: no --shelve' $r '--shelve'

# ── update command ────────────────────────────────────────────────────

Write-Host "`n=== update command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son update -' '-'
Assert-Contains 'update flags: has -b' $r '-b'
Assert-Contains 'update flags: has --base-branch' $r '--base-branch'
Assert-Contains 'update flags: has -n' $r '-n'
Assert-Contains 'update flags: has --dry-run' $r '--dry-run'
Assert-Contains 'update flags: has --no-edit' $r '--no-edit'
Assert-Contains 'update flags: has --shelve' $r '--shelve'
Assert-Contains 'update flags: has -s' $r '-s'
Assert-Contains 'update flags: has --sleep' $r '--sleep'
Assert-NotContains 'update flags: no -f' $r '-f'
Assert-NotContains 'update flags: no --force' $r '--force'
Assert-NotContains 'update flags: no --review' $r '--review'

# ── list-changes command ──────────────────────────────────────────────

Write-Host "`n=== list-changes command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son list-changes -' '-'
Assert-Contains 'list-changes flags: has -b' $r '-b'
Assert-Contains 'list-changes flags: has --base-branch' $r '--base-branch'
Assert-NotContains 'list-changes flags: no -f' $r '-f'
Assert-NotContains 'list-changes flags: no --shelve' $r '--shelve'
Assert-NotContains 'list-changes flags: no -s' $r '-s'
Assert-NotContains 'list-changes flags: no --sleep' $r '--sleep'

# ── alias command ─────────────────────────────────────────────────────

Write-Host "`n=== alias command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son alias '
Assert-Contains 'alias sub: has list' $r 'list'
Assert-Contains 'alias sub: has set' $r 'set'
Assert-Contains 'alias sub: has delete' $r 'delete'
Assert-Contains 'alias sub: has clean' $r 'clean'

$r = Complete 'git-p4son alias s' 's'
Assert-Contains 'alias partial s: has set' $r 'set'
Assert-NotContains 'alias partial s: no list' $r 'list'

# ── alias set command ─────────────────────────────────────────────────

Write-Host "`n=== alias set command ===" -ForegroundColor Cyan

$r = Complete 'git-p4son alias set -' '-'
Assert-Contains 'alias set flags: has -f' $r '-f'
Assert-Contains 'alias set flags: has --force' $r '--force'
Assert-NotContains 'alias set flags: no -s' $r '-s'
Assert-NotContains 'alias set flags: no --sleep' $r '--sleep'

# ── alias delete command ──────────────────────────────────────────────

Write-Host "`n=== alias delete command ===" -ForegroundColor Cyan

# No aliases exist in a clean repo, so delete completion returns empty for positionals
$r = Complete 'git-p4son alias delete -' '-'
# Should not crash; may or may not offer flags

# ── alias list / clean (no extra flags expected) ──────────────────────

Write-Host "`n=== alias list/clean commands ===" -ForegroundColor Cyan

# These have no flags at all
$r = Complete 'git-p4son alias list -' '-'
Assert-Empty 'alias list: no flags' $r

$r = Complete 'git-p4son alias clean -' '-'
Assert-Empty 'alias clean: no flags' $r

# ── Edge cases ────────────────────────────────────────────────────────

Write-Host "`n=== Edge cases ===" -ForegroundColor Cyan

# Empty input should show commands
$r = Complete 'git-p4son '
Assert-Equals 'empty shows commands' $r @('sync','new','update','list-changes','alias')

# Double dash prefix
$r = Complete 'git-p4son sync --f' '--f'
Assert-Contains 'sync --f: has --force' $r '--force'

# Unknown command should return empty
$r = Complete 'git-p4son bogus '
Assert-Empty 'unknown cmd returns empty' $r

# Flag after positional in sync
$r = Complete 'git-p4son sync latest -' '-'
Assert-Contains 'sync flag after pos: has -f' $r '-f'

# ── Alias-based completions (using test fixtures) ─────────────────────

Write-Host "`n=== Alias-based completions ===" -ForegroundColor Cyan

# sync positional should include aliases
$r = Complete 'git-p4son sync '
Assert-Contains 'sync pos: has alias myfeature' $r 'myfeature'
Assert-Contains 'sync pos: has alias bugfix' $r 'bugfix'

# sync partial alias
$r = Complete 'git-p4son sync my' 'my'
Assert-Contains 'sync partial alias: has myfeature' $r 'myfeature'
Assert-NotContains 'sync partial alias: no bugfix' $r 'bugfix'

# new positional should include aliases
$r = Complete 'git-p4son new '
Assert-Contains 'new pos: has alias myfeature' $r 'myfeature'
Assert-Contains 'new pos: has alias bugfix' $r 'bugfix'

# update positional should include aliases
$r = Complete 'git-p4son update '
Assert-Contains 'update pos: has alias myfeature' $r 'myfeature'
Assert-Contains 'update pos: has alias bugfix' $r 'bugfix'

# alias set second positional should include aliases
$r = Complete 'git-p4son alias set 12345 '
Assert-Contains 'alias set 2nd pos: has myfeature' $r 'myfeature'
Assert-Contains 'alias set 2nd pos: has bugfix' $r 'bugfix'

# alias set first positional should NOT include aliases (it's a CL number)
$r = Complete 'git-p4son alias set '
Assert-NotContains 'alias set 1st pos: no myfeature' $r 'myfeature'

# alias delete should include aliases
$r = Complete 'git-p4son alias delete '
Assert-Contains 'alias delete: has myfeature' $r 'myfeature'
Assert-Contains 'alias delete: has bugfix' $r 'bugfix'

# ── Summary ───────────────────────────────────────────────────────────

# Clean up test fixtures
Pop-Location
Remove-Item -Path $script:TestRepo -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n=== Results ===" -ForegroundColor Cyan
Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
if ($script:TestsFailed -gt 0) {
    Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
