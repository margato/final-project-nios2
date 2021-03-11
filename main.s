    .equ UART,              0x1000  
    .equ IO_BASE_ADDR,      0x10000000
    .equ TIMER,             0x2000
    .equ DATA_MASK,         0xff
    .equ RVALID_MASK,       0x8000  
    .equ STACK,             0x10000
    .equ LED,               0x40
    .equ _2021,             0x5b3f5b06
    .equ HEX3to0,           0x20
    .equ HEX7to3,           0x30
    .equ PUSH_BUTTON_MASK,  0x50
    .equ INTERRUPTION_MASK, 0x58
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

        andi r8, et, 0b11           # máscara do timer

        movi r9, 1 
        beq r8, r9, _HANDLE_INTERRUPTION_LED
        br END_RTI
        _HANDLE_INTERRUPTION_LED:
            call HANDLE_INTERRUPTION_LED
        
        call HANDLE_INTERRUPTION_2021
        call HANDLE_KEY1_PRESS
        call HANDLE_KEY2_PRESS


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

        movi r10, 0x8                   # máscara para bit 3
        stwio r10, INTERRUPTION_MASK+4(r5)

        movia r10, 25000000             # 25*10^6 = 500ms

        andi r17, r10, 0xFFFF           # parte baixa (16 bits inferiores)
        stwio r17, TIMER+8(r5)          # configura parte baixa do timer

        srli r17, r10, 16               # parte alta (16 bits superiores)
        stwio r17, TIMER+12(r5)         # configura parte alta do timer

        movi r10, 3
        wrctl ienable, r10              # habilitar timer no ienable
        movi r10, 1
        wrctl status, r10               # habilitar o PIE no status

        movi r10, 0b111                 # configuração do timer
        stwio r10, TIMER+4(r5)          # salva configuração do timer

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
        addi sp, sp, -24
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r11, 16(sp)
        stw r4, 16(sp)
        
        movia r8, CHAR_BASE_ADDR                # carrega endereço de memória dos caracteres
        ldw r9, (r8)                            # carrega o offset
        movi r10, 0xc                           # valor para saber se o offset é valido
        blt r9, r10, _INVALID_COMMAND           # caso o offset menor que 12 (3 caractere) ainda não é considerado um comando
        
        stw r0, (r8)                            # zera o offset, preparando para as proximas chamadas
        
        ldw r9, 4(r8)                           # carrega o primeiro caractere
        slli r9, r9, 8                          # move dois bytes para esquerda (preparação para concatenação a seguir)
        ldw r10, 8(r8)                          # carrega o segundo caractere
        ldw r11, 12(r8)                         # carrega o terceiro caractere

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

        br _INVALID_COMMAND


        _COMMAND_00:
            movi r9, 0x20                           # carrega ESPAÇO em r9                
            bne r11, r9, _INVALID_COMMAND           # se o terceiro char não for ESPAÇO: comando inválido

            mov r4, r8                            
            addi r4, r4, 16                         # define como argumento do comando o endereço do primeiro argumento

            call COMMAND_00
            br END_COMMAND
        _COMMAND_01:
            movi r9, 0x20                           # carrega ESPAÇO em r9                
            bne r11, r9, _INVALID_COMMAND           # se o terceiro char não for ESPAÇO: comando inválido

            mov r4, r8                            
            addi r4, r4, 16                         # define como argumento do comando o endereço do primeiro argumento

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
            br END_COMMAND

        _INVALID_COMMAND:
            call INVALID_COMMAND

        END_COMMAND:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        ldw r11, 16(sp)
        ldw r4, 20(sp)
        addi sp, sp, 24
        ret 

    HANDLE_COMMAND_LEDS_ARGUMENT:
        # prólogo
        addi sp, sp, -20
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r11, 16(sp)

        ldw r8, (r4)                                          # carrega primeiro número do argumento
        andi r8, r8, 0xF                                      # obtém apenas número

        movi r10, 0
        blt r8, r10, INVALID_ARGUMENT_FOUND_COMMAND_00        # se for < 0, r8 = -1
        movi r10, 9
        bgt r8, r10, INVALID_ARGUMENT_FOUND_COMMAND_00        # se for > 9, r8 = -1
        
        ldw r9, 4(r4)                                         # carrega segundo número do argumento
        andi r9, r9, 0xF                                      # obtém apenas número 

        movi r10, 0
        blt r9, r10, END_HANDLE_COMMAND_00_ARGUMENT           # se for < 0, zera r9
        movi r10, 8
        bgt r9, r10, INVALID_ARGUMENT_FOUND_COMMAND_00        # se for > 9, zera r9
        
        movi r11, 0xa
        ldw r10, 8(r4)                                        # valida ENTER
        bne r10, r11, INVALID_ARGUMENT_FOUND_COMMAND_00

        br PREPARE_RETURN_OF_ARGUMENT

        INVALID_ARGUMENT_FOUND_COMMAND_00:
            movi r10, 0xa
            beq r9, r10, END_HANDLE_COMMAND_00_ARGUMENT
            movi r8, -1
            br END_HANDLE_COMMAND_00_ARGUMENT

        PREPARE_RETURN_OF_ARGUMENT:
            movi r10, 1
            bne r8, r10, INVALID_ARGUMENT_FOUND_COMMAND_00
            movi r8, 0xa
            add r8, r8, r9

        END_HANDLE_COMMAND_00_ARGUMENT:
            mov r2, r8
        
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
        addi sp, sp, -16
        stw ra, (sp)
        stw r2, 4(sp)
        stw r8, 8(sp)
        stw r9, 12(sp)

        call HANDLE_COMMAND_LEDS_ARGUMENT
        movi r8, -1

        beq r8, r2, INVALID_ARGUMENT_COMMAND_00     # se HANDLE_COMMAND_LEDS_ARGUMENT retornar -1: argumento inválido

        mov r4, r2
        call TURN_ON_NTH_LED

        br END_COMMAND_00
        INVALID_ARGUMENT_COMMAND_00:
            call PRINT_INVALID_COMMAND
            br END_COMMAND_00

        END_COMMAND_00:    
        # epílogo
        ldw ra, (sp)
        ldw r2, 4(sp)
        ldw r8, 8(sp)
        ldw r9, 12(sp)
        addi sp, sp, 16
        ret 

    HANDLE_INTERRUPTION_LED: 
        # prólogo
        addi sp, sp, -12
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)

        stwio r0, TIMER(r5)             # reseta interrupção no detector de borda
        
        #LED_BASE_ADDR
        movi r9, LED_BASE_ADDR          # carrega endereço dos leds em r10
        ldw r8, (r9)                    # carrega leds que devem ser acesos (memória)
        ldwio r9, (r5)                  # carrega leds acesos atualmente

        beq r9, r0, TURN_ON_LEDS        # se led apagado, acende
        TURN_OFF_LEDS:
            stwio r0, (r5)              # apaga leds
            br _END_HANDLE_INTERRUPTION_LED
        TURN_ON_LEDS:
            stwio r8, (r5)              # acende leds

    _END_HANDLE_INTERRUPTION_LED:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        addi sp, sp, 12
        ret   

    TURN_ON_NTH_LED: # arg: n = r4
        # prólogo
        addi sp, sp, -20
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r4, 16(sp)
        
        movi r8, 0x1                    # carrega 0x1 em r8
        subi r4, r4, 1                  # subtraí de r4, uma vez que começa de 0 a N led
        sll r8, r8, r4                  # move o bit [r4] - 1 vezes para esquerda. por exemplo: r4 = 4, então r8 = 0x1000

        movi r10, LED_BASE_ADDR         # carrega endereço dos leds em r10
        ldw r9, (r10)

        or r9, r9, r8                   # concatenar leds 

        stw r9, (r10)                   # salva leds

        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        ldw r4, 16(sp)
        addi sp, sp, 20
        ret 

    TURN_OFF_NTH_LED: # arg: n = r4
        # prólogo
        addi sp, sp, -24
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r11, 16(sp)
        stw r4, 20(sp)
        
        movi r8, 0x1                        # carrega 0x1 em r8
        subi r4, r4, 1                      # subtraí de r4, uma vez que começa de 0 a N led
        sll r8, r8, r4                      # move o bit [r4] - 1 vezes para esquerda. por exemplo: r4 = 4, então r8 = 0x1000

        movi r10, LED_BASE_ADDR             # carrega endereço dos leds em r10
        ldw r9, (r10)

        mov r11, r9                         # carrega leds salvo na memória
        srl r11, r11, r4                     
        andi r11, r11, 0x1                  # pega bit que está sendo desligado

        beq r11, r0, _END_TURN_OFF_NTH_LED  # se bit for 0, finaliza

        xor r9, r9, r8                      # concatenar leds 
        stw r9, (r10)                       # salva leds

    _END_TURN_OFF_NTH_LED:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        ldw r11, 16(sp)
        ldw r4, 20(sp)
        addi sp, sp, 24
        ret 

    COMMAND_01:
        # prólogo
        addi sp, sp, -16
        stw ra, (sp)
        stw r2, 4(sp)
        stw r8, 8(sp)
        stw r9, 12(sp)

        call HANDLE_COMMAND_LEDS_ARGUMENT
        movi r8, -1

        beq r8, r2, INVALID_ARGUMENT_COMMAND_01     # se HANDLE_COMMAND_LEDS_ARGUMENT retornar -1: argumento inválido

        mov r4, r2
        call TURN_OFF_NTH_LED

        br END_COMMAND_01
        INVALID_ARGUMENT_COMMAND_01:
            call PRINT_INVALID_COMMAND
            br END_COMMAND_01

        END_COMMAND_01:    
        # epílogo
        ldw ra, (sp)
        ldw r2, 4(sp)
        ldw r8, 8(sp)
        ldw r9, 12(sp)
        addi sp, sp, 16
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
        addi sp, sp, -20
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r11, 16(sp)
        
        
        movia r10, CURRENT_2021 

        ldw r8, (r10)                       # carrega 2021 da memória em r8
        beq r8, r0, LOAD_DEFAULT_2021       # se r8 == 0, então deve carregar valor inicial: 2021, senão, carrega valor atual de 2021 (por ex: 0212)
        br SAVE_2021_IN_MEMORY
        LOAD_DEFAULT_2021:
            movia r8, _2021                 # carrega 2021 em r8
        SAVE_2021_IN_MEMORY:
        stwio r8, HEX3to0(r5)               # carrega 2021 no hex
        stw r8, (r10)                       # salva 2021 na memória

        movia r11, SEGMENT_DISPLAY_STATE    # carrega em r11 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r9, (r11)                       # carrega estado atual
        movi r10, 0b11                      # estado inicial: rotacionando para direita
        or r9, r9, r10                      # concatena bits de estado

        stw r9, (r11)                       # salva estado na memória
        
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        ldw r11, 16(sp)
        addi sp, sp, 20
        ret 

    TOGGLE_2021_ROTATION:
        addi sp, sp, -12
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)

        movia r9, SEGMENT_DISPLAY_STATE                # carrega em r10 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r8, (r9)                                   # carrega estado atual

        xori r8, r8, 0b1                               # inverte bit de rotação
        stw r8, (r9)

    _END_TOGGLE_2021_ROTATION:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        addi sp, sp, 12
        ret   

    TOGGLE_2021_DIRECTION:
        addi sp, sp, -12
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)

        movia r9, SEGMENT_DISPLAY_STATE                # carrega em r10 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r8, (r9)                                   # carrega estado atual

        xori r8, r8, 0b10                              # inverte bit de direção
        stw r8, (r9)

    _END_TOGGLE_2021_DIRECTION:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        addi sp, sp, 12
        ret   

    HANDLE_KEY1_PRESS:
        # prólogo
        addi sp, sp, -12
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)

        ldwio r8, PUSH_BUTTON_MASK+12(r5)               # le a flag status

        andi r8, r8, 0x2                                # checa se KEY1 foi pressionado
        beq r8, r0, _END_HANDLE_KEY1_PRESS              # finaliza tratamento caso falso
        movi r8, 2
        stwio r8, PUSH_BUTTON_MASK+12(r5)               # limpar captura de borda de KEY1

        movia r9, SEGMENT_DISPLAY_STATE                 # carrega em r9 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r8, (r9)                                    # carrega estado atual

        _KEY1_PRESS:
            andi r9, r8, 0b1                            # carrega bit que indica se está rotacionando
            beq r9, r0, _END_HANDLE_KEY1_PRESS          # caso bit == 0, finaliza tratamento de interrupção
            call TOGGLE_2021_DIRECTION

    _END_HANDLE_KEY1_PRESS:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        addi sp, sp, 12
        ret     


    HANDLE_KEY2_PRESS:
        # prólogo
        addi sp, sp, -12
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)

        ldwio r8, PUSH_BUTTON_MASK+12(r5)               # le a flag status

        andi r8, r8, 0x4                                # checa se KEY2 foi pressionado
        beq r8, r0, _END_HANDLE_KEY2_PRESS              # finaliza tratamento caso falso
        movi r8, 4
        stwio r8, PUSH_BUTTON_MASK+12(r5)               # limpar captura de borda de KEY2

        movia r9, SEGMENT_DISPLAY_STATE                 # carrega em r9 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r8, (r9)                                    # carrega estado atual

        _KEY2_PRESS:
            call TOGGLE_2021_ROTATION

    _END_HANDLE_KEY2_PRESS:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        addi sp, sp, 12
        ret    

    HANDLE_INTERRUPTION_2021: 
        # prólogo
        addi sp, sp, -28
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        stw r11, 16(sp)
        stw r12, 20(sp)
        stw r13, 24(sp)

        stwio r0, TIMER(r5)                             # reseta interrupção no detector de borda
        
        movia r10, SEGMENT_DISPLAY_STATE                # carrega em r10 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r9, (r10)                                   # carrega estado atual

        andi r8, r9, 0b1                                # carrega bit que indica se está rotacionando
        beq r8, r0, _END_HANDLE_INTERRUPTION_2021       # caso bit == 0, finaliza tratamento de interrupção

        srli r8, r9, 1                                  # carrega segundo bit que indica direção da rotação
        andi r8, r8, 0b1                                # obtém apenas bit de direção

        movia r10, CURRENT_2021                           
        ldw r11, 4(r10)                                   # carrega valor atual de 2021 na memória HEX7-4
        ldw r9, (r10)                                   # carrega valor atual de 2021 na memória HEX3-0
        movi r10, 8                                     
        # 0: left, 1: right 
        movia r13, 0xFF000000
        beq r8, r0, LEFT_2021

        RIGHT_2021:
            andi r12, r9, 0xFF                          # pega o ultimo numero HEX3-0
            slli r12, r12, 24                           # shift left ultimo numero 
            andi r8, r11, 0xFF                          # pega o ultimo numero HEX7-4
            srl r11, r11, r10                           # shift right HEX7-4
            or r11, r11, r12                            # concatena 
            srl r9, r9, r10                             # shift right HEX7-4
            slli r8, r8, 24                             # shift left ultimo numero
            or r9, r9, r8                               # concatena 
            br _SAVE_2021
        LEFT_2021:
            and r12, r9, r13                            # pega o primeiro numero HEX3-0
            srli r12, r12, 24                           # shift right primeiro numero
            and r8, r11, r13                            # pega o primeiro numero HEX7-4
            sll r11, r11, r10                           # shift left HEX7-4
            or r11, r11, r12                            # concatena 
            sll r9, r9, r10                             # shift right HEX7-4
            srli r8, r8, 24                             # shift right ultimo numero
            or r9, r9, r8                               # concatena
        _SAVE_2021:
            movia r10, CURRENT_2021
            stw r9, (r10)                               # salva 2021 atual na memória
            stw r11, 4(r10)                             # salva 2021 atual na memória
            stwio r9, HEX3to0(r5)                       # carrega 2021 atual no display
            stwio r11, HEX7to3(r5)                      # carrega 2021 atual no display

    _END_HANDLE_INTERRUPTION_2021:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        ldw r11, 16(sp)
        ldw r12, 20(sp)
        ldw r13, 24(sp)
        addi sp, sp, 28
        ret  

    COMMAND_21:
        # prólogo
        addi sp, sp, -16
        stw ra, (sp)
        stw r8, 4(sp)
        stw r9, 8(sp)
        stw r10, 12(sp)
        
        movia r10, SEGMENT_DISPLAY_STATE    # carrega em r8 o endereço de memória de SEGMENT_DISPLAY_STATE
        ldw r9, (r10)                       # carrega estado atual
        andi r8, r9, 0b1                    # obtém bit de rotação
        beq r8, r0, _END_COMMAND_21         # se não estiver rotacionando, finaliza comando 21

        xori r9, r9, 0b1                    # caso esteja rotacionando, seta como 0 para não rotacionar
        stw r9, (r10)                       # salva estado na memória
    _END_COMMAND_21:
        # epílogo
        ldw ra, (sp)
        ldw r8, 4(sp)
        ldw r9, 8(sp)
        ldw r10, 12(sp)
        addi sp, sp, 16
        ret 

    INVALID_COMMAND:
        # prólogo
        addi sp, sp, -4
        stw ra, (sp)
        
        call PRINT_INVALID_COMMAND

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
        
        movia r4, 0x206d75          # "um"
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

    PRINT_INVALID_COMMAND:
        # prólogo
        addi sp, sp, -8
        stw ra, (sp)
        stw r4, 4(sp)
        
        movia r4, 0x616d6f43        # "Coma"
        call WRITE_CHAR   

        movia r4, 0x6e              # "n"
        call WRITE_CHAR

        movia r4, 0x69206f64        # "do i"
        call WRITE_CHAR

        movia r4, 0x6ce1766e        # "nvál"
        call WRITE_CHAR

        movia r4, 0x6f6469          # "ido"
        call WRITE_CHAR   
        
        movia r4, 0x0a0a            # "ENTERENTER"
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


    SEGMENT_DISPLAY_STATE:
    /**
        bits representam estado

        0b00000000
                ba

        a = is_rotating
        b = left or right => 0: left, 1: right 
    **/
        .word 0x0
    CURRENT_2021:
        .word 0x0
        .word 0x0
    LED_BASE_ADDR:
        .word 0x0
    CHAR_BASE_ADDR:
        .word 0x0