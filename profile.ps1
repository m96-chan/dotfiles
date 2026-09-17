#
# profile.ps1
#
# .bashrc の PowerShell 版。Windows PowerShell 5.1 と PowerShell 7 の
# どちらでも読めるよう、5.1 に無い構文 (三項演算子 / ?? / エスケープ `e) は使わない。
# setup.ps1 が profile.aliases.ps1 と一緒にプロファイルディレクトリへ置く。
#

# reload が自分自身の場所を知るために覚えておく。
$global:DotfilesProfile = $PSCommandPath

# Starship やアートの記号を正しく出すためコンソールを UTF-8 にする。
# 出力がリダイレクトされている場合は設定できないので握り潰す。
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
try {
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
} catch {
}

# ISE は ANSI/VT を解釈しないので、プロンプトとアートは出さない。
$script:DotfilesIsIse = $Host.Name -eq 'Windows PowerShell ISE Host'

function Get-XdgConfigHome {
    if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
    return (Join-Path $HOME '.config')
}

function Get-XdgCacheHome {
    if ($env:XDG_CACHE_HOME) { return $env:XDG_CACHE_HOME }
    return (Join-Path $HOME '.cache')
}

# bash と共有するファイルに BOM を混ぜない。
function Write-DotfilesText {
    param([string]$Path, [string[]]$Lines)
    [System.IO.File]::WriteAllLines($Path, [string[]]$Lines, (New-Object System.Text.UTF8Encoding $false))
}

# --- PATH ----------------------------------------------------------
# PATH を reload のたびに重複させない。存在しないディレクトリは足さない。
function Add-PathEntry {
    param([string]$Path, [switch]$Append)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
    $full = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\')
    foreach ($part in ($env:PATH -split ';')) {
        if ($part -and $part.TrimEnd('\') -ieq $full) { return }
    }
    if ($Append) { $env:PATH = "$env:PATH;$full" } else { $env:PATH = "$full;$env:PATH" }
}

$script:CargoHome = $env:CARGO_HOME
if (-not $script:CargoHome) { $script:CargoHome = Join-Path $HOME '.cargo' }
Add-PathEntry (Join-Path $script:CargoHome 'bin')
Add-PathEntry (Join-Path $HOME '.local\bin')
Add-PathEntry (Join-Path $HOME '.deno\bin')
Add-PathEntry (Join-Path $HOME '.grok\bin')
Add-PathEntry (Join-Path $HOME '.opencode\bin')

# go install の出力先。GOBIN と、複数指定された GOPATH の先頭にも対応する。
if (Get-Command go -ErrorAction SilentlyContinue) {
    $script:GoEnv = @(& go env GOBIN GOPATH 2>$null)
    $script:GoBin = ''
    if ($script:GoEnv.Count -ge 1 -and $script:GoEnv[0]) { $script:GoBin = $script:GoEnv[0] }
    if (-not $script:GoBin -and $script:GoEnv.Count -ge 2 -and $script:GoEnv[1]) {
        $script:GoBin = Join-Path ($script:GoEnv[1] -split ';')[0] 'bin'
    }
    if (-not $script:GoBin) { $script:GoBin = Join-Path $HOME 'go\bin' }
    Add-PathEntry $script:GoBin
}

# --- 履歴 ----------------------------------------------------------
# HISTCONTROL=ignoreboth 相当: 重複を残さず、空白始まりの行は記録しない。
try {
    Set-PSReadLineOption -MaximumHistoryCount 10000 -HistoryNoDuplicates:$true -ErrorAction Stop
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally -ErrorAction SilentlyContinue
    Set-PSReadLineOption -AddToHistoryHandler {
        param($line)
        return -not $line.StartsWith(' ')
    } -ErrorAction SilentlyContinue
} catch {
}

# --- エイリアス ----------------------------------------------------
$script:AliasFile = $null
if ($PSScriptRoot) { $script:AliasFile = Join-Path $PSScriptRoot 'profile.aliases.ps1' }
if ($script:AliasFile -and (Test-Path -LiteralPath $script:AliasFile)) { . $script:AliasFile }

# --- TODO ----------------------------------------------------------
# MOTD の TODO 欄が読む ~/.todo を操作する。
# 引数なしで一覧、引数ありで1行追加、-d で先頭行 (MOTD に出る行) を削除。
function todo {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Text)

    $file = Join-Path $HOME '.todo'
    if (-not $Text -or $Text.Count -eq 0) {
        if ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 0) {
            Get-Content -LiteralPath $file -Encoding UTF8
        } else {
            'Nothing!'
        }
        return
    }
    if ($Text.Count -eq 1 -and $Text[0] -eq '-d') {
        if (Test-Path -LiteralPath $file) {
            $lines = @(Get-Content -LiteralPath $file -Encoding UTF8)
            if ($lines.Count -gt 0) { Write-DotfilesText $file ($lines | Select-Object -Skip 1) }
        }
        return
    }
    $lines = @()
    if (Test-Path -LiteralPath $file) { $lines = @(Get-Content -LiteralPath $file -Encoding UTF8) }
    Write-DotfilesText $file ($lines + ($Text -join ' '))
}

