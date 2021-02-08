.equ UART,          0x1000  
.equ IO_BASE_ADDR,  0x10000000
.equ DATA_MASK,     0xff
.equ RVALID_MASK,   0x8000  
.equ STACK,         0x10000
.equ LED,           0x40

.org 0x20
RTI:
    # prólogo
    addi sp, sp, -12
    stw ra, (sp)
    stw r8, 4(sp)
    stw r9, 8(sp)
    ##########
    
    rdctl et, ipending
    beq et, r0, END_RTI         # não é interrupção do hardware

    subi ea, ea, 4          

    andi r8, et, 1              # máscara do temporizador
    movi r9, 1 
    bne r8, r9, END_RTI   

END_RTI:
    # epílogo
    ldw ra, (sp)  
    ldw r8, 4(sp)
    ldw r9, 8(sp)
    addi sp, sp, 12
eret


.global _start
_start:
    movia sp, STACK 
    mov fp, sp

    movia r5, IO_BASE_ADDR 
    mov r2, r0                      # resetar r2
    call PRINT_INSERT_COMMAND
    POLLING:
        movi r9, 0xa                # carrega ENTER em r9

        call READ_CHAR              
        mov r4, r2                  # carrega em r4 o retorno de READ_CHAR
        beq r0, r4, POLLING         # se r4 == 0, não leu nada
        call WRITE_CHAR             # escreve char na tela
        bne r9, r4, POLLING         # se não for ENTER, polling continua

        call COMMAND                # chama subrotina que trata os comandos
        mov r2, r0                  # resetar r2

        call PRINT_INSERT_COMMAND

        br POLLING

END:
    br END

READ_CHAR:
    # prólogo
    addi sp, sp, -16
    stw ra, (sp)
    stw r8, 4(sp)
    stw r9, 8(sp)
    stw r10, 12(sp)

    #############
    mov r2, r0              
    movia r8, RVALID_MASK  
    ldwio r9, UART(r5)              # carrega control register em r9
    and r9, r9, r8                  # obtém valor de RAVAIL
    beq r9, r0, END_READ_CHAR 
    #############

    movia r9, DATA_MASK             # carrega máscara de dados
    ldwio r8, UART(r5)              # carrega registrador de dados
    and r8, r8, r9                  # obtém apenas bits de dados
    movia r10, CHAR_BASE_ADDR       # carrega r10 com o endereço de memória onde os caracteres serão salvos
    ldw  r9, (r10)                  # carrega o offset
    addi r9, r9, 0x4                # incrementa o offset para proxima posição
    stw  r9, (r10)                  # atualiza o offset
    add  r10, r10, r9               # soma o offset ao endereço base
    stw  r8, (r10)                  # armazena o caractere na memoria
    mov r2, r8                      # retorno da função com o ultimo caractere lido
    
END_READ_CHAR:
    # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    ldw r9, 8(sp)
    ldw r10, 12(sp)
    addi sp, sp, 16
    ret 
    
COMMAND:
     # prólogo
    addi sp, sp, -20
    stw ra, (sp)
    stw r8, 4(sp)
    stw r9, 8(sp)
    stw r10, 12(sp)
    stw r11, 16(sp)
    
    movia r8, CHAR_BASE_ADDR                # carrega endereço de memória dos caracteres
    ldw r9, (r8)                            # carrega o offset
    movi r10, 0xc                           # valor para saber se o offset é valido
    blt r9, r10, END_COMMAND                # caso o offset menor que 12 (3 caractere) ainda não é considerado um comando
    
    stw r0, (r8)                            # zera o offset, preparando para as proximas chamadas
    
    ldw r9, 4(r8)                           # carrega o primeiro caractere
    slli r9, r9, 8                          # move dois bytes para esquerda (preparação para concatenação a seguir)
    ldw r10, 8(r8)                          # carrega o segundo caractere

    or r9, r10, r9                          # concatenação dos caracteres 
    
    movi r10, 0x3030                        # mascara para saber se o comando selecionado foi 00
    beq r9, r10, _COMMAND_00                # caso seja comando 00
    
    movi r10, 0x3031                        # mascara para saber se o comando selecionado foi 01
    beq r9, r10, _COMMAND_01                # caso seja comando 01
    
    movi r10, 0x3130                        # mascara para saber se o comando selecionado foi 10
    beq r9, r10, _COMMAND_10                # caso seja comando 10
    
    movi r10, 0x3230                        # mascara para saber se o comando selecionado foi 20
    beq r9, r10, _COMMAND_20                # caso seja comando 20
    
    movi r10, 0x3231                        # mascara para saber se o comando selecionado foi 21
    beq r9, r10, _COMMAND_21                # caso seja comando 21

    br END_COMMAND

    _COMMAND_00:
        call COMMAND_00
        br END_COMMAND
    _COMMAND_01:
        call COMMAND_01  
        br END_COMMAND 
    _COMMAND_10:
        call COMMAND_10
        br END_COMMAND
    _COMMAND_20:
        call COMMAND_20
        br END_COMMAND
    _COMMAND_21:
        call COMMAND_21


    END_COMMAND:
    # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    ldw r9, 8(sp)
    ldw r10, 12(sp)
    ldw r11, 16(sp)
    addi sp, sp, 20
    ret 




COMMAND_00:
     # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r8, 4(sp)
    
    
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    addi sp, sp, 8
    ret 


COMMAND_01:
     # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r8, 4(sp)
    
    
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    addi sp, sp, 8
    ret 

COMMAND_10:
     # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r8, 4(sp)
    
    
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    addi sp, sp, 8
    ret 

COMMAND_20:
     # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r8, 4(sp)
    
    
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    addi sp, sp, 8
    ret 

COMMAND_21:
     # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r8, 4(sp)
    
    
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    addi sp, sp, 8
    ret 

INVALID_COMMAND:
    # prólogo
    addi sp, sp, -4
    stw ra, (sp)
    
    # nothing to see here

    # epílogo
    ldw ra, (sp)
    addi sp, sp, 4
    ret 
    
    
PRINT_INSERT_COMMAND:
    # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r4, 4(sp)
    
    movia r4, 0x72746e45        # "Entr"
    call WRITE_CHAR  
    
    movia r4, 0x2065            # "e "
    call WRITE_CHAR

    movia r4, 0x206d6f63        # "com "
    call WRITE_CHAR   
    
    movia r4, 0x206d75            # "um"
    call WRITE_CHAR
    
    movia r4, 0x616d6f63        # "coma"
    call WRITE_CHAR 

    movia r4, 0x6e              # "n"
    call WRITE_CHAR

    movia r4, 0x203a6f64        # "do: "
    call WRITE_CHAR

    # epílogo
    ldw r4, 4(sp)
    ldw ra, (sp)
    addi sp, sp, 8
    ret 

WRITE_CHAR:
    # prólogo
    addi sp, sp, -12
    stw ra, (sp)
    stw r4, 4(sp)
    stw r8, 8(sp)
    #############
    WRITE_LOOP:
        beq r4, r0, END_WRITE_LOOP
        stwio r4, UART(r5)            
        srli r4, r4, 8
        br WRITE_LOOP
    END_WRITE_LOOP:
    # epílogo
    ldw ra, (sp)
    ldw r4, 4(sp)
    ldw r8, 8(sp)
    addi sp, sp, 12
    ret

.org 0x500
CHAR_BASE_ADDR:
    .word 0x0