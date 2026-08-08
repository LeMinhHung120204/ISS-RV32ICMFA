param(
    [Parameter(Mandatory=$true)]
    [string]$InputAssembly,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputHex
)

# Đảm bảo đường dẫn sử dụng / để chạy trên WSL
$InputAssembly = $InputAssembly.Replace('\', '/')
$OutputHex = $OutputHex.Replace('\', '/')
$ElfFile = $InputAssembly + ".elf"

Write-Host "Compiling $InputAssembly to $ElfFile using wsl riscv64-unknown-elf-gcc..." -ForegroundColor Yellow
wsl riscv64-unknown-elf-gcc -march=rv32ia -mabi=ilp32 -nostdlib -Ttext 0x0 -o $ElfFile $InputAssembly

if ($LASTEXITCODE -ne 0) {
    Write-Host "GCC Compilation Failed!" -ForegroundColor Red
    exit
}

Write-Host "Converting $ElfFile to $OutputHex..." -ForegroundColor Yellow
wsl python3 elf2hex.py $ElfFile $OutputHex

if ($LASTEXITCODE -ne 0) {
    Write-Host "elf2hex Conversion Failed!" -ForegroundColor Red
    exit
}

# Xóa file elf tạm thời
Remove-Item -Path $ElfFile -ErrorAction SilentlyContinue
Write-Host "Success! Created $OutputHex" -ForegroundColor Green
