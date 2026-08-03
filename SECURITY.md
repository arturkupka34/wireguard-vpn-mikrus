# Security policy

## Zgłaszanie problemów

Nie publikuj podatności, profili klientów ani kluczy prywatnych w publicznym issue. Skontaktuj się prywatnie z właścicielem repozytorium.

## Dane logowania

- Hasła SSH, klucze prywatne WireGuard i profile klientów nigdy nie należą do repozytorium.
- Po pierwszym logowaniu na świeży system natychmiast ustaw nowe hasło poleceniem `passwd`.
- Instalator nie odczytuje, nie zapisuje ani nie wymaga hasła SSH.
- Po skonfigurowaniu klucza SSH można rozważyć wyłączenie logowania hasłem, ale dopiero po sprawdzeniu dostępu w drugiej sesji.

## Założenia bezpieczeństwa

- Skrypt jest uruchamiany jako `root`.
- Klucze powstają lokalnie na Mikrusie i są zapisywane z uprawnieniami `0600`.
- Repozytorium nie może zawierać plików `.conf`, `.key`, `.psk` ani kopii `/etc/mikrus-wg`.
- Instalacja przez `curl | bash` ufa wskazanej gałęzi. Dla zastosowania produkcyjnego użyj tagu wydania albo sklonuj i przejrzyj kod.
- Projekt nie konfiguruje NAT/MASQUERADE.
- Firewall blokuje dostęp klientów VPN do usług samego VPS oraz wyjście z WireGuard do zwykłej karty sieciowej serwera.
- W polityce `acl` peer z rolą `member` może odpowiadać na połączenia administratora, lecz nie może inicjować ruchu do innych peerów.
