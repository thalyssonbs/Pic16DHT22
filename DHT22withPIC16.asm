
; PIC16F877A Configuration Bit Settings

; Assembly source line config statements

#include "p16f877a.inc"

; CONFIG
; __config 0x3F3A
 __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

#DEFINE	    BANCO0	    BCF STATUS,RP0	;   Acessa o Banco 0
#DEFINE	    BANCO1	    BSF STATUS,RP0	;   Acessa o Banco 1
#DEFINE	    COMANDAR_LCD    BCF PORTB,RB0	;   Enviar comandos ao LCD
#DEFINE	    ESCREVER_LCD    BSF PORTB,RB0	;   Enviar caracteres ao LCD
#DEFINE	    ENABLE		PORTB,RB1	;   Conexão com o pino EN do LCD
#DEFINE	    LCD			PORTD		;   Conexão de dados com o LCD
#DEFINE	    DHT_PIN		PORTB,RB5	;   Conexão de dados com o DHT
#DEFINE	    DHT_DIR		TRISB,5		;   Direção de dados com o DHT

;--------------------------------------------------------;
;********************************************************;
;------------ REGISTRADORES DE USO GERAL ----------------;
CBLOCK	0x20
;-----DELAY_MS------;
    TEMPO0	    ;	(0x20)
    TEMPO1	    ;	(0x21)
;-------------------;
;---Bytes do DHT----;
    UMID_HI	    ;	(0x22) MSB da leitura de Umidade
    UMID_LO	    ;	(0x23) LSB da leitura de Umidade
    TEMP_HI	    ;	(0x24) MSB da leitura de Temperatura
    TEMP_LO	    ;	(0x25) LSB da leitura de Temperatura
;-------------------;
;----Leitura DHT----;
    CONTADOR	    ;	(0x26) Contador para leitura serial
    BYTE_DHT	    ;	(0x27) Byte usado durante a leitura
    CHKS	    ;	(0x28) Checksum para verificação de erros
;-------------------;
;-Rotina de Divisão-;
    QHI		    ;	(0x29) MSB do quociente da divisão
    QLO		    ;	(0x2A) LSB do quociente da divisão
    DDHI	    ;	(0x2B) MSB do dividendo da divisão
    DDLO	    ;	(0x2C) LSB do dividendo/resto da divisão
;-------------------;
;--Dígitos Finais---;
    UMID_CEN	    ;	(0x2D) Centena da Umidade Relativa
    UMID_DEZ	    ;	(0x2E) Dezena da Umidade Relativa
    UMID_UNI	    ;	(0x2F) Unidade da Umidade Relativa
    UMID_DEC	    ;	(0x30) Decimal da Umidade Relativa
    TEMP_SIN	    ;	(0x31) Sinal da Temperatura
    TEMP_DEZ	    ;	(0x32) Dezena da Temperatura
    TEMP_UNI	    ;	(0x33) Unidade da Temperatura
    TEMP_DEC	    ;	(0x34) Decimal da Temperatura
;-------------------;
ENDC

;--------------------------------------------------------;
;********************************************************;
;-------------- VETOR DE INTERRUPCAO --------------------;
ORG 0x00
GOTO SETUP

;--------------------------------------------------------;
;********************************************************;
;------------ CONFIGURACOES DO PROGRAMA -----------------;
SETUP
    BANCO1		    ;
    CLRF    TRISD	    ;	Configura PORTD inteiro como saída
    BCF	    TRISB,RB0	    ;	Configura o bit 0 de PORTB como saída
    BCF	    TRISB,RB1	    ;	Configura o bit 1 de PORTB como saída
;-----Configura o TIMER0----;
    MOVLW   H'0F'	    ;	Configuração [0000 1111]
			    ;	<5> Contagem dos pulsos de Clock
			    ;	<4> Incremento pela borda de descida
			    ;	<3> Pré-escalador atribuído ao WDT
    MOVWF   OPTION_REG	    ;
;---------------------------;
    BANCO0		    ;
;-----Configura o TIMER1----;
    MOVLW   H'30'	    ;	Configuração [0011 0000]
			    ;	<5-4> Pré-escalador 1:8
			    ;	<3>   Oscilador desligado
			    ;	<2>   Sincronizado com clock externo
			    ;	<1>   Clock interno
			    ;	<0>   TIMER1 parado
    MOVWF   T1CON	    ;
