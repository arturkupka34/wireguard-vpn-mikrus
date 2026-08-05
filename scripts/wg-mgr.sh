#!/bin/bash
set -e

SERVER_ENDPOINT="xander504.mikr.us.xyz:20504"
WG_IF="wg0"
WG_CONF="/etc/wireguard/${WG_IF}.conf"
CLIENTS_DIR="/etc/wireguard/clients"
VPN_SUBNET="10.77.77"
ALLOWED_IPS="10.77.77.0/24"

SERVER_PUBKEY=$(cat /etc/wireguard/server_public.key 2>/dev/null)

mkdir -p "$CLIENTS_DIR"
chmod 700 "$CLIENTS_DIR"

find_free_ip() {
    for i in {7..254}; do
        local test_ip="${VPN_SUBNET}.${i}"
        if ! grep -q "$test_ip" "$WG_CONF" 2>/dev/null; then
            echo "$test_ip"
            return 0
        fi
    done
    echo ""
}

add_client() {
    local client_name="$1"
    local target_ip="$2"

    if [ -z "$client_name" ]; then
        read -p "Podaj nazwę klienta: " client_name
    fi

    client_name=$(echo "$client_name" | sed 's/[^a-zA-Z0-9_-]//g')
    
    if [ -z "$client_name" ]; then
        echo "❌ Błąd: Nieprawidłowa nazwa!"
        exit 1
    fi

    local client_dir="${CLIENTS_DIR}/${client_name}"
    if [ -d "$client_dir" ]; then
        echo "❌ Błąd: Klient '$client_name' już istnieje!"
        exit 1
    fi

    if [ -z "$target_ip" ]; then
        target_ip=$(find_free_ip)
        if [ -z "$target_ip" ]; then
            echo "❌ Błąd: Brak wolnych IP w podsieci!"
            exit 1
        fi
    fi

    echo "⚙️  Generowanie konfiguracji dla: $client_name ($target_ip)..."

    mkdir -p "$client_dir"
    chmod 700 "$client_dir"
    
    local privkey=$(wg genkey)
    local pubkey=$(echo "$privkey" | wg pubkey)
    local psk=$(wg genpsk)

    echo "$privkey" > "${client_dir}/private.key"
    echo "$pubkey" > "${client_dir}/public.key"
    echo "$psk" > "${client_dir}/preshared.key"
    chmod 600 "${client_dir}"/*

    local conf_file="${client_dir}/${client_name}.conf"
    
    cat <<EOF > "$conf_file"
[Interface]
PrivateKey = ${privkey}
Address = ${target_ip}/32

[Peer]
PublicKey = ${SERVER_PUBKEY}
PresharedKey = ${psk}
Endpoint = ${SERVER_ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}
PersistentKeepalive = 25
EOF

    chmod 600 "$conf_file"

    cat <<EOF >> "$WG_CONF"

# Client: ${client_name}
[Peer]
PublicKey = ${pubkey}
PresharedKey = ${psk}
AllowedIPs = ${target_ip}/32
EOF

    wg syncconf "$WG_IF" <(wg-quick strip "$WG_IF")

    echo "✅ Utworzono klienta $client_name ($target_ip)"
    echo "📄 Plik: $conf_file"
    echo ""
    qrencode -t ansiutf8 < "$conf_file"
}

remove_client() {
    local client_name="$1"
    local client_dir="${CLIENTS_DIR}/${client_name}"
    
    if [ ! -d "$client_dir" ]; then
        echo "❌ Błąd: Klient nie istnieje!"
        exit 1
    fi

    sed -i "/# Client: ${client_name}/,+4d" "$WG_CONF"
    wg syncconf "$WG_IF" <(wg-quick strip "$WG_IF")
    rm -rf "$client_dir"

    echo "✅ Klient $client_name usunięty."
}

list_clients() {
    echo "=== KLIENCI WIREGUARD ==="
    printf "%-20s %-15s\n" "NAZWA" "ADRES IP"
    echo "-----------------------------------"
    for dir in "${CLIENTS_DIR}"/*; do
        if [ -d "$dir" ]; then
            local name=$(basename "$dir")
            local ip=$(grep "Address" "${dir}/${name}.conf" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
            printf "%-20s %-15s\n" "$name" "$ip"
        fi
    done
}

case "$1" in
    add) add_client "$2" "$3" ;;
    del|remove) remove_client "$2" ;;
    list|ls) list_clients ;;
    qr)
        if [ -f "${CLIENTS_DIR}/$2/$2.conf" ]; then
            qrencode -t ansiutf8 < "${CLIENTS_DIR}/$2/$2.conf"
        fi
        ;;
    *)
        echo "Użycie: wg-mgr {add|del|list|qr} [nazwa] [IP]"
        exit 1
        ;;
esac
