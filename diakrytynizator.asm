; Zadanie 1 - "Diakrytynizator"
; Antoni Koszowski(418333)

; TODO: odpowiednie formatowanie !


global _start

SYS_EXIT    equ 60
SYS_READ    equ 0
SYS_WRITE   equ 1
STDIN       equ 0
STDOUT      equ 1
MAX_LINE    equ 64  ; FIXME: jak z tymi współczynnikami

section .rodata
new_line    db `\n`
dupa        db `dupa\n`

section .data
args_num    dw   0    ; liczba argumentów (tj. współczynników wielomianu)


section .bss
chr         resb 1    ; alokujemy zmienną 1bajt
cnt         resb 1
buffer      resb 4    ; alokujemy zmienną 4bajt

section .text


; Małymi kroczkami, najpierw dla pojedynczych liter !!!

; Etap 1:       Wczytanie parametrów wielomianu diakrytynizującego
;               a_0 a_1 ... a_n + konwersja
;    var:       liczba parametrów, mamy je na stosie ?!? OK
; Etap 2:       Wczytywanie z echo do bufora (porcjami?)
;    var:       rozmiar bufora, bufor trzymający liczby 32bit

; Etap 3:       Kowersja z UTF-8 na hex + sprawdzenie czy najkrótsza możliwa forma.
; Etap 4:       Wyliczenie wartości wielomianu modulo 0x10FF80
; Etap 5:       Konwersja z hex na UTF-8
; Etap 6:       Wypisanie wyjścia, powrót do 2)
_start:
    mov     r10D, 0x10FF80          ; zapisujemy stałą modulo

; Wczytywanie i konwersja paremetrów wielomianu diakrytynizującego.
    lea     rbp, [rsp + 2*8]        ; adres args[0]

args_reader:
    mov     rsi, [rbp]              ; adres kolejnego argumentu
    test    rsi, rsi
    jz      input_reader              ; napotkano zerowy wskażnik

    ; literka po literce
    ;   -> sprawdzamy czy '0' - '9'
    ;   -> liczymy wartość współczynnika modulo

    ; zerujemy rejestr, w którym trzymamy literki, wynik
    xor     ebx, ebx
    xor     ecx, ecx
    xor     edi, edi
arg_loop:
    ; rejestry:
    ;   -> rdx:rax - rax wynik, rdx reszta
    ;   -> rsi     - aktualny argument
    ;   -> rdi     - obecny wynik
    ;   -> rbx     - kolejne literki
    ;   -> rcx     - licznik literek

    ; sprawdzamy ograniczenie MAX_LINE (to pewnie do wywalenia)
    cmp     ecx, MAX_LINE
    je      next_arg
    ; wczytujemy literkę i sprawdzamy czy null
    mov     bl, [rsi + rcx]
    test    bl, bl
    jz      next_arg
    ; sprawdzamy czy jest z zakresu '0' - '9', odejmujemy '0', tj. 48 wpp.failure!
    cmp     bl, 48
    jl      failure
    cmp     bl, 57
    jg      failure
    sub     bl, 48
    ; wczytujemy wynik, mnożymy go przez 10, dodajemy cyfrę
    mov     eax, edi
    mov     edi, 10                      ; mnożymy zawartość eax przez 10
    mul     edi
    add     eax, ebx
    ; bierzemy wynik modulo mod, idiv -> rem w edx
    idiv    r10D
    mov     edi, edx
    ; aktualizujemy wartości rejestrów
    inc     ecx
    jmp     arg_loop

next_arg:
    ; wrzucamy wyliczony współczynnik na stos
    push    rdi

    ; TEST
    ; mov     rdx, rdi
    mov     eax, SYS_WRITE
    mov     edi, STDOUT
    ; sub     rdx, rsi                ; liczba bajtów do wypisania
    mov     rdx, rcx
    syscall
    mov     eax, SYS_WRITE
    mov     edi, STDOUT
    mov     rsi, new_line           ; wypisujemy znak nowej lini
    mov     edx, 1                  ; wypisujemy jeden znak
    syscall
    ; /TEST

    inc     dword [args_num]              ; zwiększamy licznik argumentów
    add     rbp, 8                  ; przechodzimy do następnego argumentu
    jmp     args_reader


; po zakończeniu pętli args_loop mamy wczytane i odłożone na stosie
; współczynniki modulo nasza stała, odpowiednio pod adresem [rsp] mamy a_n
; dodatkowo w zmiennej args_num mamy liczbę tych argumentów

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


