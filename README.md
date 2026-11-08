Audit.sh – Pasywny audyt bezpieczeństwa systemu Linux
Opis projektu
audit.sh jest pasywnym skryptem audytowym napisanym w Bashu.

Jego zadaniem jest zebranie podstawowych informacji związanych z bezpieczeństwem systemu Linux oraz zapisanie ich do czytelnego raportu tekstowego.

Skrypt nie modyfikuje konfiguracji systemu, nie restartuje usług, nie instaluje pakietów i nie wykonuje działań administracyjnych wpływających na działanie systemu.

Projekt został przygotowany w ramach Laboratorium 12 poświęconego podstawom audytu bezpieczeństwa systemów Linux.

Cele projektu
Skrypt umożliwia:

identyfikację środowiska systemowego,
zapisanie informacji o hoście i systemie operacyjnym,
przegląd aktywnych sesji użytkowników,
analizę historii logowań,
wykrywanie kont posiadających UID 0,
podstawową kontrolę konfiguracji SSH,
przegląd zadań cron użytkowników,
wyszukiwanie plików z ustawionym bitem SUID,
określenie liczby dostępnych aktualizacji pakietów,
prowadzenie technicznego logu działania skryptu.
Wymagania
System operacyjny
Kali Linux
Ubuntu Linux
Oprogramowanie
Wykorzystywane są wyłącznie standardowe narzędzia systemowe:

bash
hostname
uname
uptime
who
last
grep
find
awk
crontab
apt (opcjonalnie)
Dodatkowo:

ShellCheck (opcjonalnie)
Lynis (opcjonalnie)
Struktura katalogów
work/
├── audit.sh
├── audit-script-checklist.md
├── report-review.md
└── reports/
    ├── audit.log
    ├── audit-host1-20260923-183001.txt
    └── audit-host1-20260923-183745.txt
Funkcjonalności
1. Informacje podstawowe
Raport zawiera:

nazwę hosta,
użytkownika uruchamiającego skrypt,
wersję systemu,
wersję jądra,
czas działania systemu,
datę wykonania audytu.
2. Aktywne sesje
Wyświetlana jest lista aktualnie zalogowanych użytkowników.

Źródło danych:

who
3. Historia logowań
Pokazywane jest 10 ostatnich wpisów historii logowań.

Źródło danych:

last
4. Konta UID 0
Skrypt analizuje:

/etc/passwd
i wyświetla wszystkie konta posiadające UID równy 0.

Takie konta posiadają uprawnienia administracyjne.

5. Kontrola SSH
Analizowany jest plik:

/etc/ssh/sshd_config
Sprawdzana jest obecność aktywnej dyrektywy:

PermitRootLogin yes
Możliwe wyniki
OK
Nie wykryto aktywnej dyrektywy.

WARN
Wykryto aktywne ustawienie.

Ograniczenia
Kontrola dotyczy jedynie głównego pliku konfiguracyjnego SSH i nie uwzględnia wszystkich możliwych plików Include.

6. Zadania cron
Dla każdego użytkownika z pliku:

/etc/passwd
skrypt próbuje odczytać jego crontab.

Rozróżniane są trzy sytuacje:

użytkownik posiada zadania cron,
użytkownik nie posiada crontaba,
brak możliwości odczytu.
7. Pliki SUID
Skrypt wyszukuje pliki posiadające ustawiony bit SUID.

Analizowane katalogi:

/bin
/sbin
/usr/bin
/usr/sbin
/usr/local/bin
/usr/local/sbin
UWAGA
Obecność pliku SUID nie oznacza automatycznie kompromitacji systemu.

8. Dostępne aktualizacje
Jeżeli dostępny jest menedżer pakietów APT:

apt list --upgradable
skrypt:

pobiera listę możliwych aktualizacji,
liczy pakiety,
zapisuje wynik do raportu.
Ograniczenia
Skrypt:

nie uruchamia apt update,
nie instaluje aktualizacji,
korzysta wyłącznie z lokalnych informacji systemu.
9. Log techniczny
Tworzony jest oddzielny plik:

reports/audit.log
Rejestrowane są zdarzenia:

INFO
WARN
ERROR
Przykład:

2026-09-23T18:10:01+0200 [INFO] Rozpoczęto audyt
2026-09-23T18:10:02+0200 [WARN] Nie można odczytać sshd_config
2026-09-23T18:10:05+0200 [INFO] Audyt zakończony
Uruchomienie
Nadanie uprawnień wykonywania:

chmod +x audit.sh
Uruchomienie:

./audit.sh
Zalecenia bezpieczeństwa
Skrypt powinien być uruchamiany jako zwykły użytkownik.

Nie należy uruchamiać go z podwyższonymi uprawnieniami bez wcześniejszego przeanalizowania jego działania.

Skrypt został zaprojektowany jako:

Read Only
to znaczy:

nie zmienia konfiguracji systemu,
nie usuwa plików,
nie restartuje usług,
nie instaluje oprogramowania.
Ograniczenia
Wynik audytu nie stanowi pełnej oceny bezpieczeństwa systemu.

Przykładowo:

analiza jednego pliku SSH nie oznacza pełnej analizy konfiguracji SSH,
brak dostępu do danych nie oznacza braku problemu,
brak wykrytego zagrożenia nie oznacza pełnego bezpieczeństwa systemu,
część kontroli może być ograniczona przez uprawnienia użytkownika.
Interpretacja wyników
Podczas analizy raportu należy rozróżniać:

OK
Kontrola została wykonana i nie wykryto badanego problemu.

WARN
Kontrola wskazuje potencjalny problem lub ograniczenie.

ERROR
Kontrola nie mogła zostać poprawnie wykonana.