;---------------------------;
    CLRF    PORTD	    ;	Limpa toda a saída PORTD
    CALL    DELAY_500MS	    ;	Aguarda 500ms para energização
    GOTO    LCD_CONFIG	    ;	Inicia a configuração do display LCD

;--------------------------------------------------------;
;********************************************************;
;--------------- CONFIGURACAO DO LCD --------------------;
LCD_CONFIG
    COMANDAR_LCD	    ;
;------Function Set---------;
    MOVLW   H'38'	    ;	Comando [0011 1000]
			    ;	<4> Barramento de 8 bits
			    ;	<3> Modo de duas linhas
			    ;	<2> Caractere de 5x8 pontos
    CALL    ESCREVE	    ;
;---------------------------;
;------Modo de Entrada------;
    MOVLW   H'06'	    ;	Comando [0000 0110]
			    ;	<1> Cursor move-se à direita
			    ;	<0> Deslocamento do display OFF
    CALL    ESCREVE	    ;
;---------------------------;
;------Display ON/OFF-------;
    MOVLW   H'0C'	    ;	Comando [0000 1100]
			    ;	<2> Display ligado
			    ;	<1> Cursor invisível
			    ;	<0> Cursor intermitente OFF
    CALL    ESCREVE	    ;
;---------------------------;
;------Limpar Display-------;
    MOVLW   H'01'	    ;	Comando [0000 0001]
    CALL    ESCREVE	    ;
;---------------------------;
;-----Posição do Cursor-----;
    MOVLW   H'80'	    ;	Comando [1000 0000]
    CALL    ESCREVE	    ;	Posição (1,1)
;---------------------------;
    CALL    MSG_INICIO	    ;	Imprime uma mensagem de boas vindas por 3s
    CALL    TEXTOS	    ;	Imprime os textos padrão
    GOTO    LOOP	    ;

;--------------------------------------------------------;
;********************************************************;
;-------------------- LAÇO INFINITO ---------------------;
LOOP
    CALL    LER_DHT	    ;	Lê e formata os dados do DHT
;---------------------------;
;-- Cursor na pos (1,11) ---;
    COMANDAR_LCD	    ;	Prepara para enviar comandos ao LCD
    MOVLW   H'8B'	    ;	Comando LCD -> Cursor na posição (1,11)
    CALL    ESCREVE	    ;	Envia o comando ao LCD
    ESCREVER_LCD	    ;	Prepara para enviar caracteres ao LCD
;---------------------------;
;-- Escreve a Temperatura --;
    MOVF    TEMP_SIN,W	    ;	Coleta o sinal da temperatura lida (+/-)
    CALL    ESCREVE	    ;	Envia o caractere ao LCD (WREG -> LCD)
    MOVF    TEMP_DEZ,W	    ;	Coleta o primeiro dígito da temperatura (dezena)
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    TEMP_UNI,W	    ;	Coleta o segundo dígito da temperatura (unidade)
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVLW   ','		    ;	Coleta o caractere ','
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    TEMP_DEC,W	    ;	Coleta o terceiro dígito da temperatura (decimal)
    CALL    ESCREVE	    ;	WREG -> LCD
;---------------------------;
;-- Cursor na pos (2,11) ---;
    COMANDAR_LCD	    ;	Prepara para enviar comandos ao LCD
    MOVLW   H'CB'	    ;	Comando LCD -> Cursor na posição (2,11)
    CALL    ESCREVE	    ;	Envia o comando ao LCD
    ESCREVER_LCD	    ;	Prepara para enviar caracteres ao LCD
;---------------------------;
;---- Escreve a Umidade ----;
    MOVF    UMID_CEN,W	    ;	Coleta o primeiro dígito da umidade (centena)
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_DEZ,W	    ;	Coleta o segundo dígito da umidade (dezena)
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_UNI,W	    ;	Coleta o terceiro dígito da umidade (unidade)
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVLW   ','		    ;	Coleta o caractere ','
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_DEC,W	    ;	Coleta o ultimo dígito da umidade (decimal)
    CALL    ESCREVE	    ;	WREG -> LCD
;---------------------------;
;--- Aguarda 2 segundos ----;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    GOTO    LOOP	    ;	Reinicia o laço
;---------------------------;

