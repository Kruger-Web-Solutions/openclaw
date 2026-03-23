# OpenClaw Personal Assistant — Full Deployment Orchestration Script
# Run from Windows PowerShell in C:\Project\openclaw
#
# BEFORE RUNNING:
#   1. Find the current VM IP (check with the user if VM is off or IP changed)
#   2. Update $vmIP below
#   3. Ensure the VM is running and SSH is accessible
#   4. Ensure all code is pushed to origin: git push origin main
#
# USAGE: .\docs\custom\vm-deploy\deploy-all.ps1

param(
    [string]$vmIP = "192.168.122.82"   # UPDATE THIS if VM IP changed
)

$sshKey = "C:\Users\henza\.ssh\id_rsa"
$vm = "henzard@$vmIP"
$repoRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent

Write-Host "=== OpenClaw Personal Assistant Deployment ===" -ForegroundColor Cyan
Write-Host "VM: $vm" -ForegroundColor Yellow
Write-Host "Repo: $repoRoot" -ForegroundColor Yellow

# Test connectivity first
Write-Host "`n[0] Testing SSH connectivity..." -ForegroundColor Cyan
$testResult = ssh -i $sshKey -o BatchMode=yes -o ConnectTimeout=10 $vm "echo SSH_OK" 2>&1
if ($testResult -ne "SSH_OK") {
    Write-Host "ERROR: Cannot connect to VM at $vmIP" -ForegroundColor Red
    Write-Host "Check: Is the VM running? Is the IP correct?" -ForegroundColor Red
    Write-Host "Try: ssh -i $sshKey $vm" -ForegroundColor Yellow
    exit 1
}
Write-Host "  SSH OK" -ForegroundColor Green

# ─── Phase 1: Push code ───────────────────────────────────────────────────────

Write-Host "`n[1] Pushing code to remote..." -ForegroundColor Cyan
Set-Location $repoRoot
git push origin main 2>&1
git push kws main 2>&1
Write-Host "  Code pushed" -ForegroundColor Green

# ─── Phase 2: Deploy code to VM ──────────────────────────────────────────────

Write-Host "`n[2] Deploying code to VM (git pull + build + install)..." -ForegroundColor Cyan
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\phase2-deploy-code.sh" "${vm}:/tmp/oc-phase2.sh"
ssh -i $sshKey $vm "bash /tmp/oc-phase2.sh && rm /tmp/oc-phase2.sh"
Write-Host "  Phase 2 complete" -ForegroundColor Green

# ─── Phase 3: Sparky prep (Docker + download) ────────────────────────────────

Write-Host "`n[3] Preparing SparkyFitness..." -ForegroundColor Cyan
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\phase3-sparky-setup.sh" "${vm}:/tmp/oc-phase3.sh"
ssh -i $sshKey $vm "bash /tmp/oc-phase3.sh && rm /tmp/oc-phase3.sh"
Write-Host "  Phase 3 prep complete" -ForegroundColor Green
Write-Host "  ACTION REQUIRED: SSH to VM, edit ~/sparky/.env, then run 'cd ~/sparky && docker compose up -d'" -ForegroundColor Yellow

# ─── Phase 4: SCP MCP server ─────────────────────────────────────────────────

Write-Host "`n[4] Deploying MCP server..." -ForegroundColor Cyan
scp -i $sshKey "$repoRoot\tools\openclaw-mcp-server.mjs" "${vm}:~/openclaw-custom/tools/openclaw-mcp-server.mjs"
$toolCount = ssh -i $sshKey $vm "grep -c 'server.tool(' ~/openclaw-custom/tools/openclaw-mcp-server.mjs"
Write-Host "  MCP server deployed — $toolCount tools" -ForegroundColor Green
Write-Host "  Reconnect MCP in Cursor: Ctrl+Shift+P → 'MCP: Reconnect servers'" -ForegroundColor Yellow

# ─── Phase 5: TOOLS.md + calendar-2026.json ──────────────────────────────────

Write-Host "`n[5] Deploying workspace files (TOOLS.md, calendar-2026.json)..." -ForegroundColor Cyan
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\TOOLS.md" "${vm}:~/.openclaw/workspace/TOOLS.md"
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\calendar-2026.json" "${vm}:~/.openclaw/workspace/calendar-2026.json"
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\phase5-workspace-setup.sh" "${vm}:/tmp/oc-phase5.sh"
ssh -i $sshKey $vm "bash /tmp/oc-phase5.sh && rm /tmp/oc-phase5.sh"
Write-Host "  Phase 5 complete" -ForegroundColor Green

# ─── Phase 6: Verify gateway + whitelist ─────────────────────────────────────

Write-Host "`n[6] Verifying gateway health..." -ForegroundColor Cyan
$health = ssh -i $sshKey $vm "source ~/.profile; openclaw health 2>&1"
Write-Host "  $health" -ForegroundColor Gray

# ─── Phase 7: Create cron jobs ───────────────────────────────────────────────

Write-Host "`n[7] Creating cron jobs (this may take a minute)..." -ForegroundColor Cyan
scp -i $sshKey "$repoRoot\docs\custom\vm-deploy\phase7-crons-v2.sh" "${vm}:/tmp/oc-phase7.sh"
ssh -i $sshKey $vm "bash /tmp/oc-phase7.sh && rm /tmp/oc-phase7.sh"
Write-Host "  Phase 7 complete" -ForegroundColor Green

# ─── Summary ─────────────────────────────────────────────────────────────────

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Remaining manual steps:" -ForegroundColor Yellow
Write-Host "  1. SPARKY: SSH to VM → edit ~/sparky/.env → docker compose up -d" -ForegroundColor Yellow
  Write-Host "  2. SPARKY: Create account at http://${vmIP}:3004 → set macro goals → create saved meals → get API token" -ForegroundColor Yellow
Write-Host "  3. SPARKY: echo 'your-token' > ~/.openclaw/secrets/sparky-token" -ForegroundColor Yellow
Write-Host "  4. GCAL: Todoist app → Settings → Integrations → Google Calendar → enable two-way sync" -ForegroundColor Yellow
Write-Host "  5. CURSOR: Ctrl+Shift+P → 'MCP: Reconnect servers'" -ForegroundColor Yellow
Write-Host "  6. TODOIST: Create projects (Home, Weighsoft, Nedbank, Books, Personal Growth) via MCP tool" -ForegroundColor Yellow
Write-Host "  7. HABITICA: Create dailies + habits via MCP tool" -ForegroundColor Yellow
Write-Host ""
Write-Host "Sign-off checklist is in docs/custom/vm-deploy/sign-off-checklist.md" -ForegroundColor Cyan
