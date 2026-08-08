$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " IVERILOG DUAL CORE TEST RUNNER " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "Step 1: Generating file list for iverilog..." -ForegroundColor Yellow
$tempFileList = "filelist_iverilog.txt"

# Lấy các file từ filelist.txt, bỏ qua tb_single_core.v
Get-Content filelist.txt | Where-Object { 
    $_ -notmatch "tb_single_core.v" -and 
    $_ -match "\S" -and 
    $_ -notmatch "^#" 
} | Out-File $tempFileList -Encoding ASCII

# Thêm tb_dual_core.sv vào danh sách compile
Add-Content $tempFileList "Verilog/pipeline/TestBench/tb_core/tb_dual_core.sv"

Write-Host "Step 2: Compiling with iverilog..." -ForegroundColor Yellow
$compileCmd = "iverilog -g2012 -I Verilog/pipeline/include -I Verilog/pipeline/RV32ICMFA -I Verilog/pipeline/dual_core -c $tempFileList -s tb_dual_core -o sim.vvp"
Invoke-Expression $compileCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation Failed! Aborting." -ForegroundColor Red
    exit
}
Write-Host "Compilation Successful!" -ForegroundColor Green

Write-Host "Step 3: Running simulation with vvp..." -ForegroundColor Yellow
vvp sim.vvp

if ($LASTEXITCODE -ne 0) {
    Write-Host "Simulation Failed!" -ForegroundColor Red
} else {
    Write-Host "Simulation Completed!" -ForegroundColor Green
}

Write-Host "=============================================" -ForegroundColor Cyan
