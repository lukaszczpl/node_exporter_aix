# Debugowanie z GDB na AIX - node_exporter_aix

## Szybki Start

### 1. Kompilacja z symbolami debug

```bash
# Sposób 1: Użyj target debug (zalecane)
make debug

# Sposób 2: Manualnie ustaw DEBUG=1
make DEBUG=1

# Sprawdź czy symbole są obecne
file build/node_exporter_aix
# Powinno pokazać: "... not stripped" lub "with debug_info"
```

### 2. Uruchomienie w GDB

```bash
# Podstawowe uruchomienie
gdb build/node_exporter_aix

# Lub z argumentami
gdb --args build/node_exporter_aix --port 9100
```

---

## Flagi Debugowania w Makefile

### DEBUG=1 włącza:

**CXXFLAGS dla C++:**
```makefile
-g          # Dodaje symbole debugowania
-O0         # Wyłącza optymalizację (kod zgodny z kodem źródłowym)
-Wall       # Wszystkie ostrzeżenia (bez -Werror w trybie debug)
```

**CFLAGS dla C (civetweb):**
```makefile
-g -O0      # Symbole debug + brak optymalizacji
```

**LDFLAGS:**
```makefile
-pthread -lperfstat  # Linkowanie dynamiczne (łatwiejsze do debugowania)
# Statyczne linkowanie wyłączone w trybie debug
```

---

## Podstawowe Komendy GDB

### Uruchamianie programu

```gdb
(gdb) run                          # Uruchom program
(gdb) run --port 9100             # Uruchom z argumentami
(gdb) start                        # Uruchom i zatrzymaj w main()
```

### Breakpointy

```gdb
(gdb) break main                   # Breakpoint w funkcji main
(gdb) break server.cpp:20          # Breakpoint na linii 20 w server.cpp
(gdb) break request_handler        # Breakpoint w funkcji
(gdb) info breakpoints            # Lista breakpointów
(gdb) delete 1                    # Usuń breakpoint #1
(gdb) clear server.cpp:20         # Usuń breakpoint na linii
```

### Poruszanie się po kodzie

```gdb
(gdb) next          # Wykonaj następną linię (nie wchodź w funkcje)
(gdb) step          # Wykonaj następną linię (wejdź w funkcje)
(gdb) finish        # Dokończ obecną funkcję
(gdb) continue      # Kontynuuj wykonywanie
(gdb) until 50      # Wykonuj do linii 50
```

### Przeglądanie kodu

```gdb
(gdb) list                      # Pokaż kod wokół obecnej pozycji
(gdb) list main                 # Pokaż kod funkcji main
(gdb) list server.cpp:20        # Pokaż kod z linii 20
(gdb) backtrace                 # Pokaż stos wywołań
(gdb) frame 2                   # Przejdź do ramki #2 na stosie
```

### Zmienne i wyrażenia

```gdb
(gdb) print port                # Wyświetl wartość zmiennej
(gdb) print flags & PART_CPU    # Wyświetl wartość wyrażenia
(gdb) print/x flags             # Wyświetl w hex
(gdb) display port              # Wyświetlaj automatycznie przy każdym stop
(gdb) info locals               # Wszystkie zmienne lokalne
(gdb) info args                 # Argumenty funkcji
(gdb) set var port = 8080       # Zmień wartość zmiennej
```

### Wątki (pthread)

```gdb
(gdb) info threads              # Lista wątków
(gdb) thread 3                  # Przełącz na wątek #3
(gdb) thread apply all bt       # Backtrace wszystkich wątków
```

---

## Debugowanie Typowych Problemów

### 1. Crash/Segfault

```gdb
# Uruchom program
(gdb) run

# Program crashuje - GDB automatycznie zatrzyma się
# Sprawdź co się stało:
(gdb) backtrace
(gdb) info registers
(gdb) print *pointer   # Sprawdź wartość pointera który spowodował crash
```

### 2. Program się zawiesza

```bash
# W jednym terminalu uruchom program
./build/node_exporter_aix --port 9100

# W drugim terminalu znajdź PID
ps -ef | grep node_exporter

# Podłącz GDB do uruchomionego procesu
gdb -p <PID> build/node_exporter_aix

# W GDB:
(gdb) info threads              # Sprawdź wątki
(gdb) thread apply all bt       # Gdzie siedzą wątki?
(gdb) thread 2                  # Przełącz na wątek który się zawiesił
(gdb) backtrace
```

### 3. Memory leak - sprawdzanie wskaźników

```gdb
(gdb) break gather_cpus
(gdb) run
(gdb) next
# ... po wykonaniu funkcji
(gdb) print ctx
(gdb) print *ctx
(gdb) watch ctx  # Zatrzymaj gdy ctx się zmieni
```

### 4. Nieprawidłowe wartości

