# Podmiana repozytorium na GitHubie

Najpewniejsza metoda to GitHub Desktop albo zwykły Git. Nie przesyłaj plików pojedynczo przez edytor WWW, ponieważ łatwo wtedy pominąć katalog `.github` albo uszkodzić wcięcia YAML.

## GitHub Desktop

1. Sklonuj `arturkupka34/wireguard-vpn-mikrus` przez **Code → Open with GitHub Desktop**.
2. W GitHub Desktop wybierz **Repository → Show in Explorer**.
3. Skopiuj całą zawartość tej paczki do sklonowanego katalogu, ale nie usuwaj znajdującego się tam katalogu `.git`.
4. Sprawdź, czy istnieje `.github/workflows/ci.yml`.
5. W GitHub Desktop wpisz podsumowanie `Release 3.2.2`, kliknij **Commit to main**, a następnie **Push origin**.
6. Otwórz zakładkę **Actions** i sprawdź najnowszy workflow `CI`.

## Git w terminalu

```bash
git clone https://github.com/arturkupka34/wireguard-vpn-mikrus.git
cd wireguard-vpn-mikrus
# Skopiuj tutaj zawartość paczki, nie usuwając katalogu .git.
git add -A
git status
git commit -m "Release 3.2.2"
git push origin main
```

Przed instalacją wszystkie zadania w najnowszym workflow powinny być zielone.