# --- MOTD: 情報取得 ------------------------------------------------
# 起動以来の平均ではなく、短い区間の差分を使う。
# Win32_Processor は 1 秒以上かかり、Win32_PerfRawData_PerfOS_Processor は
# WMI 側のキャッシュのせいで 100ms 程度の差分がまったく当てにならない。
# 全プロセスの CPU 時間の合計は安定していて速いので、それを使う。
function Get-ProcessCpuTicks {
    $ticks = [double]0
    $procs = [System.Diagnostics.Process]::GetProcesses()
    foreach ($p in $procs) {
        # Idle / System などはアクセスできないので、読めたものだけ足す。
        try { $ticks += $p.TotalProcessorTime.Ticks } catch { }
        $p.Dispose()
    }
    return $ticks
}

function Get-MotdCpu {
    try {
        $before = Get-ProcessCpuTicks
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds 100
        $after = Get-ProcessCpuTicks
        $sw.Stop()
        $elapsed = [double]$sw.Elapsed.Ticks * [System.Environment]::ProcessorCount
        if ($elapsed -le 0) { return 'N/A' }
        $busy = 100 * ($after - $before) / $elapsed
        if ($busy -lt 0) { $busy = 0 }
        if ($busy -gt 100) { $busy = 100 }
        return ('{0:0.0}%' -f $busy)
    } catch {
        return 'N/A'
    }
}

function Format-MotdBytes {
    param([double]$Bytes)
    $units = @('B', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi')
    $i = 0
    while ($Bytes -ge 1024 -and $i -lt ($units.Count - 1)) {
        $Bytes = $Bytes / 1024
        $i++
    }
    if ($i -eq 0 -or $Bytes -ge 100) { return ('{0:0}{1}' -f $Bytes, $units[$i]) }
    return ('{0:0.0}{1}' -f $Bytes, $units[$i])
}

function Format-MotdPlural {
    param([int]$Count, [string]$Unit)
    if ($Count -eq 1) { return "$Count $Unit" }
    return "$Count ${Unit}s"
}

function Get-MotdUptime {
    param($Os)
    if (-not $Os) { return '' }
    $span = (Get-Date) - $Os.LastBootUpTime
    $parts = @()
    if ($span.Days -gt 0) { $parts += (Format-MotdPlural $span.Days 'day') }
    if ($span.Hours -gt 0) { $parts += (Format-MotdPlural $span.Hours 'hour') }
    if ($span.Minutes -gt 0 -or $parts.Count -eq 0) { $parts += (Format-MotdPlural $span.Minutes 'minute') }
    return 'up ' + ($parts -join ', ')
}

function Get-MotdMemory {
    param($Os)
    if (-not $Os) { return '' }
    $total = [double]$Os.TotalVisibleMemorySize * 1024
    $free = [double]$Os.FreePhysicalMemory * 1024
    return ('{0}/{1}' -f (Format-MotdBytes ($total - $free)), (Format-MotdBytes $total))
}

function Get-MotdDisk {
    $drive = $env:SystemDrive
    if (-not $drive) { $drive = 'C:' }
    try {
        $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction Stop
        if (-not $d -or -not $d.Size) { return 'N/A' }
        $used = [double]$d.Size - [double]$d.FreeSpace
        $pct = [math]::Round(100 * $used / [double]$d.Size)
        return ('{0}/{1} ({2}%)' -f (Format-MotdBytes $used), (Format-MotdBytes ([double]$d.Size)), $pct)
    } catch {
        return 'N/A'
    }
}

# 既定ゲートウェイを持つインターフェイスの IPv4 を使う。
function Get-MotdIp {
    try {
        foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($nic.OperationalStatus -ne 'Up') { continue }
            if ($nic.NetworkInterfaceType -eq 'Loopback') { continue }
            $props = $nic.GetIPProperties()
            $hasGateway = $false
            foreach ($gw in $props.GatewayAddresses) {
                if ($gw.Address -and $gw.Address.AddressFamily -eq 'InterNetwork' -and
                    $gw.Address.ToString() -ne '0.0.0.0') {
                    $hasGateway = $true
                }
            }
            if (-not $hasGateway) { continue }
            foreach ($ua in $props.UnicastAddresses) {
                if ($ua.Address.AddressFamily -ne 'InterNetwork') { continue }
                $prefix = ''
                try {
                    if ($ua.PrefixLength -gt 0) { $prefix = '/' + $ua.PrefixLength }
                } catch {
                }
                return $ua.Address.ToString() + $prefix
            }
        }
    } catch {
    }
    return 'N/A'
}