;--------------------------------------------------------;
;********************************************************;
;----- LEITURA, FORMATACAO E VERIFICACAO DOS DADOS ------;
LER_DHT
    CALL    INICIA_TRANSMISSAO
;---------------------------;
    CALL    LER_BYTE	    ;	Lê os MSB da Umidade Relativa
    MOVWF   UMID_HI	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Lê os LSB da Umidade Relativa
    MOVWF   UMID_LO	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Lê os MSB da Temperatura
    MOVWF   TEMP_HI	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Lê os LSB da Temperatura
    MOVWF   TEMP_LO	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Lê o byte de verificação
    MOVWF   CHKS	    ;
;---------------------------;
    CALL    CHECKSUM	    ;	Executa a verificação de erros
    CALL    FORMATAR	    ;	Formata os valores para exibição
    RETURN		    ;

;--------------------------------------------------------;
;********************************************************;
;------- INICIA A TRANSMISSAO DOS 40 BITS DO DHT --------;
INICIA_TRANSMISSAO
;-- Envio do Start Signal --;	
    BANCO1		    ;	
    BCF	    DHT_DIR	    ;	Comunicacao MCU -> DHT
    BANCO0		    ;
    BCF	    DHT_PIN	    ;	Start Signal em nivel baixo
    MOVLW   .18		    ;	Aguarda 18ms
    CALL    DELAY_MS	    ;
    BSF	    DHT_PIN	    ;	Retorna ao nivel alto
    BANCO1		    ;
    BSF	    DHT_DIR	    ;	Comunicacao DHT -> MCU
    BANCO0		    ;
;---------------------------;
    CALL    TIMEOUT	    ;	Inicia o Timeout de 100uS
;-- Aguarda uma resposta ---;
ESPERA_RESPOSTA
    BTFSS   INTCON,2	    ;	Verifica se já se se passaram 100uS
    GOTO    $+2		    ;	Não! Pula duas instruções adiante
    GOTO    MSG_TIMEOUT	    ;	Sim! Exibe a mensagem de Timeout
    BTFSC   DHT_PIN	    ;	Verifica se a resposta do DHT é 0
    GOTO    ESPERA_RESPOSTA ;	Não! Continua aguardando
    MOVLW   .115	    ;
    CALL    DELAY_US	    ;	Sim! Aguarda 140uS
    RETURN		    ;

;--------------------------------------------------------;
;********************************************************;
;----------------- INICIA O TIMEOUT ---------------------;
TIMEOUT
    BCF	    INTCON,2	    ;	Inicia o flag de interrupção do TIMER0
    MOVLW   .156	    ;	Aproximadamente 100uS
    MOVWF   TMR0	    ;	Envia o valor inicial para o TIMER0
    RETURN

;--------------------------------------------------------;
;********************************************************;
;---------------- LEITURA DE UM BYTE --------------------;
LER_BYTE
    MOVLW   .9		    ;	Restaura o contador
    MOVWF   CONTADOR	    ;	para 8 leituras
    CLRF    BYTE_DHT	    ;	Limpa o ultimo valor lido
LEITURA
    CALL    TIMEOUT	    ;	Inicia o Timeout
    DECFSZ  CONTADOR	    ;	Decrementa o contador e testa é 0
    GOTO    NOVO_BIT	    ;	Não! Inicia nova leitura
    MOVF    BYTE_DHT,W	    ;	Sim! coleta o byte lido e grava em WREG
    RETURN		    ;	Finaliza e retorna com BYTE_DHT -> WREG
NOVO_BIT
    RLF	    BYTE_DHT,1	    ;	Desloca os bits à esquerda
    BTFSS   INTCON,2	    ;	Verifica se o Timeout transborda
    GOTO    $+2		    ;	Não! Avança duas instruções
    GOTO    MSG_TIMEOUT	    ;	Sim! Exibe a mensagem de Timeout
    BTFSC   DHT_PIN	    ;	Aguarda um bit 0 do DHT
    GOTO    $-1		    ;	
    BTFSS   DHT_PIN	    ;	Aguarda o início do bit de dado
    GOTO    $-1		    ;
    MOVLW   .240	    ;	Aguarda 30uS
    CALL    DELAY_US	    ;
    BTFSC   DHT_PIN	    ;	Testa se o bit enviado pelo DHT é 0 
    GOTO    BIT_HIGH	    ;	Não! Pula para registrar um bit 1
