# AIX Kompilacja - Rozwiązywanie problemów

## Problem 1: `cc: A file or directory in the path name does not exist`

### Przyczyna
Make ma wbudowaną domyślną zmienną `CC = cc`. Gdy użyjesz `CC ?= gcc`, operator `?=` (conditional assignment) nie nadpisuje już istniejącej wartości `cc`.

### Rozwiązanie
W Makefile ustawiono `CC = gcc` (zamiast `CC ?= gcc`):

```makefile
# Wymuszenie gcc (nadpisanie domyślnego 'cc' w Make)
CXX = g++
CC = gcc
```

**Wyjaśnienie operatorów Make:**
- `CC ?= gcc` - ustaw CC na gcc **tylko jeśli** CC nie jest już ustawione (nie działa, bo Make ma `CC = cc`)
- `CC = gcc` - **wymuś** CC na gcc, nadpisując domyślną wartość

Nadal można nadpisać podczas kompilacji:
```bash
make CC=/opt/freeware/bin/gcc
```

---

## Problem 2: `Undefined symbol: .timegm`

### Przyczyna
Funkcja `timegm()` używana w `civetweb/src/civetweb.c` jest rozszerzeniem GNU/Linux i **nie istnieje** w standardowej bibliotece AIX.

### Błąd kompilacji
```
civetweb/src/civetweb.c:8369:34: warning: implicit declaration of function 'timegm'
ld: 0711-317 ERROR: Undefined symbol: .timegm
```

### Rozwiązanie
AIX dostarcza kompatybilność z funkcjami GNU/Linux przez flagi `-D_LINUX_SOURCE_COMPAT` i `-DNEED_TIMEGM`.

**W Makefile dodano:**
```makefile
# C compilation flags for civetweb (AIX compatibility)
CFLAGS = -D_LINUX_SOURCE_COMPAT -DNEED_TIMEGM
```

**I zaktualizowano kompilację civetweb:**
```makefile
build/civetweb.o: civetweb/src/civetweb.c
	$(CC) $(CFLAGS) -I civetweb/include -DNO_SSL -DNO_FILES -c -o build/civetweb.o civetweb/src/civetweb.c
```

### Co robią te flagi?
- **`-D_LINUX_SOURCE_COMPAT`**: Włącza kompatybilność z funkcjami GNU/Linux w AIX
- **`-DNEED_TIMEGM`**: Jawnie włącza funkcję `timegm()` w niektórych wersjach biblioteki AIX

Te flagi włączają w AIX:
- Kompatybilność z funkcjami GNU/Linux
- Dostęp do funkcji jak `timegm()`, `strptime()` z GNU semantyką
- Dodatkowe POSIX rozszerzenia

---

## Kompilacja

### Krok 1: Setup środowiska
```bash
export PATH=/opt/freeware/bin:$PATH
```

### Krok 2: Budowanie
```bash
make clean
make
```

### Krok 3: Weryfikacja
```bash
ls -lh build/node_exporter_aix
# Powinno pokazać >2MB binarny plik

ldd build/node_exporter_aix
# Powinno pokazać tylko systemowe biblioteki AIX
```

---

## Częste problemy

### Problem: `g++: command not found`
```bash
# Zainstaluj g++
yum install gcc-c++-9*

# Lub wskaż ścieżkę
make CXX=/opt/freeware/bin/g++
```

### Problem: `ksh: command not found`
Skrypty generujące wymagają ksh:
```bash
yum install ksh
```

### Problem: Nadal `timegm undefined`
Upewnij się że CFLAGS zawiera obie flagi:
```bash
# W Makefile sprawdź linijkę:
grep "CFLAGS" Makefile | grep -v "^#"
# Powinno pokazać: CFLAGS = -D_LINUX_SOURCE_COMPAT -DNEED_TIMEGM
```

---

## Flagi kompilacji - Podsumowanie

### Dla C++ (CXXFLAGS)
```makefile
CXXFLAGS = -Wall -Werror -fmax-errors=5 -fconcepts -std=c++17 -pthread
```

### Dla C (CFLAGS) - CivetWeb
```makefile
CFLAGS = -D_LINUX_SOURCE_COMPAT -DNEED_TIMEGM
```

### Linkowanie (LDFLAGS)
```makefile
LDFLAGS = -pthread -static-libgcc -static-libstdc++ -lperfstat
```

---

## Dodatkowe informacje

### Alternatywna implementacja timegm (nie używana)
Gdyby `-D_LINUX_SOURCE_COMPAT` nie działała, można by zastąpić `timegm()` manualnie:

```c
// W civetweb.c przed użyciem timegm
#ifdef _AIX
#ifndef timegm
static time_t timegm(struct tm *tm) {
    time_t ret;
    char *tz;
    tz = getenv("TZ");
    setenv("TZ", "UTC", 1);
    tzset();
    ret = mktime(tm);
    if (tz)
        setenv("TZ", tz, 1);
    else
        unsetenv("TZ");
    tzset();
    return ret;
}
#endif
#endif
```

Ale **nie jest to konieczne** gdy używamy `-D_LINUX_SOURCE_COMPAT`.
