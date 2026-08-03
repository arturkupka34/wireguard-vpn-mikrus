# Audyt wydania 3.2.3

## Zakres

Audyt obejmuje wszystkie pliki wykonywalne projektu, generowanie konfiguracji WireGuard, parser ustawień, walidację danych wejściowych, transakcje klientów, reguły `iptables`, instalację, aktualizację, kopię zapasową i deinstalację.

## Kontrole wykonywane przez `make test`

- składnia wszystkich skryptów Bash przez `bash -n`;
- lokalna regresja SC2155: brak deklaracji zmiennych połączonych z podstawieniem polecenia;
- składnia i podstawowa struktura `.github/workflows/ci.yml` przez PyYAML;
- zgodność `src/mikrus-wg` z `src/mikrus-wg.sha256`;
- walidatory nazw, endpointów, portów, podsieci, ról, kluczy i reguł `custom`;
- brak profili z `AllowedIPs = 0.0.0.0/0` lub `::/0`;
- brak reguł NAT/MASQUERADE tworzonych przez projekt;
- polityki `acl`, `mesh`, `rdp` i `custom` na atrapach `iptables`;
- wycofywanie nieudanych operacji dodania, usunięcia i zmiany klienta;
- wycofywanie nieudanej instalacji i przerwanej deinstalacji;
- integralność bootstrapu i aktualizacji przez SHA-256;
- odrzucanie dowiązań symbolicznych oraz niebezpiecznych uprawnień stanu.

GitHub Actions dodatkowo uruchamia ShellCheck na Linuksie i parser PowerShell na Windows.

## Ograniczenia

Testy z atrapami nie zastępują uruchomienia na rzeczywistym VPS. Po publikacji repozytorium należy najpierw uruchomić `preflight.sh`, następnie instalację, a na końcu `sudo mikrus-wg doctor`. Szczególnie zależne od środowiska są: dostępność `CAP_NET_ADMIN`, obsługa WireGuard przez kernel lub hosta kontenera, działanie `systemd`, backend `iptables` i dostępność portu UDP Mikrusa.

Nie ma uczciwej możliwości zagwarantowania braku wszystkich błędów. Wydanie zostało jednak zbudowane tak, aby przy błędzie kończyć działanie bez nadpisywania istniejącego `wg0` i — tam, gdzie jest to możliwe — wycofywać rozpoczętą zmianę.