BIT_LOW
    BCF	    BYTE_DHT,0	    ;	Sim! Registra um bit 0
    GOTO    LEITURA	    ;	Reinicia uma nova leitura para o próximo bit
BIT_HIGH
    BSF	    BYTE_DHT,0	    ;	Registra um bit 1
    BTFSC   DHT_PIN	    ;	Aguarda um bit 0 para iniciar
    GOTO    $-1		    ;	uma nova leitura
    GOTO    LEITURA	    ;	Reinicia uma nova leitura para o próximo bit

;--------------------------------------------------------;
;********************************************************;
;---------------- VERIFICACAO DE ERROS ------------------;
CHECKSUM
    MOVF    UMID_HI,W	    ;	Move os MSB da umidade para WREG
    ADDWF   UMID_LO,W	    ;	Soma os LSB da umidade com WREG
    ADDWF   TEMP_HI,W	    ;	Soma os MSB da temperatura com WREG
    ADDWF   TEMP_LO,W	    ;	Soma os LSB da temperatura com WREG
    SUBWF   CHKS,W	    ;	Subtrai o byte CHKS de WREG
    BTFSS   STATUS,Z	    ;	Verifica se o resultado da subtração é zero
    GOTO    MSG_ERRO	    ;	Não! Exibe uma mensagem de erro de comunicação
    RETURN		    ;	Sim! Retorna

;--------------------------------------------------------;
;********************************************************;
;------------ FORMATAR VALORES PARA EXIBICAO ------------;
FORMATAR
;-----Formatar Umidade------;
;--Primeira divisão por 10--;
;--------( 000,X )----------;
    MOVF    UMID_HI,W	    ;	UMID_HI -> WREG
    MOVWF   DDHI	    ;	Move os MSB da umidade para os MSB do dividendo
    MOVF    UMID_LO,W	    ;	UMID_LO -> WREG
    MOVWF   DDLO	    ;	Move os LSB da umidade para os LSB do dividendo
    CALL    DIVIDIR	    ;	Inicia a divisão por 10
    MOVF    DDLO,W	    ;	Move o resto da divisão para WREG
    MOVWF   UMID_DEC	    ;	Move o valor de WREG para o decimal da umidade
    MOVLW   H'30'	    ;	Formata o dígito decimal da umidade
    IORWF   UMID_DEC,1	    ;	para o formato ASCII (UMID_DEC or 0x30)
;---------------------------;
;--Segunda divisão por 10---;
;--------( 00X,0 )----------;
    MOVF    QLO,W	    ;	Quociente da Divisão -> WREG
    MOVWF   DDLO	    ;	Move o quociente para o novo LSB do dividendo
    CALL    DIVIDIR	    ;	Inicia uma nova divisão por 10
    MOVF    DDLO,W	    ;	Resto da Divisão -> WREG
    MOVWF   UMID_UNI	    ;	Move o resto da divisão para a unidade da Umidade
    MOVLW   H'30'	    ;	Formata o dígito unidade da umidade
    IORWF   UMID_UNI	    ;	para o formato ASCII (UMID_UNI or 0x30)
    MOVF    QLO,W	    ;	Move o quociente da divisão para WREG
;---------------------------;
;-------Verifica se---------;
;---- a umidade é 100% -----;
    SUBLW   H'0A'	    ;	Verifica se o quociente é igual a 10
    BTFSC   STATUS,Z	    ;	indicando que a umidade medida é igual a 100
    GOTO    CENTENA	    ;	Sim! Configura os dígitos de centena e dezena
;--------( 0X0,0 )----------;
    MOVF    QLO,W	    ;	Não! Quociente da Divisão -> WREG
    MOVWF   UMID_DEZ	    ;	Move o Quociente da divisão para a dezena da umidade
    MOVLW   H'30'	    ;	Formata o dígito dezena da umidade
    IORWF   UMID_DEZ,1	    ;	para o formato ASCII (UMID_DEZ or 0x30)
;--------( X00,0 )----------;
    MOVLW   ' '		    ;	Move um espaço em branco para WREG
    MOVWF   UMID_CEN	    ;	Move o espaço em branco para a centena da umidade
    GOTO    TEMPERATURA	    ;	Inicia a formatação da medida de temperatura
