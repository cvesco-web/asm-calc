; ============================================================
;  calc_linux.asm  –  Console calculator for Linux x86-64
;  Assemble : nasm -f elf64 calc_linux.asm -o calc_linux.o
;  Link     : ld calc_linux.o -o calc_linux
; ============================================================

bits 64
default rel

section .data

msg_banner      db  "================================", 10
                db  "   Assembly Calculator v1.0     ", 10
                db  "================================", 10
msg_banner_len  equ $ - msg_banner

msg_prompt      db  10, "Expression (e.g. 25 + 7, 100 / 4): "
msg_prompt_len  equ $ - msg_prompt

msg_result      db  "= "
msg_result_len  equ $ - msg_result

msg_again       db  10, "Calculate again? (y/n): "
msg_again_len   equ $ - msg_again

msg_divzero     db  "Error: division by zero", 10
msg_divzero_len equ $ - msg_divzero

msg_badop       db  "Error: use + - * /", 10
msg_badop_len   equ $ - msg_badop

msg_bye         db  "Goodbye!", 10
msg_bye_len     equ $ - msg_bye

newline         db  10
newline_len     equ 1

section .bss

inbuf       resb 128
digbuf      resb 34

section .text
global _start

; ----------------------------------------------------------------
; sys_write: rdi=buf, rsi_len=count
; ----------------------------------------------------------------
sys_write:
    ; args: rdi=buf, rsi=len
    mov  rax, 1         ; sys_write
    mov  rdx, rsi       ; count
    mov  rsi, rdi       ; buf
    mov  rdi, 1         ; stdout
    syscall
    ret

; ----------------------------------------------------------------
; sys_read: reads into inbuf, returns bytes read in rax
; ----------------------------------------------------------------
sys_read:
    mov  rax, 0         ; sys_read
    mov  rdi, 0         ; stdin
    lea  rsi, [inbuf]
    mov  rdx, 127
    syscall
    ret

; ----------------------------------------------------------------
; print macro: label, length
; ----------------------------------------------------------------
%macro print 2
    lea  rdi, [%1]
    mov  rsi, %2
    call sys_write
%endmacro

; ----------------------------------------------------------------
; write_int  –  print signed 64-bit integer in rax
; ----------------------------------------------------------------
write_int:
    push rbx
    push r12

    lea  r12, [digbuf + 33]
    mov  byte [r12], 0
    xor  rbx, rbx           ; negative flag

    test rax, rax
    jns  .positive
    neg  rax
    mov  rbx, 1
.positive:
    mov  r10, 10
.extract:
    xor  rdx, rdx
    div  r10
    add  dl, '0'
    dec  r12
    mov  [r12], dl
    test rax, rax
    jnz  .extract

    test rbx, rbx
    jz   .no_minus
    dec  r12
    mov  byte [r12], '-'
.no_minus:
    ; compute length
    lea  rax, [digbuf + 33]
    sub  rax, r12

    mov  rdi, r12       ; buf
    mov  rsi, rax       ; len
    call sys_write

    pop  r12
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
; parse_int  –  parse signed decimal at rsi, returns value in rax
; ----------------------------------------------------------------
parse_int:
    call skip_spaces
    xor  rax, rax
    xor  r11, r11
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
_start:
    print msg_banner, msg_banner_len

.mainloop:
    print msg_prompt, msg_prompt_len

    call sys_read

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
    print newline, newline_len

.ask:
    print msg_again, msg_again_len

    call sys_read

    movzx rax, byte [inbuf]
    or   al, 0x20           ; lowercase
    cmp  al, 'y'
    je   .mainloop

    print msg_bye, msg_bye_len

    ; exit(0)
    mov  rax, 60
    xor  rdi, rdi
    syscall
