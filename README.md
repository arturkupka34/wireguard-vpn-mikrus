# WireGuard VPN dla Mikrusa `xander504`

**Wydanie:** `3.2.3`

Lekki serwer WireGuard typu **split-tunnel** do prywatnych połączeń między urządzeniami: RDP, SSH, administracja routerami, panele WWW i inne usługi dostępne przez adresy VPN.

Projekt nie kieruje Internetu klientów przez VPS. Przez WireGuard przechodzi wyłącznie ruch do podsieci `10.77.77.0/24`.

Kod jest skonfigurowany dla `xander504.mikr.us.xyz`, ID `504` i portu `20504/UDP`. Klucze prywatne powstają dopiero na serwerze i nie znajdują się w repozytorium.

## Gotowa konfiguracja

| Parametr | Wartość |
|---|---|
| Repozytorium | `arturkupka34/wireguard-vpn-mikrus` |
| System | Debian 13 |
| Host VPS | `xander504.mikr.us.xyz` |
| Login SSH | `root` |
| Port SSH | `10504/TCP` |
| ID Mikrusa | `504` |
| Port WireGuard | `20504/UDP` |
| Port rezerwowy | `30504/UDP` |
| Interfejs | `wg0` |
| Podsieć VPN | `10.77.77.0/24` |
| Adres serwera VPN | `10.77.77.1` |
| IPv6 w tunelu | wyłączony |
| NAT/MASQUERADE | brak |
| Dostęp klientów do VPS | zablokowany |
| Polityka domyślna | `acl` |

## Ważne przed rozpoczęciem

Jeżeli dane logowania zostały pokazane lub przesłane w niezabezpieczonym miejscu, potraktuj hasło roota jako ujawnione. Po pierwszym zalogowaniu natychmiast ustaw nowe:

```bash
ssh -p 10504 root@xander504.mikr.us.xyz
passwd
```

Nie wpisuj hasła do repozytorium, skryptów, issue ani plików konfiguracyjnych. Ten projekt go nie potrzebuje.

## Instalacja systemu

W panelu Mikrusa wybierz:

```text
Debian 13 (2025.09)
```

Ponowna instalacja systemu usuwa aktualne dane VPS. Po jej zakończeniu połącz się:

```bash
ssh -p 10504 root@xander504.mikr.us.xyz
```

## Sprawdzenie istniejącego `wg0`

Na świeżym systemie uruchom:

```bash
test -e /etc/wireguard/wg0.conf \
  && echo "UWAGA: /etc/wireguard/wg0.conf istnieje" \
  || echo "OK: brak /etc/wireguard/wg0.conf"

systemctl status wg-quick@wg0 --no-pager || true
wg show wg0 2>/dev/null || true
```

Instalator przerwie działanie, gdy znajdzie istniejący `/etc/wireguard/wg0.conf`. Nie nadpisuje cudzej konfiguracji.

## Publikacja na GitHubie

Repozytorium `arturkupka34/wireguard-vpn-mikrus` już istnieje. Nie twórz nowej historii przez `git init` i nie przesyłaj plików pojedynczo w edytorze WWW. Sklonuj istniejące repozytorium, skopiuj do niego całą zawartość tej paczki — łącznie z katalogiem `.github` — a następnie wykonaj commit i push.

Dokładna instrukcja dla GitHub Desktop i zwykłego Git znajduje się w [`PUBLISH_TO_GITHUB.md`](PUBLISH_TO_GITHUB.md).

Repozytorium powinno pozostać publiczne, aby instalacja z `raw.githubusercontent.com` nie wymagała tokenu.

## Kontrola przed instalacją

Po opublikowaniu repozytorium:

```bash
curl -fsSL https://raw.githubusercontent.com/arturkupka34/wireguard-vpn-mikrus/main/preflight.sh \
  | sudo bash
```

Kontrola niczego nie zmienia. Pokazuje system, endpoint, wyliczone porty i stan `wg0`.

## Instalacja jednym poleceniem

Wszystkie wartości są już ustawione dla `xander504`, dlatego nie trzeba przekazywać ID, hosta ani portu:

```bash
curl -fsSL https://raw.githubusercontent.com/arturkupka34/wireguard-vpn-mikrus/main/install.sh \
  | sudo bash
```

Instalator utworzy pierwszego klienta `admin-1` z adresem `10.77.77.2`.

Bezpieczniejszy wariant pozwalający przejrzeć kod przed uruchomieniem:

```bash
git clone https://github.com/arturkupka34/wireguard-vpn-mikrus.git
cd wireguard-vpn-mikrus
less install.sh
less src/mikrus-wg
sudo bash install.sh
```

Wartości można nadal nadpisać, np.:

```bash
sudo bash install.sh \
  --endpoint xander504.mikr.us.xyz \
  --mikrus-id 504 \
  --port 20504 \
  --client laptop-artur
```

## Model uprawnień

Domyślna polityka `acl` spełnia wymaganie „pierwsze pięć adresów może łączyć się w obie strony, pozostali nie inicjują połączeń”:

