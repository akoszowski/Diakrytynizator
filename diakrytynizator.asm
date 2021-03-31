; Zadanie 1 - "Diakrytynizator"
; Antoni Koszowski(418333)


global _start

SYS_EXIT    equ 60
SYS_READ    equ 0
SYS_WRITE   equ 1
STDIN       equ 0
STDOUT      equ 1


section .data
args_num    dw   0                  ; Liczba argumentów (tj. współczynników wielomianu).


section .bss
chr         resb 1                  ; Alokujemy zmienną pomocniczą 1bajt.
buffer      resb 4                  ; Alokujemy bufor 4bajt.


section .text

_start:
    mov     r10D, 0x10FF80          ; Zapisujemy stałą modulo.

    lea     rbp, [rsp + 2*8]        ; Adres args[0].
    mov     rsi, [rbp]
    test    rsi, rsi
    jz      failure                 ; Mamy zero parametrów.

; Wczytywanie i konwersja paremetrów wielomianu diakrytynizującego.
args_reader:
    ; Rejestry:
    ;   -> rdx:rax - rax wynik, rdx reszta,
    ;   -> rsi     - aktualny argument,
    ;   -> rdi     - obecny wynik, tzn. parametr modulo stała,
    ;   -> rbx     - kolejne literki.

    mov     rsi, [rbp]              ; Adres kolejnego parametru.
    test    rsi, rsi
    jz      input_reader            ; Wczytaliśmy wszystkie parametry.

    xor     ebx, ebx                ; Zerujemy rejestr, w którym trzymamy literki.
    xor     ecx, ecx                ; Zerujemy rejestr, w którym trzymamy licznik.
    xor     edi, edi                ; Zerujemy rejestr, w którym trzymamy wynik.

; Wczytywanie kolejnych literek danego parametru.
arg_loop:
    mov     bl, [rsi + rcx]         ; Wczytujemy kolejną literką danego parametru.
    test    bl, bl
    jz      next_arg                ; Null, wczytaliśmy parametr.

    cmp     bl, 48                  ; Sprawdzamy czy literka jest z zakresu '0' - '9'.
    jl      failure
    cmp     bl, 57
    jg      failure
    sub     bl, 48                  ; Konwertujemy tekst na liczbę.

    mov     eax, edi                ; Wczytujemy obecny wynik do eax.
    mov     edi, 10
    mul     edi                     ; Mnożymy zawartość eax przez 10.
    add     eax, ebx                ; Dodajemy aktualną cyferkę.

    idiv    r10D                    ; Bierzemy wynik modulo nasza stała.
    mov     edi, edx                ; Przerzucamy resztę z dzielenia.

    inc     ecx
    jmp     arg_loop

next_arg:
    push    rdi                     ; Wrzucamy wyliczony współczynnik na stos.

    inc     dword [args_num]        ; Zwiększamy licznik argumentów.
    add     rbp, 8                  ; Przesuwamy wskażnik na następny argument.
    jmp     args_reader


; Po zakończeniu pętli args_loop mamy wczytane i odłożone na stosie
; współczynniki modulo nasza stała, odpowiednio pod adresem rsp mamy a_n
; dodatkowo w zmiennej args_num mamy liczbę tych argumentów.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Wczytywanie danych wejściowych;
input_reader:
    ; Rejestry:
    ;   -> rbx  - operacje na obecnie wczytywanym znaku (w UTF-8),
    ;   -> r8   - informacje dot. liczby bitów, które jeszcze chcemy wczytać,
    ;   -> r12  - licznik bitów, które jeszcze chcemy wczytać,
    ;   -> r13  - operacje na buforze.

    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, chr              ; Wczytujemy bajt do lokalnej zmiennej.
    mov     rdx, 1
    syscall

    test    rax, rax              ; Sprawdzamy czy był to ostatni znak.
    jz      success

    ; Klasyfikujemy długość danego znaku:
    ; 0xxxxxxx              - 1bajt
    mov     bl, [chr]
    cmp     bl, 0x80              ; Sprawdzamy czy wczytany znak jest w przedziale
                                  ; od 0x00 do 0x7F (wtedy nie konwertujemy)
    jb      plain_ascii

    ; 11110xxx (10xxxxxx)^3 - 4bajty
    mov     r12D, 3               ; Tu trzymamy liczbę bitów,
                                  ; które jeszcze chcemy wczytać.
    cmp     bl, 0xF8
    jae     failure               ; Niepoprawne kodowanie w UTF-8.
    cmp     bl, 0xF0
    jae     rest_reader           ; Mamy znak kodowany na 4 bajtach.

    ; 1110xxxx (10xxxxxx)^2 - 3bajty
    dec     r12D                  ; Jeśli coś będzie poprawne to wczytamy max 2 bajty.
    cmp     bl, 0xE0
    jae     rest_reader           ; Mamy znak kodowany na 3 bajtach.

    ; 110xxxxx 10xxxxxx     - 2bajty
    dec     r12D
    cmp     bl, 0xC0              ; Jeśli coś będzie poprawne to wczytamy max 1 bajt.
    jae     rest_reader           ; Mamy znak kodowany na 2 bajtach.

    jmp     failure               ; Niepoprawne kodowanie w UTF-8.

