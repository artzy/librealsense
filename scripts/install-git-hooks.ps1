# Install project git hooks (commit-msg strips Cursor Co-authored-by trailer)
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    throw "Not a git repository: $repoRoot"
}

Set-Location $repoRoot

git config core.hooksPath scripts/git-hooks
Write-Host "core.hooksPath = scripts/git-hooks"
Write-Host "commit-msg hook will remove: Co-authored-by: Cursor <cursoragent@cursor.com>"
