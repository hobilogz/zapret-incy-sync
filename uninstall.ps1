# Удаление службы Zapret & INCY VPN Sync
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Запрос прав администратора..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$serviceName = "ZapretVpnSync"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   Удаление службы Zapret & INCY VPN Sync" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "[*] Остановка службы..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName | Out-Null
    Write-Host "[ГОТОВО] Служба $serviceName успешно удалена из системы." -ForegroundColor Green
} else {
    Write-Host "[ИНФО] Служба $serviceName не найдена в системе." -ForegroundColor Gray
}

Write-Host ""
Read-Host "Нажмите Enter для завершения"
