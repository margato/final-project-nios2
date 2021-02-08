.equ UART,          0x1000  
.equ IO_BASE_ADDR,  0x10000000
.equ DATA_MASK,     0xff
.equ RVALID_MASK,   0x8000  
.equ STACK,         0x10000
.equ LED,			0x40

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

	POLLING:
        #ldwio r9, UART(r5)         # carrega control register em r9
        movia r9,0xa             # obtém valor de RVALID
		call READ_CHAR 
        bne r9, r2, POLLING        # se RVALID != 0, existe char na fila

        call Command             # chama subrotina que trata os comandos
		
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
		movia r8, RVALID_MASK          
		ldwio r9, UART(r5)         # carrega control register em r9
		and r9, r9, r8             # obtÃ©m valor de RVALID
		beq r9, r0, END_READ_CHAR        # se RVALID != 0, existe char 
		
			movia r9, DATA_MASK            # carrega máscara de dados
			ldwio r8, UART(r5)             # carrega registrador de dados
			and r8, r8, r9                 # obtém apenas bits de dados
			movia r10, CHAR_BASE_ADDR	   # Salva onde o caracteres estarão salvos
			ldw	 r9, (r10)				   #carrega o offset
			addi r9,r9,0x4				   #Incrementa o offset para proxima posição
			stw  r9, (r10)				   #atualiza o offset
			add  r10,r10,r9				   #Soma o offset ao endereço base
			stw  r8, (r10)				   #Armazena o caractere na memoria
			mov r2, r8					   #Retorno da função com o ultimo caractere lido
END_READ_CHAR:
    # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    ldw r9, 8(sp)
	ldw r10, 12(sp)
    addi sp, sp, 16
    ret
	
	
	
	
Command:
	 # prólogo
    addi sp, sp, -16
    stw ra, (sp)
    stw r8, 4(sp)
    stw r9, 8(sp)
	stw r10, 12(sp)
	
	
	movia r8, CHAR_BASE_ADDR	# Salva onde o caracteres estarão salvos
	ldw	 r9, (r8)				#carrega o offset
	movia r10,0xc				#Mascara para saber se o offset é valido
	bgt  r9,r10,INVALID_COMMAND	#Caso o offset seja maior que 12(3 caractere) se trata de um comando invalido
	
	mov  r9,r0					#Move zero para o offset
	stw  r9, (r8)				#zera o offset, o preparando para as proximas chamadas
	
	ldw	 r9, 4(r8)				#Carrega o primeiro caractere
	slli r9,r9,8				#Move dois bytes para esquerda(preparação para concatenação a seguir)
	ldw	 r10, 8(r8) 			#Carrega o segundo caractere
	or	 r9,r10,r9				#concatenação dos caracteres
	
	movia r10,0x3030			#Mascara para saber se o comando selecionado foi 00
	beq	r9,r10,COMMAND_00		#Caso seja comando 00
	
	movia r10,0x3031			#Mascara para saber se o comando selecionado foi 01
	beq	r9,r10,COMMAND_01		#Caso seja comando 01
	
	movia r10,0x3130			#Mascara para saber se o comando selecionado foi 10
	beq	r9,r10,COMMAND_10		#Caso seja comando 10
	
	movia r10,0x3230			#Mascara para saber se o comando selecionado foi 20
	beq	r9,r10,COMMAND_20		#Caso seja comando 20
	
	movia r10,0x3231			#Mascara para saber se o comando selecionado foi 21
	beq	r9,r10,COMMAND_20		#Caso seja comando 21


		
	 # epílogo
    ldw ra, (sp)
    ldw r8, 4(sp)
    ldw r9, 8(sp)
	ldw r10, 12(sp)
    addi sp, sp, 16
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
	ret

WRITE_CHAR:
    # prólogo
    addi sp, sp, -8
    stw ra, (sp)
    stw r4, 4(sp)
    #############

    stwio r4, UART(r5)             # carrega r8 no registrador de dados

    # epílogo
    ldw ra, (sp)
    ldw r4, 4(sp)
    addi sp, sp, 8
    ret

.org 0x500
CHAR_BASE_ADDR:
	.word 0x0


	
	
	
	
	
	
	