CENTENA
    MOVLW   H'31'	    ;	Move o dígito '1' em formato ASCII para WREG
    MOVWF   UMID_CEN	    ;	Move '1' para a centena da umidade
;--------( 0X0,0 )----------;
    MOVLW   H'30'	    ;	Move o dígito '0' em formato ASCII para WREG
    MOVWF   UMID_DEZ	    ;	Move '0' para a dezena da umidade
;---------------------------;
;---Formatar Temperatura----;
TEMPERATURA
    BTFSC   TEMP_HI,7	    ;	Verifica se a temperatura medida é negativa
    GOTO    NEGATIVO	    ;	Sim! Configura o sinal negativo da temperatura
    MOVLW   ' '		    ;	Não! Move um espaço em branco para WREG
    MOVWF   TEMP_SIN	    ;	Move o espaço em branco para o sinal da temperatura
    GOTO    CALCULAR_TEMP   ;	Inicia a conversão do valor de temperatura
NEGATIVO
    MOVLW   '-'		    ;	Move o símbolo negativo para WREG
    MOVWF   TEMP_SIN	    ;	Move o símbolo '-' para o sinal da temperatura
CALCULAR_TEMP
    BCF	    TEMP_HI,7	    ;	Limpa o bit sinalizador negativo da temperatura
;---------------------------;
;--Primeira divisão por 10--;
;---------( 00,X )----------;
    MOVF    TEMP_HI,W	    ;	TEMP_HI -> WREG
    MOVWF   DDHI	    ;	Move os MSB da temperatura para os MSB do dividendo
    MOVF    TEMP_LO,W	    ;	TEMP_LO -> WREG
    MOVWF   DDLO	    ;	Move os LSB da temperatura para os LSB do dividendo
    CALL    DIVIDIR	    ;	Inicia a divisão por 10
    MOVF    DDLO,W	    ;	Resto da Divisão -> WREG
    MOVWF   TEMP_DEC	    ;	Move o resto da divisão para o decimal da temperatura
    MOVLW   H'30'	    ;	Formata o dígito decimal da temperatura
    IORWF   TEMP_DEC,1	    ;	para o formato ASCII (TEMP_DEC or 0x30)
;---------------------------;
;--Segunda divisão por 10 --;
;---------( X0,0 )----------;
    MOVF    QLO,W	    ;	Move o quociente da divisão para WREG
    MOVWF   DDLO	    ;	Move WREG para os LSB da nova divisão
    CALL    DIVIDIR	    ;	Inicia a divisão por 10
    MOVF    QLO,W	    ;	Move o quociente da divisão para WREG
    MOVWF   TEMP_DEZ	    ;	Move WREG para a dezena da temperatura
    MOVLW   H'30'	    ;	Formata o dígito de dezena da temperatura
    IORWF   TEMP_DEZ,1	    ;	para o formato ASCII (TEMP_DEZ or 0x30)
;---------( 0X,0 )----------;
    MOVF    DDLO,W	    ;	Move o resto da divisão para WREG
    MOVWF   TEMP_UNI	    ;	Move WREG para a unidade da temperatura
    MOVLW   H'30'	    ;	Formata o dígito da unidade da temperatura
    IORWF   TEMP_UNI,1	    ;	para o formato ASCII (TEMP_UNI or 0x30)
;---------------------------;
    RETURN		    ;	Retorna
;--------------------------------------------------------;
;-------------- DIVISÃO DE 2 BYTES POR 10 ---------------;
DIVIDIR    
    CLRF    QHI		    ; Limpa os quocientes
    CLRF    QLO		    ;
    MOVLW   .10		    ; W = divisor
STEP
    SUBWF   DDLO,F	    ;
    BTFSC   STATUS,C	    ;
    GOTO    BUMP	    ;
    MOVF    DDHI,F	    ;
    BTFSC   STATUS,Z	    ;
    GOTO    DONE	    ;
    DECF    DDHI,F	    ;
BUMP
    INCF    QLO,F	    ;
    BTFSC   STATUS,Z	    ;
    INCF    QHI,F	    ;
    GOTO    STEP	    ;
DONE
    ADDWF   DDLO,F	    ;
    RETURN  
  