```gdb
# Ustaw watchpoint na zmiennej
(gdb) watch keep_running
# Program zatrzyma się gdy keep_running się zmieni

# Breakpoint warunkowy
(gdb) break server.cpp:90 if port == 9100
# Zatrzyma się tylko gdy port == 9100
```

---

## AIX-Specyficzne Porady

### 1. Symbol debugging na AIX

AIX używa XCOFF format zamiast ELF. Niektóre dystrybucje GDB mogą mieć problemy:

```bash
# Sprawdź wersję GDB
gdb --version
# Zalecana: GDB 8.x lub nowsza

# Jeśli brak GDB:
yum install gdb
```

### 2. Core dumps

Włącz core dumps dla post-mortem debugging:

```bash
# Włącz unlimited core dumps
ulimit -c unlimited

# Uruchom program - jeśli crashnie, zostanie utworzony core dump
./build/node_exporter_aix

# Debuguj core dump
gdb build/node_exporter_aix core
(gdb) backtrace
```

### 3. Debugowanie z dbx (natywny debugger AIX)

Jeśli GDB sprawia problemy, użyj dbx:

```bash
dbx build/node_exporter_aix

# Podstawowe komendy (podobne do GDB):
(dbx) stop in main
(dbx) run
(dbx) next
(dbx) print port
(dbx) where        # backtrace
```

---

## Przykładowa Sesja Debug

```bash
# 1. Kompilacja debug build
make debug

# 2. Uruchom GDB
gdb build/node_exporter_aix

# 3. W GDB - ustaw breakpointy
(gdb) break start_server
(gdb) break request_handler

# 4. Uruchom z argumentami
(gdb) run --port 9100

# 5. Program zatrzyma się w start_server
(gdb) print port
$1 = 9100

(gdb) list
# ... kod wokół obecnej pozycji

# 6. Ustaw breakpoint warunkowy
(gdb) break server.cpp:67 if flags & PART_CPU

# 7. Kontynuuj
(gdb) continue

# 8. W drugim terminalu - wywołaj endpoint
curl http://localhost:9100/

# 9. GDB zatrzyma się w request_handler
(gdb) print flags
(gdb) backtrace

# 10. Wejdź w gather_cpus
(gdb) step

# 11. Sprawdź zmienne lokalne
(gdb) info locals

# 12. Dokończ i wyjdź
(gdb) continue
(gdb) quit
```

---

## Porównanie: Production vs Debug Build

| Aspekt | Production (`make`) | Debug (`make debug`) |
|--------|---------------------|----------------------|
| **Optymalizacja** | Włączona (domyślnie -O2) | Wyłączona (-O0) |
| **Symbole debug** | Brak | Pełne (-g) |
| **Linkowanie** | Statyczne (libstdc++, libgcc) | Dynamiczne |
| **Warnings** | -Werror (błąd na warning) | -Wall (tylko ostrzeżenie) |
| **Rozmiar binary** | Mniejszy (~2-3MB) | Większy (~5-8MB) |
| **Deployment** | ✅ Gotowe do produkcji | ❌ Tylko do testów |
| **Debugowanie** | Trudne (optymalizacje) | ✅ Łatwe |
| **Performance** | ✅ Szybki | Wolniejszy |

---

## Dodatkowe Narzędzia

### 1. Valgrind (jeśli dostępne na AIX)

```bash
# Memory leak detection
valgrind --leak-check=full ./build/node_exporter_aix
```

### 2. strace/truss (system call tracing)

```bash
# AIX używa truss zamiast strace
truss -f ./build/node_exporter_aix

# Tylko system calls związane z plikami
truss -t open,read,write,close ./build/node_exporter_aix
```

### 3. procstack (AIX stack trace)

```bash
# Sprawdź stack wszystkich wątków bez zatrzymywania procesu
procstack <PID>
```

---

## Troubleshooting GDB

### Problem: "No debugging symbols found"

```bash
# Sprawdź czy build był z -g
make clean
make DEBUG=1
file build/node_exporter_aix | grep debug
```

### Problem: GDB nie może znaleźć source files

```gdb
(gdb) directory /path/to/source
(gdb) set substitute-path /old/path /new/path
```

### Problem: Optimized out variables

Użyj `-O0` (już włączone w DEBUG=1):
```gdb
(gdb) print myvar
$1 = <optimized out>  # ← To oznacza że trzeba -O0
```

---

## Podsumowanie

**Dla debugowania:**
```bash
make debug          # Kompilacja z symbolami
gdb build/node_exporter_aix
```

**Dla produkcji:**
```bash
make clean && make  # Optymalizowany, statyczny build
```

**Quick reference:**
- `break` - ustaw breakpoint
- `run` - uruchom program
- `next` - następna linia
- `print` - wyświetl wartość
- `backtrace` - stos wywołań
- `quit` - wyjście z GDB