# Win32_VideoController は数十 ms かかるので、bash 版と同じくキャッシュする。
function Get-MotdGpu {
    param([switch]$Cached)
    $cacheFile = Join-Path (Join-Path (Get-XdgCacheHome) 'dotfiles') 'motd-gpu-windows'
    $gpu = ''
    if ($Cached) {
        if (Test-Path -LiteralPath $cacheFile) {
            $gpu = @(Get-Content -LiteralPath $cacheFile -Encoding UTF8 -TotalCount 1)[0]
        }
    } else {
        try {
            $names = @(Get-CimInstance Win32_VideoController -ErrorAction Stop |
                Where-Object { $_.Name } | ForEach-Object { $_.Name })
            $gpu = ($names -join ' / ')
        } catch {
            $gpu = ''
        }
        if ($gpu) {
            # 保存できない環境でも表示は続ける。
            try {
                $dir = Split-Path -Parent $cacheFile
                if (-not (Test-Path -LiteralPath $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
                Write-DotfilesText $cacheFile @($gpu)
            } catch {
            }
        }
    }
    if (-not $gpu) { return '-' }
    return $gpu
}

function Get-MotdBattery {
    try {
        $b = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
    } catch {
        return ''
    }
    if ($b.Count -eq 0 -or -not $b[0]) { return '' }
    $status = @{
        1 = 'Discharging'; 2 = 'AC'; 3 = 'Fully Charged'; 4 = 'Low'; 5 = 'Critical';
        6 = 'Charging'; 7 = 'Charging (High)'; 8 = 'Charging (Low)';
        9 = 'Charging (Critical)'; 10 = 'Unknown'; 11 = 'Partially Charged'
    }[[int]$b[0].BatteryStatus]
    if (-not $status) { $status = 'Unknown' }
    return ('{0}% ({1})' -f [int]$b[0].EstimatedChargeRemaining, $status)
}

# --- MOTD 表示 -----------------------------------------------------

# 表示幅 (全角を 2 桁として数える)
function Get-MotdWidth {
    param([string]$Text)
    if (-not $Text) { return 0 }
    $w = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $cp = [int]$Text[$i]
        if ([char]::IsHighSurrogate($Text[$i]) -and ($i + 1) -lt $Text.Length -and
            [char]::IsLowSurrogate($Text[$i + 1])) {
            $cp = [char]::ConvertToUtf32($Text[$i], $Text[$i + 1])
            $i++
        }
        if ($cp -ge 0x1100 -and (
            ($cp -le 0x115f) -or
            ($cp -ge 0x2e80 -and $cp -le 0x303e) -or
            ($cp -ge 0x3041 -and $cp -le 0x33ff) -or
            ($cp -ge 0x3400 -and $cp -le 0x4dbf) -or
            ($cp -ge 0x4e00 -and $cp -le 0x9fff) -or
            ($cp -ge 0xa000 -and $cp -le 0xa4cf) -or
            ($cp -ge 0xac00 -and $cp -le 0xd7a3) -or
            ($cp -ge 0xf900 -and $cp -le 0xfaff) -or
            ($cp -ge 0xfe30 -and $cp -le 0xfe6f) -or
            ($cp -ge 0xff00 -and $cp -le 0xff60) -or
            ($cp -ge 0xffe0 -and $cp -le 0xffe6) -or
            ($cp -ge 0x1f300 -and $cp -le 0x1faff) -or
            ($cp -ge 0x20000 -and $cp -le 0x3fffd))) {
            $w += 2
        } else {
            $w += 1
        }
    }
    return $w
}

# サロゲートペアを壊さずに1文字ずつ返す
function Split-MotdChar {
    param([string]$Text)
    $chars = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ([char]::IsHighSurrogate($Text[$i]) -and ($i + 1) -lt $Text.Length -and
            [char]::IsLowSurrogate($Text[$i + 1])) {
            $chars.Add($Text.Substring($i, 2))
            $i++
        } else {
            $chars.Add($Text.Substring($i, 1))
        }
    }
    return , $chars.ToArray()
}

