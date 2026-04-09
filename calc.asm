; ============================================================
;  calc.asm  –  Simple console calculator for Windows x86-64
;  Assemble : nasm -f win64 calc.asm -o calc.obj
;  Link     : x86_64-w64-mingw32-gcc calc.obj -o calc.exe -lkernel32 -nostartfiles -e main
; ============================================================

bits 64
default rel

extern GetStdHandle
extern WriteConsoleA
extern ReadConsoleA
extern ExitProcess

; ================================================================
section .data

msg_banner      db  "================================", 13, 10
                db  "   Assembly Calculator v1.0     ", 13, 10
                db  "================================", 13, 10, 0
msg_banner_len  equ $ - msg_banner

msg_prompt      db  13, 10, "Expression (e.g. 25 + 7, 100 / 4): ", 0
msg_prompt_len  equ $ - msg_prompt

msg_result      db  "= ", 0
msg_result_len  equ $ - msg_result

msg_again       db  13, 10, "Calculate again? (y/n): ", 0
msg_again_len   equ $ - msg_again

msg_divzero     db  "Error: division by zero", 13, 10, 0
msg_divzero_len equ $ - msg_divzero

msg_badop       db  "Error: use + - * /", 13, 10, 0
msg_badop_len   equ $ - msg_badop

msg_bye         db  "Goodbye!", 13, 10, 0
msg_bye_len     equ $ - msg_bye

crlf            db  13, 10, 0
crlf_len        equ $ - crlf

minus_sign      db  "-", 0

; ================================================================
section .bss

hOut        resq 1
hIn         resq 1
nWritten    resd 1
nRead       resd 1
inbuf       resb 128
; digit buffer for write_int (32 bytes, built right-to-left)
digbuf      resb 34

; ================================================================
section .text
global main

; ----------------------------------------------------------------
; con_write  rcx=buf  rdx=len
; Trashes: rax, rcx, rdx, r8, r9 + shadow space already managed
; ----------------------------------------------------------------
con_write:
    push rbp
    mov  rbp, rsp
    sub  rsp, 48            ; shadow (32) + 5th arg slot (8) + align (8)
    mov  rcx, [hOut]
    ; buf already in rdx – move it to r8 first
    mov  r8,  rdx           ; len
    mov  rdx, rcx           ; will be overwritten – fix order:
    ; Redo: args = hOut, buf(rdx on entry), len, &nWritten, NULL
    ; save buf before we clobber rdx
    mov  r8,  rdx           ; r8 = len  (wrong – fix below)
    ; WriteConsoleA(hConsole, lpBuffer, nCharsToWrite, lpNumberOfCharsWritten, NULL)
    ;   rcx = hOut
    ;   rdx = buf
    ;   r8  = len
    ;   r9  = &nWritten
    ;   [rsp+32] = NULL
    ; We received: rcx=buf, rdx=len  → rearrange
    mov  r8,  rdx           ; len → r8
    mov  rdx, rcx           ; buf → rdx
    mov  rcx, [hOut]        ; hOut → rcx
    lea  r9,  [nWritten]
    mov  qword [rsp+32], 0  ; 5th arg NULL
    call WriteConsoleA
    leave
    ret

; ----------------------------------------------------------------
; Macro wrapper: print  label, const_length
; ----------------------------------------------------------------
%macro print 2
    lea  rcx, [%1]
    mov  rdx, %2
    call con_write
%endmacro

; ----------------------------------------------------------------
; write_int  –  print signed 64-bit integer in rax
; Trashes: rax, rcx, rdx, r8, r9, r10, r11
; ----------------------------------------------------------------
write_int:
    push rbx
    push rdi

    ; point rdi to END of digit buffer (we fill right-to-left)
    lea  rdi, [digbuf + 33]
    mov  byte [rdi], 0      ; null terminator (unused but tidy)
    xor  rbx, rbx           ; negative flag

    test rax, rax
    jns  .positive
    neg  rax
    mov  rbx, 1             ; negative
.positive:
    mov  r10, 10
