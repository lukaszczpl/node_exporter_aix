# Statyczne Linkowanie - node_exporter_aix

## Czym jest statyczne linkowanie?

**Statyczne linkowanie** = kod bibliotek jest wbudowany bezpośrednio w wykonywalny plik binarny.
**Dynamiczne linkowanie** = program wymaga zainstalowanych bibliotek współdzielonych (.so/.a) podczas uruchamiania.

## Konfiguracja w projekcie

### ✅ Domyślnie: Build Statyczny (zalecane)

```makefile
LDFLAGS = -pthread -static-libgcc -static-libstdc++ -lperfstat
```

**Co jest linkowane statycznie:**
- `libstdc++` - Biblioteka standardowa C++ (wszystkie nagłówki jak `<chrono>`, `<thread>`, `<iostream>`)
- `libgcc` - Biblioteka wsparcia kompilatora GCC
- Wszystkie symbole C++ używane w kodzie

**Co pozostaje dynamiczne:**
- `libperfstat` - Biblioteka systemowa AIX (musi być dynamiczna)
- `libc` - Bazowa biblioteka C systemu AIX
- `libpthread` - Wątki POSIX (część systemu)

### Zalety Statycznego Linkowania

#### 1. **Zero zależności od GCC/G++** ✨
```bash
# Na systemie docelowym NIE musisz instalować:
# - gcc-c++
# - libstdc++
# - libgcc

# Wystarczy tylko:
ldd build/node_exporter_aix
# Pokaże tylko systemowe biblioteki AIX
```

#### 2. **Jeden plik = pełna dystrybucja**
```bash
# Kompilacja (raz na systemie developerskim z g++ 9.x)
make clean && make

# Dystrybucja (na dowolny AIX 7.x)
scp build/node_exporter_aix target-system:/usr/local/bin/
ssh target-system '/usr/local/bin/node_exporter_aix'
# DZIAŁA! Bez dodatkowej instalacji.
```

#### 3. **Kompatybilność wsteczna i wzdłużna**
- Build na AIX 7.1 → działa na AIX 7.2, 7.3
- Build z g++ 9.x → działa na systemach bez g++ lub ze starszym/nowszym g++
- Brak problemów z różnymi wersjami `libstdc++.so`

#### 4. **Bezpieczeństwo i stabilność**
- Nie ma ryzyka aktualizacji systemowej biblioteki lamie aplikację
- Wersja biblioteki jest zawsze ta sama, z którą testowałeś

## Weryfikacja

### Sprawdź rozmiar binarki
```bash
ls -lh build/node_exporter_aix
# Oczekiwane: ~2-5 MB (większe niż dynamiczny build)
```

### Sprawdź zależności
```bash
ldd build/node_exporter_aix
```

**Oczekiwany wynik (static build):**
```
build/node_exporter_aix needs:
        /usr/lib/libperfstat.a(shr.o)
        /usr/lib/libpthread.a(shr_xpg5.o)
        /usr/lib/libc.a(shr.o)
```

**Niepożądany wynik (dynamic build):**
```
build/node_exporter_aix needs:
        /opt/freeware/lib/libstdc++.so.6     ← TO OZNACZA DYNAMIC!
        /opt/freeware/lib/libgcc_s.a(shr.o)  ← TO OZNACZA DYNAMIC!
        /usr/lib/libperfstat.a(shr.o)
        ...
```

### Test na czystym systemie
```bash
# Skopiuj na system bez zainstalowanego g++
ssh clean-aix-system "which g++"
# Jeśli: "Command not found" = dobry test

scp build/node_exporter_aix clean-aix-system:/tmp/
ssh clean-aix-system "/tmp/node_exporter_aix --help"
# Powinno działać! ✅
```

## Alternatywa: Build Dynamiczny

Jeśli chcesz **mniejszy** plik binarny (kosztem zależności):

### 1. Edytuj Makefile
```makefile
# Zakomentuj:
# LDFLAGS = -pthread -static-libgcc -static-libstdc++ -lperfstat

# Odkomentuj:
LDFLAGS = -pthread -lperfstat
```

### 2. Wymagania na systemach docelowych
Musisz zainstalować na KAŻDYM systemie:
```bash
yum install libstdc++-9*
```

### 3. Wady
- ❌ Wymagana instalacja pakietów na serwerach produkcyjnych
- ❌ Problemy z wersjami bibliotek
- ❌ Większa złożoność deploymentu

## Podsumowanie

| Aspekt | Static Build | Dynamic Build |
|--------|--------------|---------------|
| **Rozmiar** | ~3-5 MB | ~300-500 KB |
| **Zależności** | Tylko AIX system libs | Wymaga g++ libs |
| **Deployment** | Skopiuj 1 plik | Install pakiety + plik |
| **Kompatybilność** | ✅ Wysoka | ⚠️ Wymaga zgodnych wersji |
| **Zalecane dla** | **Produkcja, dystrybucja** | Development, testing |

## ⭐ Rekomendacja

**Używaj statycznego linkowania** (domyślne) dla:
- Deploymentu produkcyjnego
- Dystrybucji do wielu systemów AIX
- Sytuacji gdzie nie możesz instalować dodatkowych pakietów

Obecna konfiguracja Makefile jest **optymalna** dla Twojego use case! 🎯
