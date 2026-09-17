#
# profile.aliases.ps1
#
# .bashrc.aliases の PowerShell 版。profile.ps1 から読み込まれる。
#
# PowerShell はコマンド解決でエイリアスを関数より先に見るため、
# gc / gp / gl のような組み込みエイリアスは先に外してから関数を定義する。
#

# gc=Get-Content, gp=Get-ItemProperty, gl=Get-Location, h=Get-History を上書きする。
# 組み込みエイリアスは AllScope なので、関数の中で消すとその関数のスコープにしか
# 効かない。ここは dot-source されるファイルの直下 (= グローバルスコープ) で消す。
foreach ($_alias in @('g', 'gs', 'ga', 'gc', 'gp', 'gl', 'h', 'll', 'p', 'reload', 'vc')) {
    if (Test-Path -LiteralPath "Alias:$_alias") {
        Remove-Item -LiteralPath "Alias:$_alias" -Force -ErrorAction SilentlyContinue
    }
}
Remove-Variable _alias -ErrorAction SilentlyContinue

# 親ディレクトリへ移動する。
function .. { Set-Location .. }
# 2つ上の親ディレクトリへ移動する。
function ... { Set-Location ..\.. }
# ホームへ移動する。
function ~ { Set-Location $HOME }

function g { & git @args }
function gs { & git status @args }
function ga { & git add . @args }
function gc { & git commit -m @args }
function gp { & git push @args }
function gl { & git log --oneline -20 @args }

# profile.ps1 を読み直す。source ~/.bashrc 相当。
function reload {
    if ($global:DotfilesProfile -and (Test-Path -LiteralPath $global:DotfilesProfile)) {
        . $global:DotfilesProfile
    } else {
        . $PROFILE.CurrentUserAllHosts
    }
}

# history | grep 相当。
function h {
    param([string]$Pattern = '')
    if ($Pattern) { Get-History | Where-Object { $_.CommandLine -match $Pattern } }
    else { Get-History }
}

# ls -la 相当。隠しファイルも出す。
function ll { Get-ChildItem -Force @args }

# pistol は Windows 版が無いので、入っている環境だけで有効にする。
if (Get-Command pistol -ErrorAction SilentlyContinue) {
    function p { & pistol @args }
}

function vc { & claude --dangerously-skip-permissions @args }
