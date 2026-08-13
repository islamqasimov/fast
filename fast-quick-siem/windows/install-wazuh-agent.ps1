# ============================================================
# F.A.S.T. - Windows Wazuh Agent Avtomatik Quraşdırma
# ============================================================
#
# Bu skript Windows host maşınında Wazuh Agent-i endirir,
# quraşdırır, Manager-ə (cloud VM-ə) qoşulacaq şəkildə
# konfiqurasiya edir və servisi başladır.
#
# TƏLƏB: PowerShell-i Administrator kimi aç, sonra işlət:
#
#   .\install-wazuh-agent.ps1 -ManagerIP "100.87.195.65"
#
# ManagerIP - Wazuh Manager-in işlədiyi cloud VM-in IP-sidir.
# Bu, VM-in public IP-si (curl ifconfig.me ilə VM-də tapılır)
# ya da Tailscale istifadə edirsənsə, VM-in Tailscale IP-si
# ola bilər (tailscale ip -4 ilə VM-də tapılır).
#
# İSTƏYƏ BAĞLI: Agent-ə xüsusi ad vermək istəyirsənsə:
#   .\install-wazuh-agent.ps1 -ManagerIP "100.87.195.65" -AgentName "elmir-laptop"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ManagerIP,

    [Parameter(Mandatory=$false)]
    [string]$AgentName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$WazuhVersion = "4.9.0"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Success($msg) {
    Write-Host "[OK] $msg" -ForegroundColor Green
}

function Write-Failure($msg) {
    Write-Host "[XETA] $msg" -ForegroundColor Red
}

# --- Administrator yoxlaması ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Failure "Bu skript Administrator hüququ tələb edir."
    Write-Host "PowerShell-i sağ-klik edib 'Run as Administrator' seç, sonra skripti yenidən işlət." -ForegroundColor Yellow
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  F.A.S.T. - Windows Wazuh Agent Quraşdırma" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Manager IP : $ManagerIP"
Write-Host "Agent Adı  : $AgentName"
Write-Host "Versiya    : $WazuhVersion"

# --- Manager IP-nin əlçatan olduğunu yoxla (1514/1515 portları) ---
Write-Step "Manager-in əlçatanlığı yoxlanılır ($ManagerIP)..."
$portsOk = $true
foreach ($port in 1514, 1515) {
    $test = Test-NetConnection -ComputerName $ManagerIP -Port $port -WarningAction SilentlyContinue
    if ($test.TcpTestSucceeded) {
        Write-Success "Port $port əlçatandır"
    } else {
        Write-Failure "Port $port əlçatan deyil"
        $portsOk = $false
    }
}

if (-not $portsOk) {
    Write-Host ""
    Write-Host "XƏBƏRDARLIQ: Bəzi portlar əlçatan deyil. Mümkün səbəblər:" -ForegroundColor Yellow
    Write-Host "  - Manager (VM) hələ tam açılmayıb (deploy.sh bitməyib)"
    Write-Host "  - VM-in firewall/security group qaydası 1514/1515 portlarını bağlayıb"
    Write-Host "  - Tailscale istifadə edirsənsə, hər iki tərəf (bu maşın və VM) qoşulu deyil"
    Write-Host ""
    $continue = Read-Host "Yenə də davam etmək istəyirsən? (b/x)"
    if ($continue -ne "b" -and $continue -ne "B") {
        Write-Host "Dayandırıldı."
        exit 1
    }
}

# --- Mövcud quraşdırmanı yoxla ---
$existingService = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Step "Mövcud Wazuh Agent tapıldı, dayandırılır..."
    Stop-Service -Name "WazuhSvc" -Force -ErrorAction SilentlyContinue
}

# --- MSI-ni endir ---
Write-Step "Wazuh Agent MSI endirilir (v$WazuhVersion)..."
$msiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVersion-1.msi"
$msiPath = "$env:TEMP\wazuh-agent.msi"

try {
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
    Write-Success "MSI endirildi: $msiPath"
} catch {
    Write-Failure "MSI endirilə bilmədi: $_"
    Write-Host "URL-i əl ilə yoxla: $msiUrl" -ForegroundColor Yellow
    exit 1
}

# --- Quraşdır ---
Write-Step "Wazuh Agent quraşdırılır..."
$installArgs = "/i `"$msiPath`" /q WAZUH_MANAGER=`"$ManagerIP`" WAZUH_REGISTRATION_SERVER=`"$ManagerIP`" WAZUH_AGENT_NAME=`"$AgentName`""

$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Failure "Quraşdırma xəta ilə bitdi (exit code: $($process.ExitCode))"
    exit 1
}
Write-Success "Wazuh Agent quraşdırıldı"

# --- Servisi başlat ---
Write-Step "Wazuh Agent servisi başladılır..."
try {
    Start-Service -Name "WazuhSvc"
    Start-Sleep -Seconds 5
    $service = Get-Service -Name "WazuhSvc"
    if ($service.Status -eq "Running") {
        Write-Success "Servis işləyir (Status: $($service.Status))"
    } else {
        Write-Failure "Servis işə düşmədi (Status: $($service.Status))"
    }
} catch {
    Write-Failure "Servis başladıla bilmədi: $_"
    exit 1
}

# --- Log-dan son sətirləri göstər (qoşulma vəziyyəti üçün) ---
Write-Step "Son log qeydləri (10 saniyə gözlənilir)..."
Start-Sleep -Seconds 10
$logPath = "C:\Program Files (x86)\ossec-agent\ossec.log"
if (Test-Path $logPath) {
    Get-Content -Path $logPath -Tail 10
} else {
    Write-Host "Log faylı tapılmadı: $logPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TAMAMLANDI" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Qoşulmanı Manager tərəfdə (VM-də) təsdiqlə:"
Write-Host "  docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l"
Write-Host ""
Write-Host "Yaxud Dashboard-da: Agents bölməsi -> '$AgentName' axtar"
Write-Host ""
Write-Host "Əgər 'SSL error, Connection refused' görürsənsə:"
Write-Host "  - Manager-in (VM-in) sağlam açıldığını yoxla"
Write-Host "  - docs/DEPLOYMENT_GUIDE.md -> 'Problemlərin Həlli' bölməsinə bax"
