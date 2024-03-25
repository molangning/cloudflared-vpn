#!/usr/bin/env bash

architecture=""
case $(uname -m) in
    i386)   architecture="386" ;;
    i686)   architecture="386" ;;
    x86_64) architecture="amd64" ;;
    arm)    dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
esac

function download() {
    mkdir -p bin/

    echo "[+] Downloading chisel"
    tag_name=$(curl -s https://api.github.com/repos/jpillora/chisel/releases/latest | jq '.name' | cut -b 3- | rev | cut -b 2- | rev)
    curl -sL https://github.com/jpillora/chisel/releases/download/v$tag_name/chisel_$tag_name\_linux_$architecture.gz -o bin/linux-chisel.gz

    echo "[+] Downloading cloudflared"
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$architecture -o bin/linux-cloudflared
}

function unpack() {
    echo "[+] Unpacking chisel"
    gunzip -f bin/linux-chisel.gz

    chmod +x bin/linux-chisel
    chmod +x bin/linux-cloudflared
}

if [ ! -f "bin/linux-chisel" ] || [ ! -f "bin/linux-cloudflared" ]; then
    download
    unpack
fi

mkdir -p logs/

bin/linux-chisel server --host localhost --socks5 2>&1 | tee logs/chisel &
bin/linux-cloudflared tunnel --url 127.0.0.1:8080 2>&1 | tee logs/cloudflared
