param(
    [switch]$TriggerWorkflow,
    [string]$OutputDir = 'D:\OWN_PROJECTS\SNOOZY\dist'
)

$ErrorActionPreference = 'Stop'
Set-Location 'D:\OWN_PROJECTS\SNOOZY'

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "GitHub CLI (gh) is not installed. Push this repository to GitHub and download 'Snoozy-iOS-Sideloadly-IPA' from the Actions tab, then drag Snoozy-iOS-Sideloadly.ipa into Sideloadly."
    exit 0
}

if ($TriggerWorkflow) {
    Write-Host "Triggering 'Build Snoozy iOS IPA for Sideloadly' workflow on GitHub Actions..."
    & gh workflow run ios-sideloadly-ipa.yml
    Start-Sleep -Seconds 5
}

Write-Host "Waiting for latest 'ios-sideloadly-ipa.yml' run to complete..."
$runId = (& gh run list --workflow=ios-sideloadly-ipa.yml --limit 1 --json databaseId --jq '.[0].databaseId').Trim()
if (-not $runId) {
    throw "No workflow run found for ios-sideloadly-ipa.yml."
}

& gh run watch $runId --exit-status
& gh run download $runId --name Snoozy-iOS-Sideloadly-IPA --dir $OutputDir
$ipaPath = Join-Path $OutputDir 'Snoozy-iOS-Sideloadly.ipa'
Write-Host "Downloaded Sideloadly IPA to: $ipaPath"