| Zakres | Rola | Zachowanie |
|---|---|---|
| `10.77.77.2`–`10.77.77.6` | `admin` | może inicjować połączenia do wszystkich peerów i odpowiadać |
| `10.77.77.7`–`10.77.77.254` | `member` | nie może inicjować ruchu do innych peerów, ale może odpowiedzieć administratorowi |
| `10.77.77.1` | serwer | niedostępny dla klientów VPN |

Reguły firewalla blokują również próbę użycia Mikrusa jako bramy do Internetu lub innych sieci.

## Dodawanie urządzeń

Pierwszych pięć automatycznie przydzielonych adresów będzie miało rolę `admin`:

```bash
sudo mikrus-wg add laptop-artur
sudo mikrus-wg add telefon-artur
sudo mikrus-wg add komputer-dom
sudo mikrus-wg add router-dom
sudo mikrus-wg add laptop-serwis
```

Szósty i kolejni klienci otrzymają rolę `member`:

```bash
sudo mikrus-wg add komputer-pracownika
```

Rolę można wskazać ręcznie:

```bash
sudo mikrus-wg add laptop-zapasowy admin
sudo mikrus-wg add router-klienta member
```

Zmiana roli:

```bash
sudo mikrus-wg set-role router-klienta admin
sudo mikrus-wg set-role laptop-zapasowy member
```

Lista klientów:

```bash
sudo mikrus-wg list
```

## Pobieranie profilu klienta

Wyświetlenie profilu:

```bash
sudo mikrus-wg show laptop-artur
```

Kod QR dla telefonu:

```bash
sudo mikrus-wg qr telefon-artur
```

Eksport do pliku na VPS:

```bash
sudo mikrus-wg export laptop-artur /root/laptop-artur.conf
```

Pobranie na własny komputer:

```bash
scp -P 10504 \
  root@xander504.mikr.us.xyz:/root/laptop-artur.conf \
  .
```

Profil zawiera prywatny klucz WireGuard. Nie dodawaj go do GitHuba i nie wysyłaj publicznym komunikatorem.

## RDP

Na komputerze docelowym z Windows:

1. włącz Pulpit zdalny;
2. zaimportuj jego osobny profil WireGuard;
3. uruchom tunel;
4. dopuść RDP z podsieci `10.77.77.0/24` w Zaporze Windows.

Pomocniczy skrypt:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\examples\windows-rdp-firewall.ps1 -VpnSubnet "10.77.77.0/24"
```

Łącz się z adresem VPN komputera, np. `10.77.77.3`. Nie wystawiaj publicznie portu 3389.

## Routery

Router może działać jako zwykły peer WireGuard i być zarządzany przez swój adres `10.77.77.x`.

Dostęp do całej sieci LAN za routerem, np. `192.168.10.0/24`, wymaga konfiguracji site-to-site. Trzeba wtedy znać:

- podsieć LAN każdego routera;
- adres IP routera w LAN;
- czy router wspiera WireGuard i routowanie bez NAT;
- czy podsieci poszczególnych lokalizacji się nie pokrywają.

Obecna wersja celowo nie dodaje tras LAN bez tych danych.

## Pozostałe polityki

Pełna komunikacja wszystkich peerów:

```bash
sudo mikrus-wg set-policy mesh
```

Tylko ping oraz RDP:

```bash
sudo mikrus-wg set-policy rdp
```

Wybrane porty dla wszystkich peerów:

```bash
sudo mikrus-wg set-policy custom tcp:3389,udp:3389,tcp:22,tcp:443,icmp
```

Powrót do polityki administratorów i członków:

```bash
sudo mikrus-wg set-policy acl
```

## Diagnostyka

```bash
sudo mikrus-wg doctor
sudo mikrus-wg status
sudo mikrus-wg list
```

Na kliencie konfiguracja powinna mieć:

```ini
AllowedIPs = 10.77.77.0/24
```

Nie powinna zawierać:

```ini
AllowedIPs = 0.0.0.0/0
```

Dzięki temu Internet nadal wychodzi przez lokalne Wi-Fi, Ethernet albo modem klienta.

## Aktualizacja i kopia zapasowa

```bash
sudo mikrus-wg backup
sudo mikrus-wg update
```

Kopia zawiera klucze prywatne. Przechowuj ją zaszyfrowaną.

## Usunięcie

```bash
sudo mikrus-wg uninstall
```

Automatycznie, bez pytania:

```bash
sudo mikrus-wg uninstall --yes
```

## Pliki projektu

```text
install.sh                         bootstrap instalacyjny
preflight.sh                       kontrola odczytowa
src/mikrus-wg                      instalator i menedżer klientów
examples/windows-rdp-firewall.ps1  reguła Zapory Windows
config/install.env.example         zestaw publicznych wartości domyślnych
tests/                             testy dymne, transakcyjne i walidacja workflow
.github/workflows/ci.yml           CI GitHub Actions
AUDIT.md                           zakres audytu i ograniczenia testów
PUBLISH_TO_GITHUB.md               bezpieczna podmiana repozytorium
SECURITY.md                        zasady bezpieczeństwa
```