# $Text を表示幅 $Width で折り返し、行末を空白で埋めて返す。
# タブ・改行・連続空白は潰すので fortune の整形済みテキストでも崩れない。
function Split-MotdValue {
    param([string]$Text, [int]$Width)

    $lines = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Text) { $Text = '' }
    $Text = [regex]::Replace($Text, '\p{Cc}', ' ')
    $words = @($Text -split '\s+' | Where-Object { $_ -ne '' })

    $line = ''
    $lw = 0
    foreach ($word in $words) {
        $ww = Get-MotdWidth $word
        if ($ww -gt $Width) {
            # 1 単語で幅を超えるものは文字単位で分割する
            if ($lw -gt 0) {
                $lines.Add($line)
                $line = ''
                $lw = 0
            }
            foreach ($c in (Split-MotdChar $word)) {
                $cw = Get-MotdWidth $c
                if (($lw + $cw) -gt $Width) {
                    $lines.Add($line)
                    $line = ''
                    $lw = 0
                }
                $line += $c
                $lw += $cw
            }
        } elseif ($lw -eq 0) {
            $line = $word
            $lw = $ww
        } elseif (($lw + 1 + $ww) -le $Width) {
            $line += " $word"
            $lw += 1 + $ww
        } else {
            $lines.Add($line)
            $line = $word
            $lw = $ww
        }
    }
    if ($lw -gt 0 -or $lines.Count -eq 0) { $lines.Add($line) }

    for ($n = 0; $n -lt $lines.Count; $n++) {
        $pad = $Width - (Get-MotdWidth $lines[$n])
        if ($pad -gt 0) { $lines[$n] = $lines[$n] + (' ' * $pad) }
    }
    return , $lines.ToArray()
}