; Wczytujemy pozostałe bity kodujące obecnie przetwarzany znak.
rest_reader:
    mov     r13, buffer           ; Do bufora będziemy wczytywać kolejne bajty.
    mov     r8, r12               ; Wczytujemy liczbę bajtów (-1), które ma nasz znak.
    inc     r8

    mov     byte [r13], bl        ; Buforujemy to co właśnie wczytaliśmy.
    inc     r13

rest_loop:
    test    r12D, r12D            ; Sprawdzamy czy już wszystko wczytaliśmy.
    jz      utf_to_hex          ; Wszystko wczytane prawidłowo.

    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, chr              ; Wczytujemy bajt do lokalnej zmiennej.
    mov     rdx, 1
    syscall

    test    rax, rax
    jz      failure               ; Chcieliśmy wczytać, ale to się nie udało.

    shl     ebx, 8                ; Robimy miejsce na kolejny bajt.

    mov     bl, [chr]             ; Ładujemy kolejny bajt do rejestru bl.
    cmp     bl, 0x80
    jb      failure               ; Wczytany bajt nie jest postaci 10xxxxxx.

    dec     r12D                  ; Zmniejszamy liczbę bajtów do wczytania.
    jmp     rest_loop


; Udało nam się wczytać znak w UTF-8, w rejestrzeb ebx mamy jego pełne kodowanie,
; ponadto w r8 mamy długość jego zapisu bitowego.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Konwersja z UTF-8 na hex.
utf_to_hex:
    ; Rejestry:
    ;   -> rdx:rax - rax wynik, rdx reszta,
    ;   -> rbx     - arguement wielomianu.

    mov     eax, ebx              ; Wczytujemy kod znaku do eax.

    ; Klasyfikujemy w celu odpowiedniej konwersji.
    cmp     r8, 2
    je      byte2_to_hex

    cmp     r8, 3
    je      byte3_to_hex

    cmp     r8, 4
    je      byte4_to_hex

    jmp failure

byte2_to_hex:
    mov     r9D, 0x00001F3F       ; Maska bitowa konwersji z UTF-8 na hex.
    pext    ebx, eax, r9D         ; Rzeczywista konwersja na hex.
    cmp     ebx, 0x80
    jb      failure               ; To nie jest najkrótszy zapis.
    jmp     poly

byte3_to_hex:
    mov     r9D, 0x000F3F3F       ; Maska bitowa konwersji z UTF-8 na hex.
    pext    ebx, eax, r9D         ; Rzeczywista konwersja na hex.
    cmp     ebx, 0x0800
    jb      failure               ; To nie jest najkrótszy zapis.
    jmp     poly

byte4_to_hex:
    mov     r9D, 0x073F3F3F       ; Maska bitowa konwersji z UTF-8 na hex.
    pext    ebx, eax, r9D         ; Rzeczywista konwersja na hex.
    cmp     ebx, 0x10FFFF
    ja      failure               ; Przekroczenie górnego ograniczenia na UTF-8.
    cmp     ebx, 0x010000
    jb      failure               ; To nie jest najkrótszy zapis.
    jmp     poly

