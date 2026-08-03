# Changelog

## 3.2.2

- poprawiono ostrzeżenie ShellCheck SC2155 w funkcji tworzenia kopii zapasowej: deklaracja zmiennej i przypisanie z `date` są teraz rozdzielone;
- dodano lokalną kontrolę regresji wykrywającą deklaracje `local`/`declare`/`typeset` połączone z podstawieniem polecenia;
- zaktualizowano numer wydania i ponownie przeliczono `src/mikrus-wg.sha256`.

## 3.2.1

- zapisano workflow GitHub Actions jako czytelny YAML i dodano osobną walidację jego struktury;
- przypięto `actions/checkout` do pełnego SHA wydania `v7.0.1` oraz wyłączono utrwalanie poświadczeń;
- odrzucono puste i powtórzone pozycje w regułach polityki `custom`;
- operacje modyfikujące odmawiają działania, gdy wykryją niedokończoną transakcję klienta;
- deinstalator próbuje odtworzyć forwarding, firewall i wcześniejszy stan usługi, gdy usuwanie nie powiedzie się przed skasowaniem konfiguracji;
- rozszerzono testy transakcji, wycofywania deinstalacji i walidacji workflow;
- ponownie przeliczono `src/mikrus-wg.sha256`.

## 3.2.0

- poprawiono testy walidatorów uruchamiane w podpowłokach;
- testy dymne nie zależą od bitu wykonywalności pliku `src/mikrus-wg`;
- uporządkowano workflow GitHub Actions i dodano uruchamianie ręczne;
- ShellCheck blokuje CI tylko dla ostrzeżeń i błędów, a nie uwag stylistycznych;
- dodano `.gitattributes`, aby skrypty zachowywały zakończenia linii LF po edycji w Windows.

## 3.1.0

- pełny endpoint z panelu: `xander504.mikr.us.xyz`;
- domyślne ID Mikrusa `504`;
- domyślny port WireGuard `20504/UDP`;
- instalacja bez obowiązkowych parametrów;
- kontrola wstępna bez obowiązkowych parametrów;
- szersza blokada INPUT: klient VPN nie uzyska dostępu do usług VPS przez żaden adres serwera;
- dokumentacja logowania przez SSH na porcie `10504`;
- instrukcja natychmiastowej zmiany hasła roota.

## 3.0.0

- konfiguracja repozytorium dla `arturkupka34/wireguard-vpn-mikrus`;
- domyślny endpoint `xander504.mikr.us`;
- automatyczne wyliczenie portu WireGuard jako `20000 + ID Mikrusa`;
- polityka `acl`: pierwszych pięć adresów klientów otrzymuje rolę `admin`;
- administratorzy mogą inicjować połączenia do wszystkich peerów;
- pozostali klienci mogą odpowiadać, ale nie mogą inicjować połączeń do innych peerów;
- polecenia `add NAZWA admin|member` oraz `set-role`;
- blokada dostępu klientów do usług uruchomionych na samym Mikrusie;
- zachowany split-tunnel i brak NAT/MASQUERADE.

## 2.0.0

- repozytorium gotowe do publikacji na GitHubie;
- bootstrap `install.sh` i polecenie aktualizacji;
- tryby firewalla `mesh`, `rdp` i `custom`;
- brak NAT oraz jawna blokada wyjścia z VPN do Internetu;
- diagnostyka, backup, eksport profili i QR;
- ochrona przed nadpisaniem istniejącego interfejsu WireGuard;
- CI: Bash syntax, ShellCheck i testy dymne.
