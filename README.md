# Diakrytynizator
This is a first assembly assignment for Operating Systems course at the University of Warsaw

---

## Zadanie

Zaimplementuj w asemblerze x86_64 program, który czyta ze standardowego wejścia tekst, modyfikuje go w niżej opisany sposób, a wynik wypisuje na standardowe wyjście. Do kodowania tekstu używamy UTF-8, patrz https://pl.wikipedia.org/wiki/UTF-8. Program nie zmienia znaków o wartościach unicode z przedziału od 0x00 do 0x7F. Natomiast każdy znak o wartości unicode większej od 0x7F przekształca na znak, którego wartość unicode wyznacza się za pomocą niżej opisanego wielomianu.

## Wielomian diakrytynizujący

Wielomian diakrytynizujący definiuje się przez parametry wywołania diakrytynizatora:

./diakrytynizator a0 a1 a2 ... an

jako:

w(x) = an * x^n + ... + a2 * x^2 + a1 * x + a0

Współczynniki wielomianu są nieujemnymi liczbami całkowitymi podawanymi przy podstawie dziesięć. Musi wystąpić przynajmniej parametr a0.

Obliczanie wartości wielomianu wykonuje się modulo 0x10FF80. W tekście znak o wartości unicode x zastępuje się znakiem o wartości unicode w(x - 0x80) + 0x80.

## Zakończenie programu i obsługa błędów

Program kwituje poprawne zakończenia działania, zwracając kod 0. Po wykryciu błędu program kończy się, zwracając kod 1.

Program powinien sprawdzać poprawność parametrów wywołania i danych wejściowych. Przyjmujemy, że poprawne są znaki UTF-8 o wartościach unicode od 0 do 0x10FFFF, kodowane na co najwyżej 4 bajtach i poprawny jest wyłącznie najkrótszy możliwy sposób zapisu.