function Show-Motd {
    [CmdletBinding()]
    param([switch]$Brief)

    $esc = [char]27

    # 左のアートに40列、右の情報欄に40列を使う。
    $textCol = 41
    $boxWidth = 40
    $labelWidth = 8
    $valueWidth = $boxWidth - $labelWidth - 5

    # 配色は .motd_art のキャラの差し色から (緑=#70c5c4 / 赤=#ea438d)
    $border = "$esc[38;2;112;197;196m"
    $labelCol = "$esc[38;2;234;67;141m"
    $reset = "$esc[0m"

    $cols = 80
    try {
        $w = $Host.UI.RawUI.WindowSize.Width
        if ($w -gt 0) { $cols = [int]$w }
    } catch {
    }
    if ($cols -lt 2) { return }

    $redirected = $true
    try { $redirected = [Console]::IsOutputRedirected } catch { }

    $art = @()
    $artPath = Join-Path $HOME '.motd_art'
    if (-not $script:DotfilesIsIse -and -not $redirected -and $Host.UI.SupportsVirtualTerminal -and
        $cols -ge 80 -and (Test-Path -LiteralPath $artPath)) {
        $art = @(Get-Content -LiteralPath $artPath -Encoding UTF8)
    }
    $artLines = $art.Count
    $compact = $artLines -lt 3

    $quote = ''
    if (Get-Command fortune -ErrorAction SilentlyContinue) {
        $quote = (& fortune -s -n 120 2>$null) -join ' '
    }
    if (-not $quote) { $quote = 'Stay curious.' }

    $os = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { }
    $kernel = [System.Environment]::OSVersion.Version.ToString()
    if ($os -and $os.Version) { $kernel = $os.Version }

    $todoLine = 'Nothing!'
    $todoFile = Join-Path $HOME '.todo'
    if (Test-Path -LiteralPath $todoFile) {
        $first = @(Get-Content -LiteralPath $todoFile -Encoding UTF8 -TotalCount 1)
        if ($first.Count -gt 0 -and $first[0]) { $todoLine = $first[0] }
    }

    $items = New-Object System.Collections.Generic.List[object]
    $items.Add(@{ Label = 'USER:'; Value = $env:USERNAME })
    $items.Add(@{ Label = 'HOST:'; Value = $env:COMPUTERNAME })
    $items.Add(@{ Label = 'KERNEL:'; Value = $kernel })
    $items.Add(@{ Label = 'UPTIME:'; Value = (Get-MotdUptime $os) })
    $items.Add(@{ Label = 'MEMORY:'; Value = (Get-MotdMemory $os) })
    $items.Add(@{ Label = 'CPU:'; Value = (Get-MotdCpu) })
    $items.Add(@{ Label = 'DISK:'; Value = (Get-MotdDisk) })
    $items.Add(@{ Label = 'IP:'; Value = (Get-MotdIp) })
    if ($Brief) {
        $items.Add(@{ Label = 'GPU:'; Value = (Get-MotdGpu -Cached) })
    } else {
        $items.Add(@{ Label = 'GPU:'; Value = (Get-MotdGpu) })
    }
    $battery = Get-MotdBattery
    if ($battery) { $items.Add(@{ Label = 'BATTERY:'; Value = $battery }) }
    $items.Add(@{ Label = 'DATE:'; Value = (Get-Date).ToString('yyyy-MM-dd HH:mm') })
    $items.Add(@{ Label = 'TODO:'; Value = $todoLine })
    $items.Add(@{ Label = 'QUOTE:'; Value = $quote })

    # 横幅が足りないペイン、アートなし、リダイレクト時はテキスト表示。
    if ($compact) {
        foreach ($item in $items) {
            $value = $item.Value
            if (-not $value) { $value = '-' }
            foreach ($line in (Split-MotdValue ($item.Label + ' ' + $value) $cols)) {
                Write-Host $line
            }
        }
        return
    }

    # 吹き出しの中身を valueWidth で折り返して組み立てる
    $bodyLabel = New-Object System.Collections.Generic.List[string]
    $bodyValue = New-Object System.Collections.Generic.List[string]
    $maxBody = $artLines - 2
    :items foreach ($item in $items) {
        $value = $item.Value
        if (-not $value) { $value = '-' }
        $first = $true
        foreach ($line in (Split-MotdValue $value $valueWidth)) {
            if ($bodyValue.Count -ge $maxBody) { break items }
            if ($first) {
                $bodyLabel.Add($item.Label)
                $first = $false
            } else {
                $bodyLabel.Add('')
            }
            $bodyValue.Add($line)
        }
    }

    $bodyLines = $bodyValue.Count
    $boxHeight = $bodyLines + 2
    # 吹き出しを中央配置から5行上にずらす。
    $startRow = [int][math]::Floor(($artLines - $boxHeight) / 2) - 5
    if ($startRow -lt 0) { $startRow = 0 }

    # しっぽはキャラの顔の高さ (アート 10 行目付近) に合わせる
    $tailRow = 10 - $startRow - 1
    if ($tailRow -lt 0) { $tailRow = 0 }
    if ($tailRow -ge $bodyLines) { $tailRow = $bodyLines - 1 }

    $hline = '─' * ($boxWidth - 2)

    # アートと情報欄を1行ずつ出力する。画面を上に戻さないので、
    # 行数の少ない端末でも上端に重ね描きせずスクロールできる。
    $out = New-Object System.Text.StringBuilder
    for ($row = 0; $row -lt $artLines; $row++) {
        [void]$out.Append($art[$row]).Append($reset)
        $i = $row - $startRow - 1
        if ($row -eq $startRow) {
            [void]$out.Append("$esc[${textCol}G$border" + '╭' + $hline + '╮' + $reset)
        } elseif ($i -ge 0 -and $i -lt $bodyLines) {
            if ($i -eq $tailRow) {
                [void]$out.Append("$esc[$($textCol - 1)G$border" + '◥│' + $reset)
            } else {
                [void]$out.Append("$esc[${textCol}G$border" + '│' + $reset)
            }
            [void]$out.Append((' {0}{1}{2} {3} {4}{5}{6}' -f $labelCol, $bodyLabel[$i].PadRight($labelWidth),
                $reset, $bodyValue[$i], $border, '│', $reset))
        } elseif ($i -eq $bodyLines) {
            [void]$out.Append("$esc[${textCol}G$border" + '╰' + $hline + '╯' + $reset)
        }
        [void]$out.Append("`n")
    }
    [Console]::Out.Write($out.ToString())
}
Set-Alias motd Show-Motd

