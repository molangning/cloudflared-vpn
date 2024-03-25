$mode = $args[0]

echo "[+] Made with <3 by @molangning on github!"
echo "[+] This is meant to run on windows only. If you are running this on linux use the .sh version"
 
if (-not (Test-Path "logs/")) {
    New-Item -ItemType Directory -Path "logs/"
}
if (-not (Test-Path "bin/")) {
    New-Item -ItemType Directory -Path "bin/"
}
 
function usage {
    Write-Host
    Write-Host "==== Chisel socks proxy over cloudflare ===="
    Write-Host
    Write-Host "Script comes in two modes, client and server"
    Write-Host "Client: $PScriptName client URL SOCKS_PORT"
    Write-Host "Server: $PScriptName server "
    Write-Host
    Write-Host "============================================"
    exit
}
 
if ($mode -ne "server" -and $mode -ne "client") {
    usage
}
 
if ($mode -eq "client") {
    $server = $args[1]
    $socks_port = if ($args[2]) { $args[2] } else { 1080 }
}
 
$architecture = "386"
 
if ([Environment]::Is64BitOperatingSystem) {
    $architecture = "amd64"
}
 
Write-Host "[+] Detected architecture $architecture"
 
#https://learn.microsoft.com/en-us/archive/msdn-technet-forums/5aa53fef-5229-4313-a035-8b3a38ab93f5
 
function DeGZip-File{
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
        )
 
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
 
    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
        }
 
    $gzipStream.Close()
    $output.Close()
    $input.Close()
}
 
function Download-Chisel {
    Write-Host "[+] Downloading chisel"
 
    $response = Invoke-RestMethod "https://api.github.com/repos/jpillora/chisel/releases/latest"
    $tag_name =  $response.name.Substring(1)
    $downloadUrl = "https://github.com/jpillora/chisel/releases/download/v$tag_name/chisel_$($tag_name)_windows_$architecture.gz"
 
    Invoke-WebRequest -Uri $downloadUrl -OutFile "bin/windows-chisel.exe.gz"
 
    Write-Host "[+] Unpacking chisel"
    DeGZip-File "bin/windows-chisel.exe.gz" "bin/windows-chisel.exe"
 
    Write-Host "[+] Chisel downloaded"
}
 
function Download-Cloudflared {
    Write-Host "[+] Downloading cloudflared"
    $downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$architecture.exe"
    Invoke-WebRequest -Uri $downloadUrl -OutFile "bin/windows-cloudflared.exe"
    Write-Host "[+] Cloudflared downloaded"
}
 
function Serve-Forever {
    Start-Process -FilePath "powershell" -ArgumentList "-Command", "bin/windows-chisel.exe server --host localhost --socks5 2>&1 | % ToString | Tee-Object logs/chisel-server.txt"
    Start-Process -FilePath "powershell" -ArgumentList "-Command", "bin/windows-cloudflared.exe tunnel --url 127.0.0.1:8080 2>&1 | % ToString | Tee-Object logs/cloudflared.txt"
 }
 
 
function Start-Socks {
    Write-Host "[+] Starting socks listener on $socks_port"
    echo "bin/windows-chisel.exe client $server $socks_port:socks 2>&1 | % ToString | Tee-Object logs/chisel-client.txt"
    Start-Process -FilePath "powershell" -ArgumentList "-Command", "bin/windows-chisel.exe client $server $($socks_port):socks 2>&1 | % ToString | Tee-Object logs/chisel-client.txt"
}
 
 
if (-not (Test-Path "bin/windows-chisel.exe")) {
    Download-Chisel
 
}
 
if ($mode -eq "server") {
    if (-not (Test-Path "bin/windows-cloudflared.exe")) {
        Download-Cloudflared
    }
 
    Serve-Forever
} else {
    Start-Socks

}

