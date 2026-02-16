# Copyright  observIQ, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#Requires -RunAsAdministrator

param(
    [switch]$Uninstall,
    [string]$DownloadURL,
    [string]$FilePath,
    [string]$CollectorURL,
    [string]$Endpoint,
    [string]$SecretKey
)

$ErrorActionPreference = "Stop"

# Supervisor's installation directory
$InstallDir = "C:\Program Files\bindplane-supervisor"

# Default collector binary path
$CollectorBin = "$InstallDir\bin\collector.exe"

# Supervisor config file path
$SupervisorConfig = "$InstallDir\supervisor-config.yaml"

# Service name
$ServiceName = "bindplane-supervisor"

function Show-Usage {
    Write-Host @"
Usage: .\install_windows.ps1 [options]

Options:
  -Uninstall           Uninstall bindplane-supervisor and remove all associated files
  -DownloadURL <url>   URL to download the supervisor MSI package
  -FilePath <path>     Path to a local MSI package file
  -CollectorURL <url>  URL to download the collector binary
  -Endpoint <url>      (required for install) Bindplane endpoint URL (e.g. wss://app.bindplane.com/v1/opamp)
  -SecretKey <key>     (required for install) Bindplane secret key for authentication

PowerShell supports parameter abbreviation. You can shorten any parameter
to its unique prefix (e.g. -E for -Endpoint, -S for -SecretKey, -D for
-DownloadURL, -F for -FilePath, -C for -CollectorURL).

If neither -DownloadURL nor -FilePath is provided, the script
checks for an existing installation and errors if none is found.
"@
    exit 1
}

function Install-Package {
    param([string]$File)

    if (-not $File.EndsWith(".msi")) {
        Write-Error "Error: unsupported package type for file '$File'. Expected .msi"
        exit 1
    }

    Write-Host "Installing package: $File"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$File`" /quiet /norestart" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Error: MSI installation failed with exit code $($process.ExitCode)"
        exit 1
    }
    Write-Host "Package installed successfully"
}

function Download-AndInstallPackage {
    param([string]$URL)

    $tmpDir = Join-Path $env:TEMP "bindplane-supervisor-install"
    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
    }
    New-Item -ItemType Directory -Path $tmpDir | Out-Null

    $tmpFile = Join-Path $tmpDir "bindplane-supervisor.msi"

    Write-Host "Downloading package from: $URL"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $URL -OutFile $tmpFile -UseBasicParsing
    } catch {
        Write-Error "Error: failed to download package: $_"
        exit 1
    }
    Write-Host "Download complete"

    Install-Package -File $tmpFile
    Remove-Item -Recurse -Force $tmpDir
}

function Test-ServiceInstalled {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Existing installation found (Windows service)"
        return $true
    }

    if (Test-Path (Join-Path $InstallDir "supervisor.exe")) {
        Write-Host "Existing installation found (supervisor binary)"
        return $true
    }

    return $false
}

function Stop-SupervisorService {
    Write-Host "Stopping $ServiceName service..."
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        # Wait for the service to fully stop
        $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
}

function Start-SupervisorService {
    Write-Host "Starting $ServiceName service..."
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Start-Service -Name $ServiceName
    } else {
        Write-Warning "Warning: $ServiceName service not found, service not started"
    }
}

function Update-SupervisorConfig {
    Write-Host "Writing supervisor config to $SupervisorConfig"

    $escapedInstallDir = $InstallDir -replace '\\', '\\'
    $escapedCollectorBin = $CollectorBin -replace '\\', '\\'

    $configContent = @"
# Bindplane Supervisor Configuration for Windows
# Documentation: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor

# OpAMP server connection settings
server:
  # Bindplane SaaS endpoint
  endpoint: "$Endpoint"
  headers:
    # Replace with your Bindplane secret key from the Bindplane UI
    "X-Bindplane-Authorization": "Secret-Key $SecretKey"

# Supervisor capabilities reported to the OpAMP server
capabilities:
  reports_effective_config: true
  reports_own_metrics: true
  reports_health: true
  reports_remote_config: true
  reports_own_logs: true
  reports_heartbeat: true
  accepts_remote_config: true
  accepts_restart_command: true
  reports_available_components: true

# Managed OpenTelemetry Collector configuration
agent:
  # Path to your OpenTelemetry Collector executable
  executable: "$escapedCollectorBin"

# Persistent storage for supervisor state
storage:
  directory: "$escapedInstallDir\\supervisor_storage"

# Supervisor telemetry settings
telemetry:
  logs:
    level: info
    output_paths:
      - "$escapedInstallDir\\supervisor.log"
"@

    Set-Content -Path $SupervisorConfig -Value $configContent -Encoding UTF8
    Write-Host "Supervisor config updated successfully"
}

function Install-Collector {
    param([string]$URL)

    $collectorDir = Split-Path -Parent $CollectorBin
    Write-Host "Installing collector binary to: $CollectorBin"
    if (-not (Test-Path $collectorDir)) {
        New-Item -ItemType Directory -Path $collectorDir | Out-Null
    }

    $tmpDir = Join-Path $env:TEMP "bindplane-collector-install"
    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
    }
    New-Item -ItemType Directory -Path $tmpDir | Out-Null

    $tmpFile = Join-Path $tmpDir "collector_download"

    Write-Host "Downloading collector from: $URL"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $URL -OutFile $tmpFile -UseBasicParsing
    } catch {
        Write-Error "Error: failed to download collector: $_"
        Remove-Item -Recurse -Force $tmpDir
        exit 1
    }
    Write-Host "Download complete"

    # Strip query parameters for file type detection
    $urlPath = ($URL -split '\?')[0]

    if ($urlPath -match '\.zip$') {
        Write-Host "Extracting zip archive..."
        $extractDir = Join-Path $tmpDir "extracted"
        Expand-Archive -Path $tmpFile -DestinationPath $extractDir -Force
        $found = Get-ChildItem -Path $extractDir -Recurse -File | Select-Object -First 1
        Copy-Item -Path $found.FullName -Destination $CollectorBin -Force
    } else {
        Copy-Item -Path $tmpFile -Destination $CollectorBin -Force
    }

    Remove-Item -Recurse -Force $tmpDir
    Write-Host "Collector installed successfully"
}

function Uninstall-Supervisor {
    Write-Host "Uninstalling bindplane-supervisor..."

    Stop-SupervisorService

    # Attempt MSI uninstall via registry
    $uninstallKey = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -eq "Bindplane Supervisor" }

    if ($uninstallKey) {
        $productCode = $uninstallKey.PSChildName
        Write-Host "Found MSI product: $productCode, uninstalling..."
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Warning "MSI uninstall exited with code $($process.ExitCode)"
        } else {
            Write-Host "MSI package removed successfully"
        }
    } else {
        Write-Host "No MSI package found, proceeding with manual cleanup..."
    }

    # Remove collector binary and bin directory
    if (Test-Path $CollectorBin) {
        Remove-Item -Force $CollectorBin
    }
    $binDir = Split-Path -Parent $CollectorBin
    if ((Test-Path $binDir) -and -not (Get-ChildItem $binDir)) {
        Remove-Item -Force $binDir
    }

    # Remove install directory and remaining contents
    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
    }

    Write-Host "bindplane-supervisor has been uninstalled successfully"
}

# --- Main ---

# Uninstall mode takes precedence over all other flags
if ($Uninstall) {
    Uninstall-Supervisor
    exit 0
}

# Validate required install parameters
if (-not $Endpoint) {
    Write-Error "Error: -Endpoint is required"
    exit 1
}

if (-not $SecretKey) {
    Write-Error "Error: -SecretKey is required"
    exit 1
}

# Validate mutually exclusive options
if ($DownloadURL -and $FilePath) {
    Write-Error "Error: -DownloadURL and -FilePath are mutually exclusive"
    exit 1
}

# Supervisor installation
if ($DownloadURL) {
    Download-AndInstallPackage -URL $DownloadURL
} elseif ($FilePath) {
    Install-Package -File $FilePath
} else {
    if (-not (Test-ServiceInstalled)) {
        Write-Error "Error: no existing bindplane-supervisor installation found. Use -DownloadURL or -FilePath to install a package."
        exit 1
    }
}

# Stop the service before modifying config or collector binary.
# The MSI installer or a previous run may have started it.
Stop-SupervisorService

# Supervisor config update
Update-SupervisorConfig

# Collector download
if ($CollectorURL) {
    Install-Collector -URL $CollectorURL
}

# Start the service with the updated config and collector
Start-SupervisorService