# パイプやリダイレクトには起動メッセージを混ぜない。
if (-not $script:DotfilesIsIse) {
    $script:MotdRedirected = $true
    try { $script:MotdRedirected = [Console]::IsOutputRedirected } catch { }
    if (-not $script:MotdRedirected) { Show-Motd -Brief }
}

# --- starship ------------------------------------------------------
if (-not $script:DotfilesIsIse -and (Get-Command starship -ErrorAction SilentlyContinue)) {
    if (-not $env:STARSHIP_CONFIG) {
        $env:STARSHIP_CONFIG = Join-Path (Get-XdgConfigHome) 'starship.toml'
    }
    Invoke-Expression (& starship init powershell)
}

# --- fzf -----------------------------------------------------------
# PSFzf があれば Ctrl+T でパス挿入、Alt+C で移動、Ctrl+R で履歴検索。
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    if (-not $env:FZF_DEFAULT_OPTS) {
        $env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border'
    }
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
        try {
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -PSReadlineChordSetLocation 'Alt+c'
        } catch {
        }
    }
}

# ghq + fzf でリポジトリにジャンプ
function ghq-fzf {
    param([string]$Query = '')
    if (-not (Get-Command ghq -ErrorAction SilentlyContinue) -or
        -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Error 'ghq と fzf をインストールしてください。'
        return
    }
    $dir = & ghq list -p | & fzf --query $Query
    if ($dir) { Set-Location -LiteralPath $dir }
}

# Ctrl+] で ghq-fzf を実行する (bash 版と同じ割り当て)。
try {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+]' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('ghq-fzf')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    } -ErrorAction Stop
} catch {
}

