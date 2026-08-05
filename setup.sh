#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Uruchom instalator jako root (sudo ./setup.sh)"
  exit 1
fi

echo "🚀 Rozpoczynanie instalacji WireGuard na Mikrusie..."

# 1. Instalacja pakietów
apt update && apt install -y wireguard wireguard-tools qrencode iptables-persistent

# 2. Włączenie IP Forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system > /dev/null

# 3. Kopiowanie skryptów pomocniczych
cp scripts/wg-firewall.sh /usr/local/bin/
cp scripts/wg-mgr.sh /usr/local/bin/wg-mgr
chmod +x /usr/local/bin/wg-firewall.sh
chmod +x /usr/local/bin/wg-mgr

# 4. Generowanie kluczy serwera (jeśli nie istnieją)
mkdir -p /etc/wireguard
if [ ! -f /etc/wireguard/server_private.key ]; then
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    chmod 600 /etc/wireguard/server_private.key
fi

SERVER_PRIVKEY=$(cat /etc/wireguard/server_private.key)

# 5. Generowanie wg0.conf
sed "s|__SERVER_PRIVATE_KEY__|${SERVER_PRIVKEY}|g" templates/wg0.conf.template > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# 6. Uruchomienie i włączenie autostartu
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo ""
echo "✅ Instalacja zakończona sukcesem!"
echo "Możesz zarządzać użytkownikami wpisując polecenie: wg-mgr"
