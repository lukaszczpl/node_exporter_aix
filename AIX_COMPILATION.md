# AIX Kompilacja - Rozwiązywanie problemów

## Problem 1: `cc: A file or directory in the path name does not exist`

### Przyczyna
Zmienna `CC` nie jest poprawnie ustawiona lub `cc` nie jest w PATH.

### Rozwiązanie
W Makefile ustawiono `CC ?= gcc`:

```makefile
CC ?= gcc
```

Można też nadpisać podczas kompilacji:
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
AIX dostarcza kompatybilność z funkcjami GNU/Linux przez flagę `-D_LINUX_SOURCE_COMPAT`.

**W Makefile dodano:**
```makefile
# C compilation flags for civetweb (AIX compatibility)
CFLAGS = -D_LINUX_SOURCE_COMPAT
```

**I zaktualizowano kompilację civetweb:**
```makefile
build/civetweb.o: civetweb/src/civetweb.c
	$(CC) $(CFLAGS) -I civetweb/include -DNO_SSL -DNO_FILES -c -o build/civetweb.o civetweb/src/civetweb.c
```

### Co robi `-D_LINUX_SOURCE_COMPAT`?
Ta flaga włącza w AIX:
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
Upewnij się że CFLAGS zawiera `-D_LINUX_SOURCE_COMPAT`:
```bash
# W Makefile sprawdź linijkę:
grep "_LINUX_SOURCE_COMPAT" Makefile
# Powinno pokazać: CFLAGS = -D_LINUX_SOURCE_COMPAT
```

---

## Flagi kompilacji - Podsumowanie

### Dla C++ (CXXFLAGS)
```makefile
CXXFLAGS = -Wall -Werror -fmax-errors=5 -fconcepts -std=c++17 -pthread
```

### Dla C (CFLAGS) - CivetWeb
```makefile
CFLAGS = -D_LINUX_SOURCE_COMPAT
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
