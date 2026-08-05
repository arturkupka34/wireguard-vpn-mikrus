#!/bin/bash
INTERFACE="wg0"
ADMIN_RANGE="10.77.77.2-10.77.77.6"

# Czyszczenie starych reguł dedykowanych dla WG
iptables -D FORWARD -i $INTERFACE -o $INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $INTERFACE -o $INTERFACE -m iprange --src-range $ADMIN_RANGE -m state --state NEW -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $INTERFACE -o $INTERFACE -j DROP 2>/dev/null || true
iptables -D INPUT -i $INTERFACE -j DROP 2>/dev/null || true

# 1. Zezwól na odpowiedzi na połączenia (Reply) dla wszystkich
iptables -A FORWARD -i $INTERFACE -o $INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT

# 2. Zezwól na NOWE połączenia TYLKO Administratorom (10.77.77.2 - 10.77.77.6)
iptables -A FORWARD -i $INTERFACE -o $INTERFACE -m iprange --src-range $ADMIN_RANGE -m state --state NEW -j ACCEPT

# 3. Blokada inicjowania nowych połączeń dla pozostałych klientów (10.77.77.7+)
iptables -A FORWARD -i $INTERFACE -o $INTERFACE -j DROP

# 4. Blokada dostępu klientów VPN do usług na serwerze Mikrus (z wyjątkiem samoobsługi WG)
iptables -A INPUT -i $INTERFACE -j DROP