.extract:
    xor  rdx, rdx
    div  r10                ; rax=quotient rdx=remainder
    add  dl, '0'
    dec  rdi
    mov  [rdi], dl
    test rax, rax
    jnz  .extract

    ; prepend '-' if needed
    test rbx, rbx
    jz   .no_minus
    dec  rdi
    mov  byte [rdi], '-'
.no_minus:
    ; compute length
    lea  rax, [digbuf + 33]
    sub  rax, rdi           ; rax = length

    mov  rcx, rdi           ; buf
    mov  rdx, rax           ; len
    call con_write

    pop  rdi
    pop  rbx
    ret

; ----------------------------------------------------------------
; skip_spaces  –  advance rsi past ASCII spaces
; ----------------------------------------------------------------
skip_spaces:
    cmp  byte [rsi], ' '
    jne  .done
    inc  rsi
    jmp  skip_spaces
.done:
    ret

; ----------------------------------------------------------------
; parse_int  –  parse signed decimal at rsi, advance rsi
;               returns value in rax
; ----------------------------------------------------------------
parse_int:
    call skip_spaces
    xor  rax, rax
    xor  r11, r11           ; sign flag
    cmp  byte [rsi], '-'
    jne  .digits
    inc  rsi
    mov  r11, 1
.digits:
    movzx rcx, byte [rsi]
    cmp  cl, '0'
    jb   .done
    cmp  cl, '9'
    ja   .done
    imul rax, rax, 10
    and  rcx, 0x0F
    add  rax, rcx
    inc  rsi
    jmp  .digits
.done:
    test r11, r11
    jz   .ret
    neg  rax
.ret:
    ret

; ================================================================
main:
    push r12
    push r13
    push r14
    push r15
    push rbx
    sub  rsp, 40

    ; get handles
    mov  rcx, -11           ; STD_INPUT_HANDLE
    call GetStdHandle
    mov  [hIn], rax

    mov  rcx, -10           ; STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  [hOut], rax

    print msg_banner, msg_banner_len

.mainloop:
    print msg_prompt, msg_prompt_len

    ; read a line
    mov  rcx, [hIn]
    lea  rdx, [inbuf]
    mov  r8d, 127
    lea  r9,  [nRead]
    sub  rsp, 40
    push 0
    call ReadConsoleA
    add  rsp, 48

    lea  rsi, [inbuf]

    ; parse A
    call parse_int
    mov  r12, rax

    ; get operator
    call skip_spaces
    movzx r13, byte [rsi]
    inc  rsi

    ; parse B
    call parse_int
    mov  r14, rax

    ; dispatch
    cmp  r13b, '+'
    je   .add
    cmp  r13b, '-'
    je   .sub
    cmp  r13b, '*'
    je   .mul
    cmp  r13b, '/'
    je   .div

    print msg_badop, msg_badop_len
    jmp  .ask

.add:
    mov  rax, r12
    add  rax, r14
    jmp  .show

.sub:
    mov  rax, r12
    sub  rax, r14
    jmp  .show

.mul:
    mov  rax, r12
    imul rax, r14
    jmp  .show

.div:
    test r14, r14
    jz   .zerodiv
    mov  rax, r12
    cqo
    idiv r14
    jmp  .show

.zerodiv:
    print msg_divzero, msg_divzero_len
    jmp  .ask

.show:
    push rax
    print msg_result, msg_result_len
    pop  rax
    call write_int
    print crlf, crlf_len

.ask:
    print msg_again, msg_again_len

    mov  rcx, [hIn]
    lea  rdx, [inbuf]
    mov  r8d, 8
    lea  r9,  [nRead]
    sub  rsp, 40
    push 0
    call ReadConsoleA
    add  rsp, 48

    movzx rax, byte [inbuf]
    or   al, 0x20           ; lowercase
    cmp  al, 'y'
    je   .mainloop

    print msg_bye, msg_bye_len

    add  rsp, 40
    pop  rbx
    pop  r15
    pop  r14
    pop  r13
    pop  r12

    xor  rcx, rcx
    call ExitProcess
