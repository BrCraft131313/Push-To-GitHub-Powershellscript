<#
.SYNOPSIS
    GitHub Auto Sync Script - PowerShell Port
#>

# 1. التحقق من وجود أداة GitHub CLI (gh)
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) is required to check permissions and create repositories." -ForegroundColor Red
    Write-Host "Please install 'gh' and login using 'gh auth login'." -ForegroundColor Yellow
    exit 1
}

# 2. استقبال مسار المجلد ورابط المستودع أو اسم المستودع
$INPUT_VAL = Read-Host "Enter The Path For The Folder & The Repo URL/Name (separated by comma)"

# فصل المسار عن الرابط أو الاسم
$parts = $INPUT_VAL.Split(',')
$FOLDER_PATH = $parts[0].Trim()
$REPO_INPUT = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "" }

# 3. التحقق من وجود المجلد المحلي
if (-not (Test-Path $FOLDER_PATH -PathType Container)) {
    Write-Host "Error: Directory $FOLDER_PATH does not exist!" -ForegroundColor Red
    exit 1
}

# 4. الحصول على اسم المستخدم الحالي المصرح له عبر gh CLI
$AUTHENTICATED_USER = (gh api user --jq '.login' 2>$null)

if (-not $AUTHENTICATED_USER) {
    Write-Host "Error: You are not logged into GitHub CLI. Run 'gh auth login' first." -ForegroundColor Red
    exit 1
}
$AUTHENTICATED_USER = $AUTHENTICATED_USER.Trim()

# 5. معالجة وتحديد اسم المستودع والمالك Target User
$TARGET_OWNER = ""
$REPO_NAME = ""

if ($REPO_INPUT -match '^https://github\.com/([^/]+)/([^/.]+)(\.git)?$') {
    # إذا تم إدخال رابط كامل، يستخرج المالك واسم المستودع منه
    $TARGET_OWNER = $Matches[1]
    $REPO_NAME = $Matches[2]
} else {
    # إذا تم إدخال اسم المستودع فقط، يربطه بالمستخدم المسجل حالياً
    $TARGET_OWNER = $AUTHENTICATED_USER
    $REPO_NAME = $REPO_INPUT
}

# 6. التأكد من الأمان والملكية
if ($TARGET_OWNER -ne $AUTHENTICATED_USER) {
    Write-Host "Security Alert: Permission denied!" -ForegroundColor Red
    Write-Host "You ($AUTHENTICATED_USER) cannot create or force push to a repository owned by ($TARGET_OWNER)." -ForegroundColor Yellow
    exit 1
}

$FULL_REPO_URL = "https://github.com/$TARGET_OWNER/$REPO_NAME.git"

# 7. التحقق من وجود المستودع على GitHub أو إنشائه تلقائياً
gh repo view "$TARGET_OWNER/$REPO_NAME" *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Repository '$TARGET_OWNER/$REPO_NAME' does not exist. Creating it now..." -ForegroundColor Cyan
    gh repo create "$TARGET_OWNER/$REPO_NAME" --public --confirm
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to create repository on GitHub." -ForegroundColor Red
        exit 1
    }
}

# 8. الانتقال إلى مسار المجلد وتنفيذ الرفع
Push-Location $FOLDER_PATH

if (-not (Test-Path ".git")) {
    git init
    git branch -M main
}

git remote remove origin 2>$null
git remote add origin "$FULL_REPO_URL"

git add -A
git commit -m "Auto sync files and folders"
git push -u origin main --force

Pop-Location

Write-Host "Done! All contents from $FOLDER_PATH uploaded successfully to $FULL_REPO_URL." -ForegroundColor Green
