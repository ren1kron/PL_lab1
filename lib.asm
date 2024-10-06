section .text

global exit

global print_string
global print_char
global print_newline
global print_uint
global print_int

global string_length
global string_equals
global string_copy

global read_char
global read_word

global parse_uint
global parse_int


; ASCII symbols
%define space_sym   0x20
%define tab_sym     0x9
%define newline_sym 0xA

; sys constants
%define sys_exit 60
%define sys_write 1
%define sys_read 0

; descriptors
%define stdin 0
%define stdout 1
%define stderr 2

;===================================================================================
;
; callee-saved: rbx, rbp, rsp, r12-r15
; caller-saved: all other
;
;===================================================================================
 
 
; Принимает код возврата и завершает текущий процесс
exit: ; done (ok)
    mov  rax, sys_exit
    syscall

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length: ; done (ok)
    xor rax, rax          ; clear rax

    .loop:
        cmp byte[rdi + rax], 0 ; char on [rdi + rax] == 0?
        je .done               ; we found end of string
        inc rax                ; else increment rax
        jmp .loop              ; and continue cycle

    .done:
        ret                    ; 
    


; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string: ; done (ok)
    push rdi            ; save rdi (caller-saved)
    call string_length  ; put string length in rax
    pop rdi             ; restore rdi
    
    mov rdx, rax        ; put string length in rdx
    mov rsi, rdi        ; put string adress in rsi

    mov rax, sys_write  ; put code for write syscall in rax
    mov rdi, stdout     ; put stdout descriptor in rdi

    syscall
    
    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline: ; done (ok)
    mov rdi, newline_sym
    ; where is no ret here
    ; so it is like we called print_char with '\n' in rdi

; Принимает код символа и выводит его в stdout
print_char: ; done (ok)
    push rdi

    mov rax, sys_write
    mov rdi, stdout
    mov rsi, rsp
    mov rdx, 1 ; length of string to output - 1, because it is just 1 char
    syscall
    pop rdi

    ret



; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    xor rax, rax
    ret

; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    xor rax, rax
    ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals: ; done (ok)
    ; rdi: points to string1 current byte
    ; rsi: points to string2 current byte
    xor rax, rax
    .loop:
        mov r8b, byte [rdi]
        cmp r8b, byte [rsi]
        ; cmp byte [rdi], byte [rsi] ; compare chars
        jne .not_equals     ; not equals? -> return 0
                            ; ''
                            ; else
        cmp byte [rdi], 0   ; char == 0?
        je .equals          ; end of strings - return 1
                            ;
        inc rdi             ; esle increment rdi
        inc rsi             ; and rsi
        jmp .loop           ; and continue cycle

    .equals:
        inc rax ; make rax == 1
    .not_equals:
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char: ; done (ok)
    ; mov rax, sys_read   ; sys_read == 0, it is more effective to write 0 in 'rax' by 'xor' 
    xor rax, rax        ; 

    push ax             ; allocate buffer (we will use stack as buffer)

    ; mov rdi, stdin      ; stdin == 0, same story as with rax
    xor rdi, rdi        ;  

    mov rsi, rsp      ; rsp now points at our buffer
    mov rdx, 1          ; how much do we read? - 1 byte

    syscall             ; 
    pop ax              ;  accumulator <- char from buffer
    ret 

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор

read_word: ; done (ok)
; rdi - buffer address, rsi - buffer size
; rax - word size, rdx - word length

    ; xor rax, rax
    ; xor r8, r8

    test rsi, rsi
    jz .fail ; fail if word length <= 0

    mov r8, rdi     ; buffer address
    mov r9, rsi     ; buffer size
    xor r10, r10    ; char counter

    
    .space_skip:
            ; sub rsp, 8
            push r8
            push r9
            push r10
        call read_char  ; now char in 'rax'
            ; add rsp, 8
            pop r10
            pop r9
            pop r8

        cmp al, 0x20    ; skip space
        je .space_skip  ;
        cmp al, 0x9     ; skip '\t'
        je .space_skip  ;
        cmp al, 0xA     ; skip '\n'
        je .space_skip  ;
        
        test al, al     ; if there is null-term - fail
        jz .fail

    xor r10, r10
    .read:
        cmp r10, r9         ; if the end of buffer reached ->
        je .fail            ; fail

        mov byte[r8 + r10], al  ; put char in buffer 

        test al, al         ; readed char - EOF? => return
        je .success         ; 

        inc r10             ; else read next char

            ; sub rsp, 8
            push r8
            push r9
            push r10
        call read_char
            ; add rsp, 8
            pop r10
            pop r9
            pop r8

        cmp rax, 0x20		; sym == ' '? -> word ended
		je .success

        cmp rax, 0xA		; sym == '\n'? -> word ended
		je .success
		
		cmp rax, 0x9		; sym == '\t'? -> word ended
		je .success


        jmp .read           

    .success:
        mov byte[r8 + r10], 0
        mov rdx, r10
        mov rax, r8
        ret
        
    .fail:
        xor rax, rax
        xor rdx, rdx
        ret
 

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax
    ret




; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    xor rax, rax
    ret 

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rax, rax
    ret
