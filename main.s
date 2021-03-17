.equ UART,          0x1000  
.equ IO_BASE_ADDR,  0x10000000
.equ DATA_MASK,     0xff
.equ RVALID_MASK,   0x8000  
.equ STACK,         0x10000
.equ SWITCHES,      0x40
.equ DISPLAY,       0x20


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
        call COMMAND_01  
        br END_COMMAND 
    _COMMAND_10:
		ldwio	r11,	SWITCHES(r5)  #Carrega os valores contidos no switch
		movi    r9, 0xFF			  #Movendo 255 para teste
		bgt     r11, r9, _INVALID_COMMAND #Caso o valor seja maior que 255 (8 bits) comando invalido
		
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

HANDLE_COMMAND_00_ARGUMENT:
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

    call HANDLE_COMMAND_00_ARGUMENT
    movi r8, -1

    beq r8, r2, INVALID_ARGUMENT_COMMAND_00     # se HANDLE_COMMAND_00_ARGUMENT retornar -1: argumento inválido

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

TURN_ON_NTH_LED: # arg: n = r4
     # prólogo
    addi sp, sp, -12
    stw ra, (sp)
    stw r8, 4(sp)
    stw r4, 8(sp)
    
    movi r8, 0x1
    subi r4, r4, 1
    sll r8, r8, r4
    stwio r8, (r5)                              # acende led

     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    ldw r4, 8(sp)
    addi sp, sp, 12
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
    addi sp, sp, -12
    stw ra, (sp)
    stw r7, 4(sp)
	stw r8, 8(sp)
    
	ldwio	r7,	SWITCHES(r5)  #Carrega os valores contidos no switch
	
	mov		r8, r7			  #Salva valor de n para ser usado no numero triangular
	addi	r7, r7, 0x1		  #n + 1
	mul		r7, r8, r7		  #n(n + 1) 
	movi	r8, 0x2			  #prepara a div por 2
	div		r7, r7, r8		  #(n(n + 1))/2
	
    mov  	r4, r7			  #Prepara o argumento pro decoder
	call	DECODER			  #Chama a função de decodificação
     # epílogo
    ldw ra, (sp)
    ldw r7, 4(sp)
    ldw r8, 8(sp)
    addi sp, sp, 12
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


DECODER:
	addi sp, sp, -32
    stw ra, (sp)
    stw r8, 4(sp)
	stw r9, 8(sp)
	stw r10, 12(sp)
	stw r11, 16(sp)
	stw r12, 20(sp)
	stw r13, 24(sp)
	stw r14, 28(sp)

	mov		r11,r4					#Move o valor do(s) switche(s) para r11
	movia 	r13,0x0					#Zera r13
	movi	r14,-8					#Inicializa na posição -8
	br		FOR_COND				#Pula para condição do FOR	(r11!=0)
	FOR_LOOP:
		movia 	r9,0xF				#Mascara para separar os ultimos quatro bits
		and	  	r9,r11,r9			#Aplicação da mascara
		Switch:						#Switch para saber qual segmento preencher
			addi	r14,r14,8		#Acumulador para localziar a posição do digito
			movia	r8,0x3f			#Move o codigo do segmento referente ao numero 0
			beq		r9,r0,FOR_END

			movia	r8,0x6			#Move o codigo do segmento referente ao numero 1
			movia	r10,0x1			#Move o numero 1 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x5b			#Move o codigo do segmento referente ao numero 2
			movia	r10,0x2			#Move o numero 2 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x4f			#Move o codigo do segmento referente ao numero 3
			movia	r10,0x3			#Move o numero 3 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x66			#Move o codigo do segmento referente ao numero 4
			movia	r10,0x4			#Move o numero 4 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x6d			#Move o codigo do segmento referente ao numero 5
			movia	r10,0x5			#Move o numero 5 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x7d			#Move o codigo do segmento referente ao numero 6
			movia	r10,0x6			#Move o numero 6 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x7			#Move o codigo do segmento referente ao numero 7
			movia	r10,0x7			#Move o numero 7 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x7F			#Move o codigo do segmento referente ao numero 8
			movia	r10,0x8			#Move o numero 8 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x6F			#Move o codigo do segmento referente ao numero 9
			movia	r10,0x9			#Move o numero 9 para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x77			#Move o codigo do segmento referente ao numero A
			movia	r10,0xa			#Move o numero A para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x7F			#Move o codigo do segmento referente ao numero B
			movia	r10,0xb			#Move o numero B para fazer a comparação
			beq		r9,r10,FOR_END
	
			movia	r8,0x39			#Move o codigo do segmento referente ao numero C
			movia	r10,0xc			#Move o numero C para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x3F			#Move o codigo do segmento referente ao numero D
			movia	r10,0xd			#Move o numero D para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x79			#Move o codigo do segmento referente ao numero E
			movia	r10,0xe			#Move o numero E para fazer a comparação
			beq		r9,r10,FOR_END

			movia	r8,0x71			#Move o codigo do segmento referente ao numero F
			movia	r10,0xf			#Move o numero F para fazer a comparação
		
	FOR_END:
		srli    r11,r11,0x4			#Descarta os 4 bits já codificados
		mov		r12,r8				#Salva o segmento do número atual
		sll		r12,r12,r14			#Caminha para o endereço corresponte do digito
		or		r13,r13,r12			#Concatena o segmento anterior com o atual
	FOR_COND:
		bne		r11,r0,FOR_LOOP		#Condição do FOR (r11!=0)
		stwio	r13,DISPLAY(r5)		#Carrega o(s) valores do segmento(s) para o endereço correto
	
	
     # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
	ldw r9, 8(sp)
	ldw r10, 12(sp)
	ldw r11, 16(sp)
	ldw r12, 20(sp)
	ldw r13, 24(sp)
	ldw r14, 28(sp)
    addi sp, sp, 32
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

    movia r4, 0x6ce1766e       # "nvál"
    call WRITE_CHAR

    movia r4, 0x6f6469       # "ido"
    call WRITE_CHAR   
    
    movia r4, 0x0a0a       # "ENTERENTER"
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


CHAR_BASE_ADDR:
    .word 0x0