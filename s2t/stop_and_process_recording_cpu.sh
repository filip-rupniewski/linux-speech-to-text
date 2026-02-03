#!/bin/bash

# --- KONFIGURACJA ---
TMP_DIR="$HOME/s2t/tmp"
WHISPER_DIR="/media/filip/roboczy/gitlab_roboczy/whisper_cpu/whisper.cpp"
MODEL="$WHISPER_DIR/models/ggml-small-q5_1.bin"
#MODEL="$WHISPER_DIR/models/ggml-base.bin"
EXECUTABLE="$WHISPER_DIR/build/bin/whisper-cli"

AUDIO_FILE="$TMP_DIR/recording.wav"
TXT_FILE="$TMP_DIR/recording.txt"
PID_FILE="$TMP_DIR/recording_pid"
# ---------------------

# Funkcja do formatowania czasu (ms -> s.ms)
format_time() {
    local ms=$1
    local sec=$((ms / 1000))
    local msec=$((ms % 1000))
    printf "%d.%03d" $sec $msec
}

# START całego skryptu
SCRIPT_START=$(date +%s%3N)
echo "=== START SKRYPTU ==="

# 1. Zatrzymaj nagrywanie
STEP_START=$(date +%s%3N)
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi
sleep 0.5
STEP_END=$(date +%s%3N)
STOP_TIME=$((STEP_END - STEP_START))

# Sprawdź długość nagrania (jeśli ffprobe dostępny)
if command -v ffprobe &> /dev/null; then
    DURATION_SEC=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null | cut -d. -f1)
    echo "Długość nagrania: ${DURATION_SEC}s"
fi

# 2. Sprawdź czy plik audio istnieje
if [ ! -f "$AUDIO_FILE" ]; then
    notify-send "Błąd" "Brak pliku audio!"
    exit 1
fi

# 3. Transkrypcja 
echo "Rozpoczynam transkrypcję..."
WHISPER_START=$(date +%s%3N)

"$EXECUTABLE" \
  -m "$MODEL" \
  -f "$AUDIO_FILE" \
  -l pl \
  -nt \ #  -t $(nproc) \
  -t 6 \
  -bs 1 \
  > "$TXT_FILE" 2>/dev/null

WHISPER_END=$(date +%s%3N)
WHISPER_TIME=$((WHISPER_END - WHISPER_START))

# Sprawdź czy wynik nie jest pusty
if [ ! -s "$TXT_FILE" ]; then
    notify-send "Błąd" "Transkrypcja nie powiodła się."
    exit 1
fi

# 4. Kopiowanie do schowka i wklejanie
CLIPBOARD_START=$(date +%s%3N)

xclip -selection clipboard -r < "$TXT_FILE"

SCRIPT_END=$(date +%s%3N)
TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

# Symulacja wklejenia (nie liczymy tego do całkowitego czasu, bo to opcjonalne)
sleep 0.2
xdotool key ctrl+v

CLIPBOARD_END=$(date +%s%3N)
CLIPBOARD_TIME=$((CLIPBOARD_END - CLIPBOARD_START))

# --- PODSUMOWANIE CZASÓW ---
echo ""
echo "=== PODSUMOWANIE CZASÓW ==="
printf "%-30s %10s\n" "Operacja:" "Czas:"
printf "%-30s %10s\n" "------------------------------" "----------"
printf "%-30s %10ss\n" "1. Zatrzymanie nagrywania:" "$(format_time $STOP_TIME)"
printf "%-30s %10ss\n" "2. Transkrypcja (whisper):" "$(format_time $WHISPER_TIME)"
printf "%-30s %10ss\n" "3. Clipboard + xdotool:" "$(format_time $CLIPBOARD_TIME)"
printf "%-30s %10ss\n" "------------------------------" "----------"
printf "%-30s %10ss\n" "CAŁKOWITY CZAS SKRYPTU:" "$(format_time $TOTAL_TIME)"

# Oblicz realtime factor (RTF) - im mniejszy tym lepiej
if [ -n "$DURATION_SEC" ] && [ "$DURATION_SEC" -gt 0 ]; then
    RTF=$(echo "scale=2; $WHISPER_TIME / ($DURATION_SEC * 1000)" | bc -l 2>/dev/null || echo "N/A")
    if [ "$RTF" != "N/A" ]; then
        echo ""
        echo "Realtime Factor (RTF): $RTF"
        echo "Interpretacja: 1.0 = transkrypcja w czasie rzeczywistym"
        echo "               0.5 = 2x szybciej niż nagranie"
        echo "               2.0 = 2x wolniej niż nagranie"
    fi
fi
echo "==========================="
echo ""

# Powiadomienie systemowe
notify-send "Gotowe" "Transkrypcja: $(format_time $WHISPER_TIME)s | Całkowity: $(format_time $TOTAL_TIME)s"

# 5. Czyszczenie
#rm -rf "$TMP_DIR"
