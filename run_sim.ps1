param(
    [string]$ElfFile = ""
)

# 1. Nếu có truyền file ELF, sẽ tự động convert sang HEX qua WSL
if ($ElfFile -ne "") {
    Write-Host "[1/4] Converting ELF to HEX..." -ForegroundColor Cyan
    wsl python3 elf2hex.py $ElfFile Verilog/hexfile.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to convert Hex." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "[1/4] No ELF file provided. Using existing hexfile.txt..." -ForegroundColor Yellow
}

# 2. Biên dịch bằng Icarus Verilog dựa vào danh sách file
Write-Host "[2/4] Compiling Verilog with Icarus Verilog..." -ForegroundColor Cyan
# Đọc các dòng không phải là comment từ filelist.txt
$v_files = Get-Content filelist.txt | Where-Object { $_ -match "\S" -and $_ -notmatch "^#" }

# Biên dịch (-s tb_single_core để set Top Module)
iverilog -s tb_single_core -o sim.vvp -I Verilog/pipeline/include -I Verilog/pipeline/RV32ICMFA -I Verilog/pipeline/dual_core $v_files
if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation Failed!" -ForegroundColor Red
    exit
}

# 3. Chạy mô phỏng
Write-Host "[3/4] Running Simulation..." -ForegroundColor Cyan
vvp sim.vvp
if ($LASTEXITCODE -ne 0) {
    Write-Host "Simulation Failed!" -ForegroundColor Red
    exit
}

# 4. Mở Waveform
Write-Host "[4/4] Opening GTKWave..." -ForegroundColor Cyan
gtkwave tb_single_core.vcd
