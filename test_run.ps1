# Интерактивный запуск Zapret & INCY VPN Sync в консоли
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Запрос прав администратора для управления службой zapret..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$exePath = Join-Path $scriptDir "ZapretVpnSync.exe"

if (-not (Test-Path $exePath)) {
    Write-Host "[*] Компиляция ZapretVpnSync.exe..." -ForegroundColor Gray
    $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) {
        $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    }
    $csPath = Join-Path $scriptDir "ZapretVpnSync.cs"
    & $csc /nologo /target:winexe /out:$exePath /reference:System.dll,System.ServiceProcess.dll,System.Core.dll $csPath
}

Write-Host "Запуск в интерактивном режиме..." -ForegroundColor Cyan
Write-Host "Включайте и выключайте VPN в приложении INCY, чтобы увидеть реакцию." -ForegroundColor Cyan
Write-Host "Для выхода нажмите Ctrl+C." -ForegroundColor Gray
Write-Host ""

& $exePath --console
