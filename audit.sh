#!/bin/bash

# Katalog na raporty
REPORT_DIR="reports"

# Pobranie danych
HOST=$(hostname)
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
START_TIME=$(date +%s)

# Pełna ścieżka raportu
REPORT_FILE="$REPORT_DIR/${HOST}_${DATE}.txt"

#Pelna sciezka logu
LOG_FILE="$REPORT_DIR/audit.log"

#Licznik ostrzezen
WARN_COUNT=0

# Utworzenie katalogu raportów, jeśli nie istnieje
mkdir -p "$REPORT_DIR"

#Funkcja tworzaca sekje

print_section() {
echo
echo "========= $1 ========="
}

log_message() {

    local level="$1"
    local message="$2"

    echo "$(date '+%Y-%m-%dT%H:%M:%S%z') [$level] $message" >> "$LOG_FILE"

}

check_file() {

    local file="$1"

    if [ -r "$file" ]; then
        echo "$file : OK" >> "$REPORT_FILE"
    else
        echo "$file : BRAK DOSTEPU" >> "$REPORT_FILE"
    fi

}

#Start audytu
log_message INFO "Rozpoczęcie audytu systemu"


# Nagłówek raportu
print_section "RAPORT AUDYTU SYSTEMU LINUX" >> "$REPORT_FILE"

print_section "INFORMACJE O SYSTEMIE" >> "$REPORT_FILE"

echo "Hostname: $(hostname)" >> "$REPORT_FILE"
echo "System: $(grep PRETTY_NAME /etc/os-release)" >> "$REPORT_FILE"
echo "Kernel: $(uname -r)" >> "$REPORT_FILE"
echo "Uptime: $(uptime -p)" >> "$REPORT_FILE"
echo "Data wykonania: $(date)" >> "$REPORT_FILE"
echo "Użytkownik: $(whoami)" >> "$REPORT_FILE"

print_section "PAMIEC OPERACYJNA" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE"

print_section "WYKORZYSTANIE DYSKU" >> "$REPORT_FILE"
df -h >> "$REPORT_FILE"

print_section "AKTYWNE SESJE" >> "$REPORT_FILE"
who  >> "$REPORT_FILE"

print_section "OSTATNIE LOGOWANIA" >> "$REPORT_FILE"
last -n 10 >> "$REPORT_FILE"

print_section "KONTROLA WAZNYCH PLIKOW" >> "$REPORT_FILE"

check_file "/etc/passwd"
check_file "/etc/group"
check_file "/etc/shadow"
check_file "/etc/ssh/sshd_config"

print_section "KONTA Z UID 0" >> "$REPORT_FILE"
if [ -r /etc/passwd ]; then

    uid0_accounts=$(awk -F: '$3 == 0 { print $1 }' /etc/passwd)

    if [ -n "$uid0_accounts" ]; then
        echo "$uid0_accounts" >> "$REPORT_FILE"
    else
        echo "Nie znaleziono kont z UID 0." >> "$REPORT_FILE"
    fi

else
    echo "BŁĄD: Nie można odczytać pliku /etc/passwd" >> "$REPORT_FILE"
	log_message ERROR "Nie można odczytać pliku /etc/passwd"
fi

print_section "KONTROLA SSH ROOT LOGIN" >> "$REPORT_FILE"

SSHD_CONFIG="/etc/ssh/sshd_config"

#Sprawdzenie czy plik jest czytelny
if [ ! -r "$SSHD_CONFIG" ]; then
    echo "WARN: Nie można odczytać $SSHD_CONFIG" >> "$REPORT_FILE"
	log_message WARN "Brak dostępu do $SSHD_CONFIG"
	((WARN_COUNT++))

elif grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+yes[[:space:]]*$' "$SSHD_CONFIG"; then
    echo "WARN: Wykryto aktywne ustawienie PermitRootLogin yes" >> "$REPORT_FILE"

else
    echo "OK: Nie wykryto aktywnego PermitRootLogin yes" >> "$REPORT_FILE"
fi

echo >> "$REPORT_FILE"
echo "UWAGA: Kontrola obejmuje wyłącznie plik $SSHD_CONFIG." >> "$REPORT_FILE"
echo "Nie potwierdza pełnej efektywnej konfiguracji SSH." >> "$REPORT_FILE"
echo "Dodatkowe pliki Include mogą zmieniać końcowe ustawienia usługi." >> "$REPORT_FILE"

print_section "OTWARTE PORTY" >> "$REPORT_FILE"

if command -v ss >/dev/null 2>&1; then
    ss -tuln >> "$REPORT_FILE"
else
    echo "INFO: Narzedzie ss nie jest dostepne." >> "$REPORT_FILE"
fi

print_section "ZADANIA CRON UZYTKOWNIKOW" >> "$REPORT_FILE"

PASSWD_FILE="/etc/passwd"