input_reader:
    ; rejestry:
    ;   -> rbx  - operacje na obecnie wczytywanym znaku (w UTF-8)
    ;   -> r8   - informacje dot. liczby bitów, które jeszcze chcemy wczytać
    ;   -> r9   - maska bitowa do konwersji hex -> ascii, ascii -> hex
    ;   -> r12  - licznik bitów, które jeszcze chcemy wczytać
    ;   -> r13  - operacje na buforze
    ;


    ; czyścimy bufor
    ; mov     dword ptr [buffer]
    ; wczytujemy po jednym bajcie
    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, chr              ; wczytujemy do lokalnej zmiennej
    mov     rdx, 1
    syscall

    test    rax, rax                ; sprawdzamy czy to był ostatni znak! (to trzeba rozszerzyć, potencjalne problemy)
    jz      success

    ; klasyfikujemy długość danego znaku (trzeba wykrywać błędy !!!)
    ; + czy jest to najkrótszy możliwy sposób zapisu
    ; 0xxxxxxx              - 1bajt
    mov     bl, [chr]
    cmp     bl, 0x80        ; sprawdzamy czy wczytany znak jest w przedziale od 0x00 do 0x7F (wtedy nie konwertujemy)
    jb      plain_ascii

    ; 11110xxx (10xxxxxx)^3 - 4bajty
    mov     r12D, 3                 ; tu trzymamy liczbę bitów, które jeszcze chcemy wczytać
    cmp     bl, 0xF0
    ja      rest_reader             ; mamy znak kodowany na 4 bajtach
    je      failure                 ; można tę liczbę zapisać krócej

    ; 1110xxxx (10xxxxxx)^2 - 3bajty
    dec     r12D                    ; jeśli coś będzie poprawne to będzie miało max 2 bajty do wczytania
    cmp     bl, 0xE0
    ja      rest_reader             ; mamy znak kodowany na 3 bajtach
    je      failure                 ; można tę liczbę zapisać krócej

    ; 110xxxxx 10xxxxxx     - 2bajty
    dec     r12D
    cmp     bl, 0xC0                ; jeśli coś będzie poprawne to wczytamy max 1 bajt
    ja      rest_reader             ; mamy znak kodowany na 2 bajtach

    jmp     failure                 ; niepoprawne kodowanie w UTF-8


; wczytujemy pozostałe bity kodujące obecnie przetwarzany znak
rest_reader:
    mov     r13, buffer               ; do bufora będziemy wczytywać kolejne bajty
    lea     r8, [r12 + 1]             ; pamiętamy liczbę bajtów które ma nasz znak

    mov     byte [r13], bl            ; buforujemy to co właśnie wczytaliśmy
    inc     r13

    ; ; TEST
    ; add     r12, 48
    ; mov     [cnt], r12D
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, cnt
    ; mov     rdx, 1
    ; syscall
    ; mov     eax, SYS_WRITE
    ; mov     edi, STDOUT
    ; mov     rsi, new_line           ; wypisujemy znak nowej lini
    ; mov     edx, 1
    ; syscall
    ; sub     r12D, 48
    ; ; /TEST


; tu jeszcze może być taki problem, ze wczytamy coś innego niż 10xxxxxx
rest_loop:
    test    r12D, r12D                ; sprawdzamy czy już wszystko wczytaliśmy
    jz      ascii_to_hex            ; wszystko wczytane prawidłowo

    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, chr               ; wczytujemy do lokalnej zmiennej
    mov     rdx, 1
    syscall

    ; sprawdzamy czy aby na pewno wczytaliśmy kod postaci 10xxxxxx
    mov     bl, [chr]
    cmp     bl, 0x80
    jb      failure

    mov     byte [r13], bl           ; buforujemy to co wczytaliśmy
    inc     r13

    ; TEST
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, dupa
    ; mov     rdx, 5
    ; syscall
    ; /TEST

    dec     r12D
    jmp     rest_loop

; udało nam się wczytać znak w utf-8
ascii_to_hex:
    jmp     print

    ; jeszcze raz klasyfikujemy w celu odpowiedniej konwersjii
    cmp     r8, 2
    je      byte2_to_hex

    cmp     r8, 3
    je      byte3_to_hex

    cmp     r8, 4
    je      byte4_to_hex

    jmp failure

byte2_to_hex:
    mov     r9D, 0x1F3F             ; maska bitowa konwersji z utf8 na hex


byte3_to_hex:
    mov     r9D, 0x0F3F3F           ; maska bitowa konwersji z utf8 na hex


byte4_to_hex:
    mov     r9D, 0x073F3F3F         ; maska bitowa konwersji z utf8 na hex


poly_val:
    ; wyliczamy wartość wielomianu diakrytynizującego dla argumentu w hex

hex_to_ascii:
    ; konwertujemy hex na ascii

plain_ascii:
    mov     r8, 1
    mov     [buffer], bl

print:
    ; wypisujemy skonwertowany znak

    ; TEST
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, buffer
    mov     rdx, r8
    syscall
    ; mov     eax, SYS_WRITE
    ; mov     edi, STDOUT
    ; mov     rsi, new_line           ; wypisujemy znak nowej lini
    ; mov     edx, 1
    ; syscall
    ; /TEST
    jmp     input_reader

failure:
    mov     eax, SYS_EXIT
    mov     edi, 1                  ; kod powrotu 1
    syscall

success:
    mov     eax, SYS_EXIT
    xor     edi, edi                ; kod powrotu 0
    syscall
