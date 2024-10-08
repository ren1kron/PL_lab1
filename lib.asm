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
    ; pop rdi             ; restore rdi
    pop rsi             ; we'll mov rdi to rsi anyway
    
    mov rdx, rax        ; put string length in rdx
    ; mov rsi, rdi        ; put string adress in rsi

    mov rax, sys_write  ; put code for write syscall in rax
    mov rdi, stdout     ; put stdout descriptor in rdi

    syscall
    
    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline: ; done (ok)
    mov rdi, `\n`
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


; Выводит знаковое 8-байтовое число в десятичном формате 
print_int: ; done (ok)
    mov rax, rdi

    test rax, rax       ; set flags
    jns print_uint      ; if num > 0 - print as unsigned

    ; print minus part

        push rdi        ; save our num
        mov rdi, '-'    ; put there '-' to print it
        call print_char ; print it )

        pop rdi         ; get our num back
        neg rdi         ; and make num unsigned/positive

    ; then print_uint will be executed

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint: ; done (ok)
; rdi - число для вывода
    mov rax, rdi        ; put number to divide in rax
    mov r11, 10         ; r11 <- divider

    push 0              ; put null-terminator for proper output (now rsp%16==0)
    mov rdi, rsp        ; save old rsp
    sub rsp, 32         ; allocate buffer for string (rsp%16 == 0)

    .div10:
        xor rdx, rdx    ; clear rdx before div
        div r11         
        add dl, '0'     ; turn num to ASCII equivalent (char)

        dec rdi         ; save char 
        mov [rdi], dl   ;on stack
        
        test rax, rax
        jz .print_num

        jmp .div10

    .print_num:
        call print_string

        add rsp, 32 ; (rsp%16 == 0)
        pop rax     ; (rsp%16 == 8 (ret address on top of stack now))
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

        cmp al, ' '    ; skip space
        je .space_skip  ;
        cmp al, `\t`     ; skip '\t'
        je .space_skip  ;
        cmp al, `\n`     ; skip '\n'
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

        cmp rax, ` `		; sym == ' '? -> word ended
		je .success

        cmp rax, `\n`		; sym == '\n'? -> word ended
		je .success
		
		cmp rax, `\t`		; sym == '\t'? -> word ended
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
    xor rsi, rsi                ; rdx used for 'mul' so we need another reg as counter
    xor rax, rax
    mov r11, 10                 ; r11 <- divider
    xor rcx, rcx
    xor rdx, rdx                ;

    .read_num:
        mov cl, byte[rsi + rdi]

        cmp cl, '9'             ; Check if sym is num
        ja .ret                 ;
        sub cl, '0'             ;
        jb .ret                 ;

        mul r11
        add rax, rcx

        inc rsi
        jmp .read_num

    .ret:
        mov rdx, rsi
        ret




; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int: ; done (ok)
    mov al, byte[rdi]
    cmp al, '-'
    je .neg
    cmp al, '+'
    jne parse_uint

    .neg:
        push rdi
        inc rdi
        call parse_uint
        pop rdi

        cmp byte[rdi], '+'
        je .skip_invertion
        neg rax

        .skip_invertion:
            test rdx, rdx
            je .error
            
            inc rdx
        
        .error:
            ret

    ret 

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy: ; done (ok)
    push rdi            ; ''
    push rsi            ; save caller-saved registers 
    push rdx            ; ''
    call string_length      
    pop rdx
    pop rdi
    pop rsi

    cmp rax, rdx
    jae .error       ; buffer smaller then string length? -> return 0
    mov rcx, rax

    rep movsb

    .end:
        mov byte[rdi], 0
        ret
    .error:
        xor rax, rax
        ret