; Wyliczamy wartość wielomianu diakrytynizującego dla argumentu w hex.
; Korzystamy ze schematu Horner'a.
poly:
    mov     r12D, dword [args_num]; Wczytujemy liczbę współ. wiel. diakryt.
    lea     rbp, [rsp]            ; Wczytujemy adres a_n.
    sub     ebx, 0x80             ; Argument wielomian, tj. x.

    mov     eax, [rbp]            ; W rejestrze eax będziemy przechowywać
                                  ; bieżącą wartość wiel. diakrytynizującego.
    add     rbp, 8                ; Kolejny współczynnik.
    dec     r12D                  ; Zmniejszamy licznik.

poly_loop:
    test    r12D, r12D
    jz      end_loop              ; Policzyliśmy oczekiwaną wartość.

    mul     ebx                   ; Mnożymy obecny wynik  przez x.
    add     eax, [rbp]            ; Dodajemy kolejny wspóczynnik.
    idiv    r10D                  ; Wyliczamy obecną wartość modulo.
    mov     eax, edx              ; Przesuwamy resztę modulo do rejestru eax.

    add     rbp, 8                ; Kolejny współczynnik.
    dec     r12D                  ; Zmniejszamy licznik.
    jmp poly_loop

end_loop:
    add     eax, 0x80;            ; Dodajemy na koniec do wyliczonej wartości 0x80.


; Mamy policzoną wartość hex na podstawie zadanego wielomianu diakrytynizującego.
; W rejestrze rax znajduje się ta wartość w hex.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Konwertujemy wyliczoną wartość w hex na UTF-8.
hex_to_utf:
    mov     ecx, eax              ; Wczytujemy wyliczoną wartość do ecx.

    cmp     ecx, 0x10000
    jae     byte4_to_utf          ; Kodowanie na 4 bitach.

    cmp     ecx, 0x800
    jae     byte3_to_utf          ; Kodowanie na 3 bitach.

    cmp     ecx, 0x80
    jae     byte2_to_utf          ; Kodowanie na 2 bitach.

    jmp     failure

byte2_to_utf:
    mov     r12D, 0x0000C080
    mov     r8D, 2                ; W r8 zachowujemy długość w bitach wyliczonego kodu.
    mov     r9D, 0x00001F3F       ; Maska bitowa konwersji z hex na UTF-8.
    pdep    eax, ecx, r9D
    xor     eax, r12D             ; Rzeczywista konwersja na UTF-8.
    jmp     write_to_buffer

byte3_to_utf:
    mov     r12D, 0x00E08080
    mov     r8D, 3                ; W r8 zachowujemy długość w bitach wyliczonego kodu.
    mov     r9D, 0x000F3F3F       ; Maska bitowa konwersji z hex na UTF-8.
    pdep    eax, ecx, r9D
    xor     eax, r12D             ; Rzeczywista konwersja na UTF-8.
    jmp     write_to_buffer

byte4_to_utf:
    mov     r12D, 0xF0808080
    mov     r8D, 4                ; W r8 zachowujemy długość w bitach wyliczonego kodu.
    mov     r9D, 0x073F3F3F       ; Maska bitowa konwersji z hex na UTF-8.
    pdep    eax, ecx, r9D
    xor     eax, r12D             ; Rzeczywista konwersja na UTF-8.
    jmp     write_to_buffer

; Chcemy odpowiednio zapisać do naszego bufora kodowanie skonwertowanego znaku w UTF-8.
write_to_buffer:
    mov     r9, buffer            ; Do bufora wpisujemy kolejne bity.
    mov     ecx, r8D              ; Inicjalizujemy licznik.

write_loop:
    test    ecx, ecx
    jz      print                 ; Wczytaliśmy to co chcieliśmy.

    dec     ecx
    lea     r12, [r9 + rcx]
    mov     [r12], al             ; Wpisujemy do bufora od końca.
    shr     eax, 8                ; Robimy miejsce na kolejny bajt.
    jmp     write_loop

plain_ascii:
    mov     r8, 1
    mov     [buffer], bl          ; Przekazujemy dalej wczytaną literkę.

; Wypisujemy skonwertowany (lub nie) znak.
print:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, buffer
    mov     rdx, r8               ; Wypisujemy dokładnie tyle ile trzeba.
    syscall

    jmp     input_reader          ; Wczytujemy kolejny znak.

failure:
    mov     eax, SYS_EXIT
    mov     edi, 1                ; Kod powrotu 1.
    syscall

success:
    mov     eax, SYS_EXIT
    xor     edi, edi              ; Kod powrotu 0.
    syscall
