param(
    [string]$TestFolder = "riscv-tests/isa",
    [string]$Filter = "rv32*-p-*"
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " RISC-V AUTO TEST RUNNER " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Biên dịch Verilog (Chỉ làm 1 lần để tiết kiệm thời gian)
Write-Host "Step 1: Compiling Verilog files with Vivado (xvlog)..." -ForegroundColor Yellow
$v_files = Get-Content filelist.txt | Where-Object { $_ -match "\S" -and $_ -notmatch "^#" }
$v_files_array = $v_files -join " "

Invoke-Expression "C:\Xilinx\Vivado\2022.2\bin\xvlog.bat -sv -i Verilog/pipeline/include -i Verilog/pipeline/RV32ICMFA -i Verilog/pipeline/dual_core $v_files_array"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation (xvlog) Failed! Aborting tests." -ForegroundColor Red
    exit
}

Write-Host "Step 1.5: Elaborating with Vivado (xelab)..." -ForegroundColor Yellow
C:\Xilinx\Vivado\2022.2\bin\xelab.bat -debug typical -top tb_single_core -snapshot tb_sim
if ($LASTEXITCODE -ne 0) {
    Write-Host "Elaboration (xelab) Failed! Aborting tests." -ForegroundColor Red
    exit
}

# Lấy danh sách các file test (chỉ lấy rv32ui và rv32ua, bỏ qua fence_i và các file mở rộng)
$tests = Get-ChildItem -Path $TestFolder -File | Where-Object {
    (($_.Name -match "^rv32ui-p-") -or ($_.Name -match "^rv32ua-p-")) -and ($_.Name -ne "rv32ui-p-fence_i")
} | Where-Object { $_.Extension -eq "" } | Select-Object -ExpandProperty FullName

$total = $tests.Count
$passed = 0
$failed = 0
$timeout = 0

Write-Host "Found $total tests to run." -ForegroundColor Yellow
Write-Host "Step 2: Running Tests..." -ForegroundColor Yellow
Write-Host "---------------------------------------------"

# Xóa file log cũ nếu có
$logFile = "test_results.log"
if (Test-Path $logFile) { Remove-Item $logFile }
"RISC-V Test Results Log`n======================`n" | Out-File $logFile

foreach ($test in $tests) {
    $testName = Split-Path $test -Leaf
    $relPath = "$TestFolder/$testName"
    Write-Host -NoNewline "Running $testName ... "

    # Convert ELF to Hex using relative paths so WSL doesn't choke on C:\
    wsl python3 elf2hex.py $relPath Verilog/hexfile.txt 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Hex Conversion Failed" -ForegroundColor Red
        continue
    }

    # Chạy mô phỏng bằng xsim
    $simOutput = C:\Xilinx\Vivado\2022.2\bin\xsim.bat tb_sim -R 2>&1

    # Kiểm tra kết quả
    if ($simOutput -match "RESULT: PASS") {
        Write-Host "PASS" -ForegroundColor Green
        "PASS : $testName" | Out-File -Append $logFile
        $passed++
    }
    elseif ($simOutput -match "RESULT: FAIL at test case (\d+)") {
        $testCase = $matches[1]
        Write-Host "FAIL (Case $testCase)" -ForegroundColor Red
        "FAIL : $testName (Failed at test case $testCase)" | Out-File -Append $logFile
        $failed++
    }
    elseif ($simOutput -match "RESULT: TIMEOUT") {
        Write-Host "TIMEOUT" -ForegroundColor Magenta
        "TIMEOUT : $testName" | Out-File -Append $logFile
        $timeout++
    }
    else {
        Write-Host "UNKNOWN/CRASH" -ForegroundColor Red
        "UNKNOWN: $testName" | Out-File -Append $logFile
        $failed++
    }
}

Write-Host "---------------------------------------------"
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "Total: $total | Passed: $passed | Failed: $failed | Timeout: $timeout" -ForegroundColor Cyan
Write-Host "Detailed log saved to: $logFile" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Cyan