;--------------------------------------------------------;
;********************************************************;   
;------------------------ DELAYS ------------------------;
;------Delay de 500mS-------;
DELAY_500MS
    BCF	    T1CON,0	    ;	Desativa o TIMER1
    MOVLW   H'0B'	    ;	Move os MSB do valor inicial
    MOVWF   TMR1H	    ;	para o TIMER1H
    MOVLW   H'DC'	    ;	Move os LSB do valor inicial
    MOVWF   TMR1L	    ;	para o TIMER1L
    BSF	    T1CON,0	    ;	Ativa o TIMER1
    BTFSS   PIR1,0	    ;	Aguarda o transbordamento do
    GOTO    $-1		    ;	TIMER1 pela Flag TMR1IF
    BCF	    PIR1,0	    ;	Sim! Restaura o TIMER1
    RETURN		    ;
;---------------------------;
;--Delay de milissegundos---;
DELAY_MS
    MOVWF   TEMPO1	    ;	Move WREG para o TEMPO1
    MOVLW   .250	    ;	Move o decimal 250 para WREG
    MOVWF   TEMPO0	    ;	Move WREG para o TEMPO0
    NOP			    ;	Sem operação
    DECFSZ  TEMPO0,F	    ;	Decrementa o TEMPO0 e verifica se é 0
    GOTO    $-2		    ;	Não! Retrocede duas instruções
    DECFSZ  TEMPO1,F	    ;	Sim! Decrementa o TEMPO1 e verifica se é 0
    GOTO    $-4		    ;	Não! Retrocede quatro instruções
    RETURN		    ;	Retorna
;---------------------------;
;--Delay de microssegundos--;
DELAY_US
    BCF	    INTCON,2	    ;	Restaura o flag de interrupção do TIMER0
    MOVWF   TMR0	    ;	Move WREG para o TIMER0
    BTFSS   INTCON,2	    ;	Aguarda o transbordamento do TIMER0
    GOTO    $-1		    ;	Não! Retrocede uma instrução
    RETURN		    ;	Sim! Retorna
;---------------------------;

;--------------------------------------------------------;
;********************************************************; 
;-------------Rotinas para o Display LCD ----------------;  
;---Escreve um caractere----;
;--------- no LCD ----------;
ESCREVE
    BSF	    ENABLE	    ;	EN = 1
    MOVWF   LCD		    ;	Move WREG para PORTD
    NOP			    ;	Aguarda um tempo
    GOTO    $+1		    ;	para a comutação das portas
    BCF	    ENABLE	    ;	EN = 0 (Inicia a escrita)
    MOVLW   .1		    ;	Aguarda 1 milissegundos
    CALL    DELAY_MS	    ;	para a escrita no LCD
    RETURN		    ;	Retorna
;---------------------------;
;----Mensagem de Timeout----;
MSG_TIMEOUT
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Limpar display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor na posição (1,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'H'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ; 
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'U'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '!'		    ;
    CALL    ESCREVE	    ;
    CALL    DELAY_500MS	    ;	Aguarda 2 segundos
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    TEXTOS	    ;
    GOTO    LOOP	    ;
;---------------------------;
;-----Mensagem de erro------;
;------de Comunicação-------;
MSG_ERRO
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Limpar display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor na posição (1,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'F'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'L'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'H'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'N'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    COMANDAR_LCD	    ;
    MOVLW   H'C0'	    ;	Cursor na posição (2,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'C'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'U'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'N'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'C'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'Ç'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'Ã'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    CALL    DELAY_500MS	    ;	Aguarda 2 segundos
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    TEXTOS	    ;
    GOTO    LOOP	    ;
;---------------------------;
;-------Texto Padrão--------;
TEXTOS
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Limpa Display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor na posição (1,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'P'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'R'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'U'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'R'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    COMANDAR_LCD	    ;
    MOVLW   H'C0'	    ;	Cursor na posição (2,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'U'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    RETURN		    ;
;---------------------------;
;---Texto de Boas Vindas----;
MSG_INICIO
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Limpar Display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor na posição (1,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    COMANDAR_LCD	    ;
    MOVLW   H'C0'	    ;	Cursor na posição (2,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'C'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'R'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'P'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'R'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'C'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    CALL    DELAY_500MS	    ;	Aguarda 3 segundos
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    RETURN		    ;
;--------------------------------------------------------;
;********************************************************;

END
    
