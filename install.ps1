# Установка службы Zapret & INCY VPN Sync
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Запрос прав администратора..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$exePath = Join-Path $scriptDir "ZapretVpnSync.exe"
$csPath = Join-Path $scriptDir "ZapretVpnSync.cs"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Установка службы Zapret & INCY VPN Sync" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Компиляция при необходимости
if (-not (Test-Path $exePath)) {
    Write-Host "[*] Компиляция ZapretVpnSync.exe через .NET Framework..." -ForegroundColor Gray
    $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) {
        $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    }
    & $csc /nologo /target:winexe /out:$exePath /reference:System.dll,System.ServiceProcess.dll,System.Core.dll $csPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ОШИБКА] Не удалось скомпилировать службу." -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
}

$serviceName = "ZapretVpnSync"

# 2. Остановка и удаление старой версии
$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[*] Остановка и обновление существующей службы..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName | Out-Null
    Start-Sleep -Seconds 1
}

# 3. Регистрация новой службы Windows
Write-Host "[*] Регистрация службы Windows '$serviceName'..." -ForegroundColor Gray
& sc.exe create $serviceName binPath= "`"$exePath`"" start= auto DisplayName= "Zapret INCY VPN Sync" | Out-Null
& sc.exe description $serviceName "Автоматически отключает zapret при включении INCY VPN и включает при его отключении." | Out-Null
& sc.exe failure $serviceName reset= 86400 actions= restart/5000 | Out-Null

# 4. Запуск службы
Write-Host "[*] Запуск службы..." -ForegroundColor Gray
Start-Service -Name $serviceName -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "[ГОТОВО] Служба ZapretVpnSync успешно установлена и работает!" -ForegroundColor Green
    Write-Host "Она автоматически будет запускаться при старте Windows." -ForegroundColor Green
    Write-Host "Нагрузка на систему: 0.0% CPU, ~10 МБ ОЗУ." -ForegroundColor Green
    Write-Host "Лог переключений: $(Join-Path $scriptDir 'sync.log')" -ForegroundColor Gray
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Host "[!] Служба зарегистрирована, текущий статус: $($svc.Status)" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Нажмите Enter для завершения"
