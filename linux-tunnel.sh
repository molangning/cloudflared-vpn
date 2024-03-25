#!/usr/bin/env bash

mode=$1

echo "[+] Made with <3 by @molangning on github!"
echo "[+] This is meant to run on linux only. If you are running this on windows use the .ps1 version"

mkdir -p logs/ bin/

function usage() {

    echo
    echo "==== Chisel socks proxy over cloudflare ===="
    echo
    echo "Script comes in two modes, client and server"
    echo "Client: $0 client URL SOCKS_PORT"
    echo "Server: $0 server "
    echo
    echo "============================================"

    exit

}

if [ $mode != "server" ] && [ $mode != "client" ]; then
    usage
fi

if [ $mode == "client" ]; then
    server=$2
    socks_port=${3:-1080}
fi

architecture=""

case $(uname -m) in
i386) architecture="386" ;;
i686) architecture="386" ;;
x86_64) architecture="amd64" ;;
arm) dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
esac

echo "[+] Detected architecture $architecture"

function download_chisel() {

    echo "[+] Downloading chisel"

    tag_name=$(curl -s https://api.github.com/repos/jpillora/chisel/releases/latest | jq '.name' | cut -b 3- | rev | cut -b 2- | rev)
    curl -sL https://github.com/jpillora/chisel/releases/download/v$tag_name/chisel_$tag_name\_linux_$architecture.gz -o bin/linux-chisel.gz

    echo "[+] Unpacking chisel"

    gunzip -f bin/linux-chisel.gz
    chmod +x bin/linux-chisel

    echo "[+] Chisel downloaded"
}

function download_cloudflared() {

    echo "[+] Downloading cloudflared"

    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$architecture -o bin/linux-cloudflared
    chmod +x bin/linux-cloudflared

    echo "[+] Cloudflared downloaded"
}

function serve_forever() {
    echo "[+] Serving proxy"
    bin/linux-chisel server --host localhost --socks5 2>&1 | tee logs/chisel-server.txt &
    bin/linux-cloudflared tunnel --url 127.0.0.1:8080 2>&1 | tee logs/cloudflared.txt
}

function start_socks_listener() {
    echo "[+] Starting socks listener on $socks_port"
    bin/linux-chisel client $server $socks_port:socks 2>&1 | tee logs/chisel-client.txt
}

if [ ! -f "bin/linux-chisel" ]; then
    download_chisel
fi

if [ $mode == "server" ]; then
    if [ ! -f "bin/linux-cloudflared" ]; then download_cloudflared; fi
    serve_forever

else
    start_socks_listener
fi