if [ ! -r "$PASSWD_FILE" ]; then
    echo "ERROR: Nie mozna odczytac $PASSWD_FILE" >> "$REPORT_FILE"
	log_message ERROR "Nie można odczytać $PASSWD_FILE"
else

    while IFS=: read -r username password uid gid gecos home shell
    do

        echo "" >> "$REPORT_FILE"
        echo "--- Uzytkownik: $username ---" >> "$REPORT_FILE"

        cron_output=$(crontab -u "$username" -l 2>&1)
        cron_status=$?

        if [ $cron_status -eq 0 ]; then
            if [ -n "$cron_output" ]; then
                echo "$cron_output" >> "$REPORT_FILE"

            else
                echo "INFO: Crontab istnieje, ale jest pusty." >> "$REPORT_FILE"

            fi
        else

            if echo "$cron_output" | grep -qi "no crontab"; then
                echo "INFO: Brak crontaba dla tego uzytkownika." >> "$REPORT_FILE"

            elif echo "$cron_output" | grep -qi "not allowed"; then
                echo "WARN: Brak uprawnien do odczytu crontaba." >> "$REPORT_FILE"
		log_message WARN "Brak uprawnien do odczytu crontaba użytkownika $username"
		((WARN_COUNT++))

            elif echo "$cron_output" | grep -qi "permission"; then
                echo "WARN: Brak uprawnien do odczytu crontaba." >> "$REPORT_FILE"


            else
                echo "WARN: Nie mozna zweryfikowac crontaba." >> "$REPORT_FILE"

                echo "Szczegoly: $cron_output" >> "$REPORT_FILE"

            fi

        fi

    done < "$PASSWD_FILE"

fi

# Skanujemy najczesciej wykorzystywane katalogi z programami.
# Jest to kompromis pomiedzy czasem wykonania a wartoscia wyniku.

print_section "PLIKI SUID" >> "$REPORT_FILE"

SUID_PATHS="/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin"

echo "Przeszukiwane lokalizacje:" >> "$REPORT_FILE"
echo "$SUID_PATHS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

find $SUID_PATHS -type f -perm -4000 > /tmp/audit_suid_results.txt 2> /tmp/audit_suid_errors.txt

if [ -s /tmp/audit_suid_results.txt ]; then

    echo "Wykryte pliki SUID:" >> "$REPORT_FILE"
    cat /tmp/audit_suid_results.txt >> "$REPORT_FILE"

else

    echo "INFO: Nie znaleziono plikow SUID w analizowanym zakresie." >> "$REPORT_FILE"

fi

if [ -s /tmp/audit_suid_errors.txt ]; then

    echo "" >> "$REPORT_FILE"
    echo "WARN: Skanowanie bylo niepelne." >> "$REPORT_FILE"
    echo "Wystapily bledy dostepu:" >> "$REPORT_FILE"
	log_message WARN "Skanowanie SUID zakończone z błędami dostępu"
	((WARN_COUNT++))

    cat /tmp/audit_suid_errors.txt >> "$REPORT_FILE"

fi

echo "" >> "$REPORT_FILE"
echo "UWAGA: Obecnosc pliku SUID nie oznacza automatycznie zagrozenia." >> "$REPORT_FILE"
echo "Nietypowe lokalizacje wymagaja dodatkowej weryfikacji." >> "$REPORT_FILE"

rm -f /tmp/audit_suid_results.txt
rm -f /tmp/audit_suid_errors.txt

print_section "PAKIETY MOZLIWE DO AKTUALIZACJI" >> "$REPORT_FILE"

if command -v apt >/dev/null 2>&1; then

    upgrades=$(apt list --upgradable 2>/dev/null)

    update_count=$(echo "$upgrades" | tail -n +2 | wc -l)

    echo "Liczba pakietow mozliwych do aktualizacji: $update_count" >> "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
    echo "Pakiety:" >> "$REPORT_FILE"

    echo "$upgrades" | tail -n +2 >> "$REPORT_FILE"

else

    echo "INFO: Menedzer pakietow apt nie jest dostepny." >> "$REPORT_FILE"

fi

echo "" >> "$REPORT_FILE"
echo "UWAGA: Skrypt nie odswieza list repozytoriow i nie instaluje aktualizacji." >> "$REPORT_FILE"
echo "Wynik zalezy od aktualnosci lokalnych danych systemu." >> "$REPORT_FILE"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

print_section "CZAS WYKONANIA AUDYTU" >> "$REPORT_FILE"
echo "Czas wykonania: $DURATION sekund" >> "$REPORT_FILE"

print_section "PODSUMOWANIE" >> "$REPORT_FILE"

echo "Liczba ostrzezen: $WARN_COUNT" >> "$REPORT_FILE"
echo "Raport: $REPORT_FILE" >> "$REPORT_FILE"

# Informacja dla użytkownika
echo
echo "Raport został zapisany w pliku:"
echo "$REPORT_FILE"
log_message INFO "Audyt zakończony. Raport zapisany w $REPORT_FILE"

