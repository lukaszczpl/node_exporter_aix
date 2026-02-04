# Instalacja G++ 9.x na AIX

## Szybki Start

### 1. Sprawdź aktualną wersję
```bash
g++ --version
```

### 2. Instalacja przez AIX Toolbox (Zalecane)

#### Metoda A: Używając YUM (jeśli skonfigurowane)
```bash
# Sprawdź dostępne wersje
yum search gcc-c++

# Zainstaluj g++ 9.x
yum install gcc-c++-9*

# Lub najnowszą dostępną wersję
yum install gcc-c++
```

#### Metoda B: Ręczne pobranie z AIX Toolbox
1. Odwiedź: https://public.dhe.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/
2. Pobierz odpowiednie pakiety RPM:
   - `gcc-c++-9.x.x-x.aix7.1.ppc.rpm`
   - `gcc-9.x.x-x.aix7.1.ppc.rpm`
   - `libstdc++-9.x.x-x.aix7.1.ppc.rpm`
   - `libstdc++-devel-9.x.x-x.aix7.1.ppc.rpm`

3. Zainstaluj:
```bash
rpm -ivh gcc-9*.rpm gcc-c++-9*.rpm libstdc++*.rpm
```

### 3. Weryfikacja
```bash
g++ --version
# Powinna pokazać: g++ (GCC) 9.x.x

# Test kompilacji z C++17
echo '#include <chrono>' > test.cpp
g++ -std=c++17 -c test.cpp
```

### 4. Kompilacja projektu
```bash
# Domyślnie używa g++
make clean
make

# Lub wskaż konkretną wersję
make CXX=/opt/freeware/bin/g++-9
```

## Rozwiązywanie Problemów

### Problem: "g++ not found"
```bash
# Znajdź zainstalowane wersje
ls /opt/freeware/bin/g++*

# Dodaj do PATH
export PATH=/opt/freeware/bin:$PATH
```

### Problem: "chrono file not found"
Upewnij się, że masz zainstalowane:
- `libstdc++-devel` - zawiera nagłówki C++ standard library

```bash
rpm -qa | grep libstdc++
```

### Problem: Konflikt wersji
```bash
# Usuń starszą wersję
rpm -e gcc-c++-7*

# Zainstaluj nową
yum install gcc-c++-9*
```

## Dodatkowe Informacje

- **Lokalizacja domyślna**: `/opt/freeware/bin/`
- **Wymagane biblioteki**: libstdc++, libgcc
- **Kompatybilność**: AIX 7.1, 7.2, 7.3