# --- Java / Android ------------------------------------------------
# 明示した設定を優先し、インストール済みのものだけ自動検出する。
function Initialize-DotfilesDevEnv {
    if (-not $env:JAVA_HOME) {
        $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs')) |
            Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        foreach ($root in $roots) {
            foreach ($vendor in @('Eclipse Adoptium', 'Microsoft', 'Java', 'Amazon Corretto', 'Zulu')) {
                $dir = Join-Path $root $vendor
                if (-not (Test-Path -LiteralPath $dir)) { continue }
                $jdk = @(Get-ChildItem -LiteralPath $dir -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending)
                if ($jdk.Count -eq 0) {
                    $jdk = @(Get-ChildItem -LiteralPath $dir -Directory -Filter 'jdk*' -ErrorAction SilentlyContinue |
                        Sort-Object Name -Descending)
                }
                foreach ($candidate in $jdk) {
                    if (Test-Path -LiteralPath (Join-Path $candidate.FullName 'bin\java.exe')) {
                        $env:JAVA_HOME = $candidate.FullName
                        break
                    }
                }
                if ($env:JAVA_HOME) { break }
            }
            if ($env:JAVA_HOME) { break }
        }
        # Android Studio 同梱の JBR を最後の手段にする。
        if (-not $env:JAVA_HOME) {
            foreach ($root in $roots) {
                $jbr = Join-Path $root 'Android\Android Studio\jbr'
                if (Test-Path -LiteralPath (Join-Path $jbr 'bin\java.exe')) {
                    $env:JAVA_HOME = $jbr
                    break
                }
            }
        }
    }

    if (-not $env:ANDROID_HOME) {
        $sdks = @($env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'), (Join-Path $HOME 'Android\Sdk'))
        foreach ($sdk in $sdks) {
            if ($sdk -and (Test-Path -LiteralPath $sdk)) {
                $env:ANDROID_HOME = $sdk
                break
            }
        }
    }
    if ($env:ANDROID_HOME) {
        Add-PathEntry (Join-Path $env:ANDROID_HOME 'platform-tools')
        if (-not $env:ANDROID_NDK_HOME) {
            $ndkRoot = Join-Path $env:ANDROID_HOME 'ndk'
            $ndk = @()
            if (Test-Path -LiteralPath $ndkRoot) {
                $ndk = @(Get-ChildItem -LiteralPath $ndkRoot -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^\d+(\.\d+)*' } |
                    Sort-Object { [version]($_.Name -replace '^(\d+(\.\d+)*).*$', '$1') })
            }
            if ($ndk.Count -gt 0) {
                $env:ANDROID_NDK_HOME = $ndk[-1].FullName
            } elseif (Test-Path -LiteralPath (Join-Path $env:ANDROID_HOME 'ndk-bundle')) {
                $env:ANDROID_NDK_HOME = Join-Path $env:ANDROID_HOME 'ndk-bundle'
            }
        }
    }
}
Initialize-DotfilesDevEnv

# --- goose マルチモデル worker -------------------------------------
# ACP プロバイダ (claude-acp / codex-acp) 配下では goose 側の
# GOOSE_SUBAGENT_* が効かず、内蔵の委譲ではサブエージェントのモデルを
# リードと別にできない。そのため worker の分担は goose に任せず、
# レシピを CLI から直接叩いてモデルを明示的に切り替える。
$global:GooseRecipes = Join-Path (Get-XdgConfigHome) 'goose\recipes\plan-implement-review'

# 計画やレビュー指摘は複数行になるので、素の文字列に加えて
# '-' で stdin、'@path' でファイルからも渡せるようにする。
function Get-GooseArg {
    param([string]$Value)
    if ($Value -eq '-') { return [Console]::In.ReadToEnd() }
    if ($Value -and $Value.StartsWith('@')) {
        return (Get-Content -LiteralPath $Value.Substring(1) -Raw -Encoding UTF8)
    }
    return $Value
}

function Invoke-GooseRecipe {
    param([string]$Recipe, [string[]]$Arguments)
    $maxTurns = $env:GOOSE_WORKER_MAX_TURNS
    if (-not $maxTurns) { $maxTurns = '50' }
    & goose run --no-session --max-turns $maxTurns --recipe (Join-Path $global:GooseRecipes $Recipe) @Arguments
}

# 計画立案 (Fable): goose-plan <task|-|@file>
function goose-plan {
    param([Parameter(Mandatory = $true)][string]$Task)
    Invoke-GooseRecipe 'planner_fable.yaml' @('--params', ('task=' + (Get-GooseArg $Task)))
}

# 実装 (Sol / Opus): goose-impl <sol|opus> <plan|-|@file> [feedback|@file]
function goose-impl {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('sol', 'opus')][string]$Model,
        [Parameter(Mandatory = $true)][string]$Plan,
        [string]$Feedback = 'なし'
    )
    $recipe = 'implementer_sol.yaml'
    if ($Model -eq 'opus') { $recipe = 'implementer_opus.yaml' }
    Invoke-GooseRecipe $recipe @(
        '--params', ('plan=' + (Get-GooseArg $Plan)),
        '--params', ('feedback=' + (Get-GooseArg $Feedback))
    )
}

# レビュー (Astra): goose-review <plan|-|@file> <report|-|@file>
function goose-review {
    param(
        [Parameter(Mandatory = $true)][string]$Plan,
        [Parameter(Mandatory = $true)][string]$Report
    )
    Invoke-GooseRecipe 'reviewer.yaml' @(
        '--params', ('plan=' + (Get-GooseArg $Plan)),
        '--params', ('implementation_report=' + (Get-GooseArg $Report))
    )
}
