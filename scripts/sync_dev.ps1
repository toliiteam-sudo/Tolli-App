# ==============================================================================
# TOLII App - Automated Developer Sync Script (PowerShell)
# ==============================================================================
# Usage:
#   .\scripts\sync_dev.ps1 [optional-feature-branch-name]
# Example:
#   .\scripts\sync_dev.ps1 feature/turf-booking
# ==============================================================================

param(
    [string]$FeatureBranch = ""
)

Write-Host "`n🚀 [TOLII] Fetching latest updates from GitHub..." -ForegroundColor Cyan
git fetch origin

# Check working tree status
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️ [TOLII] Local uncommitted changes detected. Auto-stashing to prevent conflicts..." -ForegroundColor Yellow
    git stash push -m "Auto-stashed by sync_dev.ps1 at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Write-Host "🔄 [TOLII] Switching to 'dev' branch and pulling latest code..." -ForegroundColor Cyan
git checkout dev
git pull origin dev

if ($FeatureBranch -ne "") {
    Write-Host "🌿 [TOLII] Creating and checking out new feature branch: $FeatureBranch..." -ForegroundColor Green
    git checkout -b $FeatureBranch
} else {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $defaultBranch = "feature/work-$timestamp"
    Write-Host "🌿 [TOLII] Creating new feature branch: $defaultBranch..." -ForegroundColor Green
    git checkout -b $defaultBranch
}

Write-Host "📦 [TOLII] Running flutter pub get..." -ForegroundColor Cyan
flutter pub get

Write-Host "`n✅ [TOLII] Setup complete! You are ready to start coding on your feature branch." -ForegroundColor Green
Write-Host "⚠️  REMINDER: Never push directly to dev or main. Always push your feature branch!`n" -ForegroundColor Yellow
