# Private WireGuard VPN for Mikrus (xander504)

Prywatna sieć WireGuard przygotowana pod serwer Mikrus z obsługą izolacji klientów, brakiem NAT oraz brakiem publicznego panelu.

## 🚀 Szybka instalacja na serwerze Debian 13

Zaloguj się na swój serwer SSH:
```bash
ssh root@xander504.mikr.us.xyz -p 10504
```

Rozpakuj archiwum i uruchom instalator:
```bash
cd mikrus-wireguard
chmod +x setup.sh scripts/*.sh
sudo ./setup.sh
```

---

## 🛠️ Zarządzanie użytkownikami (`wg-mgr`)

Plik wykonywalny `wg-mgr` jest dostępny w systemie globalnie.

### 1. Dodawanie Administratora (Adresy 10.77.77.2 - 10.77.77.6)
Administratorzy mogą inicjować połączenia do wszystkich urządzeń w sieci:
```bash
sudo wg-mgr add admin-laptop 10.77.77.2
```

### 2. Dodawanie Zwykłego Klienta (Adresy 10.77.77.7+)
Zwykli klienci są odizolowani od siebie i mogą jedynie odpowiadać na ruch zainicjowany przez admina:
```bash
sudo wg-mgr add telefon-jan
```
*Skrypt automatycznie dobierze wolny IP oraz wyświetli kod QR do zeskanowania na telefonie.*

### 3. Pozostałe polecenia
```bash
sudo wg-mgr list              # Lista klientów
sudo wg-mgr qr <nazwa>        # Wyświetlenie kodu QR
sudo wg-mgr del <nazwa>       # Usunięcie klienta
```

---

## 🔒 Bezpieczeństwo
- Wszystkie klucze prywatne (`.key`) generowane są **wyłącznie na serwerze** i są ignorowane przez Git (`.gitignore`).
- Plik `.conf` wymusza `AllowedIPs = 10.77.77.0/24` (Split-Tunneling).
- Klienci nie mają dostępu do portów samego Mikrusa ani dostępu do Internetu przez VPS.
