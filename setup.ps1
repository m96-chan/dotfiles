#Requires -Version 5.1
#
# setup.ps1
#
# setup.sh の Windows (PowerShell) 版。
# シンボリックリンクの作成には管理者権限か開発者モードが必要なため、
# 権限が無い環境ではコピーにフォールバックする。
#
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$DotfilesDir = $PSScriptRoot
$ConfigDir = $env:XDG_CONFIG_HOME
if (-not $ConfigDir) { $ConfigDir = Join-Path $HOME '.config' }
# OneDrive にリダイレクトされていても正しいドキュメントフォルダを取る。
$Documents = [Environment]::GetFolderPath('MyDocuments')

$script:UsedCopy = $false

# 通常ファイル・ディレクトリは一度だけ退避し、既存のバックアップは上書きしない。
function Remove-LinkTarget {
    param([System.IO.FileSystemInfo]$Item)
    # PowerShell 5.1 の Remove-Item はディレクトリのリンク先まで消すことがあるので、
    # 再解析ポイントは .NET の API で本体だけ消す。
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        if ($Item -is [System.IO.DirectoryInfo]) {
            [System.IO.Directory]::Delete($Item.FullName, $false)
        } else {
            [System.IO.File]::Delete($Item.FullName)
        }
        return
    }
    Remove-Item -LiteralPath $Item.FullName -Force -Recurse
}

function New-DotfileLink {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warning "元ファイルがありません: $Source"
        return
    }

    $parent = Split-Path -Parent $Target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $item = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($item) {
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Remove-LinkTarget $item
        } else {
            $backup = "$Target.dotfiles-backup"
            if (Test-Path -LiteralPath $backup) {
                Write-Warning "バックアップが既にあります: $backup"
                return
            }
            Move-Item -LiteralPath $Target -Destination $backup
            Write-Host "  退避: $Target -> $backup"
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -ErrorAction Stop | Out-Null
        Write-Host "  link: $Target"
    } catch {
        # 権限が無い環境ではコピーで代用する。編集後は再実行が必要になる。
        Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
        $script:UsedCopy = $true
        Write-Host "  copy: $Target"
    }
}

Write-Host "dotfiles: $DotfilesDir"

# --- PowerShell プロファイル ---------------------------------------
# profile.ps1 は profile.aliases.ps1 を同じディレクトリから読むので両方置く。
$profileDirs = @(Join-Path $Documents 'WindowsPowerShell')
$ps7Dir = Join-Path $Documents 'PowerShell'
if ((Test-Path -LiteralPath $ps7Dir) -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $profileDirs += $ps7Dir
}
foreach ($dir in $profileDirs) {
    New-DotfileLink (Join-Path $DotfilesDir 'profile.ps1') (Join-Path $dir 'profile.ps1')
    New-DotfileLink (Join-Path $DotfilesDir 'profile.aliases.ps1') (Join-Path $dir 'profile.aliases.ps1')
}

# --- Git -----------------------------------------------------------
New-DotfileLink (Join-Path $DotfilesDir '.gitconfig.aliases') (Join-Path $HOME '.gitconfig.aliases')

# Git エイリアスを自動で読み込む。同じ include は重複登録しない。
if (Get-Command git -ErrorAction SilentlyContinue) {
    $want = (Join-Path $HOME '.gitconfig.aliases').Replace('/', '\')
    $current = @(& git config --global --path --get-all include.path 2>$null)
    $found = $false
    foreach ($path in $current) {
        if ($path -and $path.Replace('/', '\') -ieq $want) { $found = $true }
    }
    if (-not $found) {
        # Git 自身に ~ を展開させる。
        & git config --global --add include.path '~/.gitconfig.aliases'
        Write-Host '  git: include.path に ~/.gitconfig.aliases を追加'
    }
} else {
    Write-Warning 'git が見つからないため include.path の設定をスキップしました。'
}

# --- MOTD / starship -----------------------------------------------
New-DotfileLink (Join-Path $DotfilesDir '.motd_art') (Join-Path $HOME '.motd_art')
New-DotfileLink (Join-Path $DotfilesDir '.config\starship.toml') (Join-Path $ConfigDir 'starship.toml')

# --- goose ---------------------------------------------------------
New-DotfileLink (Join-Path $DotfilesDir '.config\goose\config.yaml') (Join-Path $ConfigDir 'goose\config.yaml')
New-DotfileLink (Join-Path $DotfilesDir '.config\goose\recipes') (Join-Path $ConfigDir 'goose\recipes')

# kitty / wtf / pistol は Windows 版が無いのでリンクしない。

if ($script:UsedCopy) {
    Write-Warning @'
シンボリックリンクを作れなかったためコピーで配置しました。
リポジトリを編集しても反映されないので、次のどちらかを行ってから setup.ps1 を再実行してください。
  - 設定 > システム > 開発者向け > 開発者モード を有効にする
  - PowerShell を管理者として実行する
'@
}

Write-Host '完了しました。新しい PowerShell を開くか reload を実行してください。'
