;---------------------------------------------------------------------------;
;                          THALYSSON SANTOS                                 ;
;           Federal University of Rondônia Foundation - UNIR                ;
;                       Porto Velho - RO. BRAZIL                            ;
;                                                                           ;
;   The Assembly source code below was developed to establish a             ;
;   communication protocol between the sensor module DHT22 (AM2302)         ;
;   and the PIC16F877A Microchip microcontroller. The reading values are    ;
;   processed, formatted and displayed on an LCD display, connected to      ;
;   microcontroller PIC16F877A throught an 8 bit connection.                ;
;                                                                           ;
;---------------------------------------------------------------------------;

; PIC16F877A Configuration Bit Settings

; Assembly source line config statements

#include "p16f877a.inc"

; CONFIG
; __config 0x3F3A
 __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

#DEFINE	    BANCO0	    BCF STATUS,RP0	;   Access to bank 0
#DEFINE	    BANCO1	    BSF STATUS,RP0	;   Access to bank 1
#DEFINE	    COMANDAR_LCD    BCF PORTB,RB0	;   Send commands to LCD
#DEFINE	    ESCREVER_LCD    BSF PORTB,RB0	;   Send data to show on LCD
#DEFINE	    ENABLE		PORTB,RB1	;   EN pin from LCD
#DEFINE	    LCD			PORTD		;   8-bit connection with LCD
#DEFINE	    DHT_PIN		PORTB,RB5	;   Data pin to DHT sensor
#DEFINE	    DHT_DIR		TRISB,5		;   Data direction of DHT pin

;--------------------------------------------------------;
;********************************************************;
;------------ GENERAL PURPOSE REGISTERS -----------------;
CBLOCK	0x20
;-----DELAY_MS------;
    TEMPO0	    ;	(0x20)
    TEMPO1	    ;	(0x21)
;-------------------;
;---Reading Bytes---;
    UMID_HI	    ;	(0x22) Relative Humidity MSB
    UMID_LO	    ;	(0x23) Relative Humidity LSB
    TEMP_HI	    ;	(0x24) Temperature MSB
    TEMP_LO	    ;	(0x25) Temperature LSB
;-------------------;
;--General Reading--;
    CONTADOR	    ;	(0x26) Bit reading counter
    BYTE_DHT	    ;	(0x27) Reading byte
    CHKS	    ;	(0x28) Checksum byte
;-------------------;
;-Division Routine--;
    QHI		    ;	(0x29) Division quotient MSB
    QLO		    ;	(0x2A) Division quotient LSB
    DDHI	    ;	(0x2B) Division dividend MSB
    DDLO	    ;	(0x2C) Division dividend LSB
;-------------------;
;----Final Values---;
    UMID_CEN	    ;	(0x2D) Hundred part of relative humidity
    UMID_DEZ	    ;	(0x2E) Ten part of relative humidity
    UMID_UNI	    ;	(0x2F) Unity of relativy humidity
    UMID_DEC	    ;	(0x30) Decimal part of relative humidity
    TEMP_SIN	    ;	(0x31) Signal of temperature
    TEMP_DEZ	    ;	(0x32) Ten part of temperature
    TEMP_UNI	    ;	(0x33) Unity part of temperature
    TEMP_DEC	    ;	(0x34) Decimal part of temperature
;-------------------;
ENDC

;--------------------------------------------------------;
;********************************************************;
;------------------ INTERRUPT VECTOR --------------------;
ORG 0x00
GOTO SETUP

;--------------------------------------------------------;
;********************************************************;
;------------------ SOFTWARE SETUP ----------------------;
SETUP
    BANCO1		    ;
    CLRF    TRISD	    ;	Setup PORTD as output
    BCF	    TRISB,RB0	    ;	Setup PORTB,0 as output
    BCF	    TRISB,RB1	    ;	Setup PORTB,1 as output
;--------TIMER0 Setup-------;
    MOVLW   H'0F'	    ;	Setup [0000 1111]
			    ;	<5> Internal clock counter
			    ;	<4> Increment on High-to-low transition
			    ;	<3> Prescaler is assigned to WDT
    MOVWF   OPTION_REG	    ;
;---------------------------;
    BANCO0		    ;
;--------TIMER1 Setup-------;
    MOVLW   H'30'	    ;	Setup [0011 0000]
			    ;	<5-4> Prescaler at 1:8
			    ;	<3>   Oscillator is shut-off
			    ;	<2>   Synchronize external clock input
			    ;	<1>   Internal clock
			    ;	<0>   TIMER1 stopped
    MOVWF   T1CON	    ;
;---------------------------;
    CLRF    PORTD	    ;	Clear PORTD
    CALL    DELAY_500MS	    ;	Wait 500ms to initialize
    GOTO    LCD_CONFIG	    ;	Start the LCD setup

;--------------------------------------------------------;
;********************************************************;
;-------------------- LCD SETUP -------------------------;
LCD_CONFIG
    COMANDAR_LCD	    ;
;------Function Set---------;
    MOVLW   H'38'	    ;	Command sent [0011 1000]
			    ;	<4> 8-bits mode
			    ;	<3> Two lines mode
			    ;	<2> Characters with 5x8 dots
    CALL    ESCREVE	    ;
;---------------------------;
;---------Input Mode--------;
    MOVLW   H'06'	    ;	Command sent [0000 0110]
			    ;	<1> Cursor moves to right
			    ;	<0> Display shift OFF
    CALL    ESCREVE	    ;
;---------------------------;
;------Display ON/OFF-------;
    MOVLW   H'0C'	    ;	Command sent [0000 1100]
			    ;	<2> Display ON
			    ;	<1> Invisible cursor
			    ;	<0> Cursor blink OFF
    CALL    ESCREVE	    ;
;---------------------------;
;------Clear Display-------;
    MOVLW   H'01'	    ;	Command sent [0000 0001]
    CALL    ESCREVE	    ;
;---------------------------;
;-----Cursor Position-----;
    MOVLW   H'80'	    ;	Command sent [1000 0000]
    CALL    ESCREVE	    ;	Position (1,1)
;---------------------------;
    CALL    MSG_INICIO	    ;	Print an welcome message for 3s
    CALL    TEXTOS	    ;	Print the standard words
    GOTO    LOOP	    ;

;--------------------------------------------------------;
;********************************************************;
;------------------------- LOOP -------------------------;
LOOP
    CALL    LER_DHT	    ;	Read and format the DHT values
;---------------------------;
;-- Cursor at pos (1,11) ---;
    COMANDAR_LCD	    ;	Set to send commands to LCD
    MOVLW   H'8B'	    ;	Command LCD -> Cursor at position (1,11)
    CALL    ESCREVE	    ;	Send the command to LCD
    ESCREVER_LCD	    ;	Set to send characters to LCD
;---------------------------;
;-- Print the Temperature --;
    MOVF    TEMP_SIN,W	    ;	Collect the temperature signa (+/-)
    CALL    ESCREVE	    ;	Send the character to LCD (WREG -> LCD)
    MOVF    TEMP_DEZ,W	    ;	Collect the ten part of temperature
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    TEMP_UNI,W	    ;	Collect the unity part of temperature
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVLW   ','		    ;	Collect the character ','
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    TEMP_DEC,W	    ;	Collect the decimal part of temperature
    CALL    ESCREVE	    ;	WREG -> LCD
;---------------------------;
;-- Cursor at pos (2,11) ---;
    COMANDAR_LCD	    ;	Set to send commands to LCD
    MOVLW   H'CB'	    ;	Command LCD -> Cursor at position (2,11)
    CALL    ESCREVE	    ;	Send the command to LCD
    ESCREVER_LCD	    ;	Set to send characters to LCD
;---------------------------;
;--- Print the Humidity ----;
    MOVF    UMID_CEN,W	    ;	Collect the hundred part of humidity
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_DEZ,W	    ;	Collect the ten part of humidity
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_UNI,W	    ;	Collect the unity part of humidity
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVLW   ','		    ;	Collect the character ','
    CALL    ESCREVE	    ;	WREG -> LCD
    MOVF    UMID_DEC,W	    ;	Collect the decimal part of humidity
    CALL    ESCREVE	    ;	WREG -> LCD
;---------------------------;
;--- Wait for 2 seconds ----;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    GOTO    LOOP	    ;	Restart the loop
;---------------------------;

;--------------------------------------------------------;
;********************************************************;
;-------- READING, FORMATING AND CHECKING DATA  ---------;
LER_DHT
    CALL    INICIA_TRANSMISSAO
;---------------------------;
    CALL    LER_BYTE	    ;	Read the Relative Humidity MSB
    MOVWF   UMID_HI	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Read the Relative Humidity LSB
    MOVWF   UMID_LO	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Read the Temperature MSB
    MOVWF   TEMP_HI	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Read the Temperature LSB
    MOVWF   TEMP_LO	    ;
;---------------------------;
    CALL    LER_BYTE	    ;	Read the checksum value
    MOVWF   CHKS	    ;
;---------------------------;
    CALL    CHECKSUM	    ;	Run the checksum verification
    CALL    FORMATAR	    ;	Format the values for display
    RETURN		    ;

;--------------------------------------------------------;
;********************************************************;
;--------------- STARTS DATA TRANSMISSION ---------------;
INICIA_TRANSMISSAO
;-- Send the Start Signal --;	
    BANCO1		    ;	
    BCF	    DHT_DIR	    ;	Data direction MCU -> DHT
    BANCO0		    ;
    BCF	    DHT_PIN	    ;	Start Signal at Low Level
    MOVLW   .18		    ;	Wait 18ms
    CALL    DELAY_MS	    ;
    BSF	    DHT_PIN	    ;	Send a bit 1
    BANCO1		    ;
    BSF	    DHT_DIR	    ;	Data direction DHT -> MCU
    BANCO0		    ;
;---------------------------;
    CALL    TIMEOUT	    ;	Start the Timeout of 100us
;-- Aguarda uma resposta ---;
ESPERA_RESPOSTA
    BTFSS   INTCON,2	    ;	Check the Timeout
    GOTO    $+2		    ;	No! Jump two insctructions forward
    GOTO    MSG_TIMEOUT	    ;	Yes! Display a Timeout message
    BTFSC   DHT_PIN	    ;	Wait a bit 0
    GOTO    ESPERA_RESPOSTA ;	Bit 1! Keep waiting
    MOVLW   .115	    ;
    CALL    DELAY_US	    ;	Bit 0! Wait 140us
    RETURN		    ;

;--------------------------------------------------------;
;********************************************************;
;----------------- TRIGGER THE TIMEOUT ---------------------;
TIMEOUT
    BCF	    INTCON,2	    ;	Start the interrupt flag of TIMER0
    MOVLW   .156	    ;	About 100uS
    MOVWF   TMR0	    ;	Set value at TIMER0
    RETURN

;--------------------------------------------------------;
;********************************************************;
;------------------ ONE BYTE READING --------------------;
LER_BYTE
    MOVLW   .9		    ;	Reset the counter
    MOVWF   CONTADOR	    ;	for 8 loops
    CLRF    BYTE_DHT	    ;	Clear the last reading
LEITURA
    CALL    TIMEOUT	    ;	Trigger the Timeout
    DECFSZ  CONTADOR	    ;	Decrement the counter and test if zero
    GOTO    NOVO_BIT	    ;	No! Begin a new bit read
    MOVF    BYTE_DHT,W	    ;	Yes! Collect the byte to WREG
    RETURN		    ;	Return the byte
NOVO_BIT
    RLF	    BYTE_DHT,1	    ;	Shift the byte to left
    BTFSS   INTCON,2	    ;	Check the timeout overflow
    GOTO    $+2		    ;	No! Jump two instructions foward
    GOTO    MSG_TIMEOUT	    ;	Yes! Display a Timeout message
    BTFSC   DHT_PIN	    ;	Wait for a bit 0
    GOTO    $-1		    ;	
    BTFSS   DHT_PIN	    ;	Wait for a bit 1
    GOTO    $-1		    ;
    MOVLW   .240	    ;	Wait 30us
    CALL    DELAY_US	    ;
    BTFSC   DHT_PIN	    ;	Test if the bit sent is 0
    GOTO    BIT_HIGH	    ;	No! Jump to bit 1 register
BIT_LOW
    BCF	    BYTE_DHT,0	    ;	Yes! bit 0 register
    GOTO    LEITURA	    ;	Jump to a new bit reading
BIT_HIGH
    BSF	    BYTE_DHT,0	    ;	Bit 1 register
    BTFSC   DHT_PIN	    ;	Wait for a bit 0
    GOTO    $-1		    ;	
    GOTO    LEITURA	    ;	Jump to a new bit reading

;--------------------------------------------------------;
;********************************************************;
;---------------------- CHECKSUM ------------------------;
CHECKSUM
    MOVF    UMID_HI,W	    ;	Collect the humidity MSB to WREG
    ADDWF   UMID_LO,W	    ;	Sum the humidity LSB with WREG
    ADDWF   TEMP_HI,W	    ;	Sum the temperature MSB with WREG
    ADDWF   TEMP_LO,W	    ;	Sum the temperature LSB with WREG
    SUBWF   CHKS,W	    ;	Subtract the checksum of WREG
    BTFSS   STATUS,Z	    ;	Check if the result is 0
    GOTO    MSG_ERRO	    ;	No! Display a error message
    RETURN		    ;	Yes! Return

;--------------------------------------------------------;
;********************************************************;
;---------------- FORMAT VALUES TO DISPLAY --------------;
FORMATAR
;----- Format Humidity -----;
;--- First Division by 10 --;
;--------( 000,X )----------;
    MOVF    UMID_HI,W	    ;	UMID_HI -> WREG
    MOVWF   DDHI	    ;	Humidity MSB to dividend division
    MOVF    UMID_LO,W	    ;	UMID_LO -> WREG
    MOVWF   DDLO	    ;	Humidity LSB to dividend division
    CALL    DIVIDIR	    ;	Divides the humidity by 10
    MOVF    DDLO,W	    ;	Collect the remainder from division
    MOVWF   UMID_DEC	    ;	Saves the remainder to decimal part
    MOVLW   H'30'	    ;	Format the number as ACII character
    IORWF   UMID_DEC,1	    ;
;---------------------------;
;---Second Division by 10---;
;--------( 00X,0 )----------;
    MOVF    QLO,W	    ;	Division quotient -> WREG
    MOVWF   DDLO	    ;	Division quotient to dividend division
    CALL    DIVIDIR	    ;	Start new division
    MOVF    DDLO,W	    ;	Division Remainder -> WREG
    MOVWF   UMID_UNI	    ;	Saves the remainder in unity part
    MOVLW   H'30'	    ;	Format the number as ASCII character
    IORWF   UMID_UNI	    ;
    MOVF    QLO,W	    ;	Division quotient -> WREG
;---------------------------;
;-------Checking if---------;
;-- the humidity = 100% ----;
    SUBLW   H'0A'	    ;	Check if the division quotient = 10
    BTFSC   STATUS,Z	    ;	If true, the relative humidity is 100%
    GOTO    CENTENA	    ;	Yes! Set the hundred and ten parts as 1 and 0
;--------( 0X0,0 )----------;
    MOVF    QLO,W	    ;	No! Division quotient -> WREG
    MOVWF   UMID_DEZ	    ;	Saves the quotient in ten part
    MOVLW   H'30'	    ;	Format the number as ASCII character
    IORWF   UMID_DEZ,1	    ;
;--------( X00,0 )----------;
    MOVLW   ' '		    ;
    MOVWF   UMID_CEN	    ;	Saves a blank space in hundred part
    GOTO    TEMPERATURA	    ;	Go to temperature formatting
CENTENA
    MOVLW   H'31'	    ;	Saves an ASCII character 1
    MOVWF   UMID_CEN	    ;	in hundred part of humidity
;--------( 0X0,0 )----------;
    MOVLW   H'30'	    ;	Saves an ASCII character 0
    MOVWF   UMID_DEZ	    ;	in ten part of humidity
;---------------------------;
;---Formatar Temperature----;
TEMPERATURA
    BTFSC   TEMP_HI,7	    ;	Check if the temperature value is negative
    GOTO    NEGATIVO	    ;	Yes! Go to save the signal
    MOVLW   ' '		    ;	No! Saves a blank space
    MOVWF   TEMP_SIN	    ;	in temperature signal
    GOTO    CALCULAR_TEMP   ;	Go to temperature formatting
NEGATIVO
    MOVLW   '-'		    ;	Saves the negative signal
    MOVWF   TEMP_SIN	    ;	in temperature signal register
CALCULAR_TEMP
    BCF	    TEMP_HI,7	    ;	Clear the bit 7 of temperature value
;---------------------------;
;----First Division by 10---;
;---------( 00,X )----------;
    MOVF    TEMP_HI,W	    ;	TEMP_HI -> WREG
    MOVWF   DDHI	    ;	Temperature MSB to division dividend MSB
    MOVF    TEMP_LO,W	    ;	TEMP_LO -> WREG
    MOVWF   DDLO	    ;	Temperature LSB to division dividend LSB
    CALL    DIVIDIR	    ;	Divides the temperature value by 10
    MOVF    DDLO,W	    ;	Division Remainder -> WREG
    MOVWF   TEMP_DEC	    ;	Saves the division remainder in decimal part
    MOVLW   H'30'	    ;	
    IORWF   TEMP_DEC,1	    ;   Format the number as ASCII character
;---------------------------;
;-- Second Division by 10 --;
;---------( X0,0 )----------;
    MOVF    QLO,W	    ;	Division quotient -> WREG
    MOVWF   DDLO	    ;	Last division quotient to dividend LSB
    CALL    DIVIDIR	    ;	Start a new division by 10
    MOVF    QLO,W	    ;	Division quotient -> WREG
    MOVWF   TEMP_DEZ	    ;	Saves the quotient in ten part
    MOVLW   H'30'	    ;	
    IORWF   TEMP_DEZ,1	    ;   Format the number as ASCII character
;---------( 0X,0 )----------;
    MOVF    DDLO,W	    ;	Saves the division remainder
    MOVWF   TEMP_UNI	    ;	in unity part of temperature
    MOVLW   H'30'	    ;	
    IORWF   TEMP_UNI,1	    ;   Format the number as ASCII character
;---------------------------;
    RETURN		    ;	Return
;--------------------------------------------------------;
;-------------- DIVISÃO DE 2 BYTES POR 10 ---------------;
DIVIDIR    
    CLRF    QHI		    ; Clear the quotients
    CLRF    QLO		    ;
    MOVLW   .10		    ; W = divider
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
;------Delay of 500mS-------;
DELAY_500MS
    BCF	    T1CON,0	    ;	Turn OFF TIMER1
    MOVLW   H'0B'	    ;	Move the initial value MSB
    MOVWF   TMR1H	    ;	to TIMER1H
    MOVLW   H'DC'	    ;	Move the inicial value LSB
    MOVWF   TMR1L	    ;	to TIMER1L
    BSF	    T1CON,0	    ;	Turn ON the TIMER1
    BTFSS   PIR1,0	    ;	Wait for overflow of TIMER1
    GOTO    $-1		    ;
    BCF	    PIR1,0	    ;	Yes! Reset the TIMER1
    RETURN		    ;
;---------------------------;
;---Delay of milliseconds---;
DELAY_MS
    MOVWF   TEMPO1	    ;	Move the WREG value to TEMPO1
    MOVLW   .250	    ;	Move the integer 250 to WREG
    MOVWF   TEMPO0	    ;	Move the 250 value to TEMPO0
    NOP			    ;	No operation
    DECFSZ  TEMPO0,F	    ;	Decrement TEMPO0 and check if it is 0
    GOTO    $-2		    ;	No! Go back two instructions
    DECFSZ  TEMPO1,F	    ;	Yes! Decrement TEMPO1 and check if it is 0
    GOTO    $-4		    ;	No! Go back two instructions
    RETURN		    ;	Return
;---------------------------;
;---Delay of microseconds---;
DELAY_US
    BCF	    INTCON,2	    ;	Reset the TIMER0 interrupt flag
    MOVWF   TMR0	    ;	Move the WREG to TMR0 peripheric
    BTFSS   INTCON,2	    ;	Wait for the TIMER0 overflow
    GOTO    $-1		    ;	No! Go back one instruction
    RETURN		    ;	Yes! Return
;---------------------------;

;--------------------------------------------------------;
;********************************************************; 
;--------------- LCD Display Routines -------------------;  
;---Print one Character----;
;--------- at LCD ----------;
ESCREVE
    BSF	    ENABLE	    ;	EN = 1
    MOVWF   LCD		    ;	Move the WREG value to PORTD
    NOP			    ;	No operation
    GOTO    $+1		    ;	One more time
    BCF	    ENABLE	    ;	EN = 0 (Start print)
    MOVLW   .1		    ;	Wait 1 millisecond
    CALL    DELAY_MS	    ;	for print
    RETURN		    ;	Return
;---------------------------;
;----Timeout Message----;
MSG_TIMEOUT
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Clear display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor at position (1,1)
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
    CALL    DELAY_500MS	    ;	Wait 2 seconds
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    TEXTOS	    ;
    GOTO    LOOP	    ;
;---------------------------;
;----Communication Error----;
;----------Message----------;
MSG_ERRO
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Clear display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor at position (1,1)
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
    MOVLW   H'C0'	    ;	Cursor at position (2,1)
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
    CALL    DELAY_500MS	    ;	Wait 2 seconds
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    TEXTOS	    ;
    GOTO    LOOP	    ;
;---------------------------;
;------Standard Words-------;
TEXTOS
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Clear Display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor at position (1,1)
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
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    COMANDAR_LCD	    ;
    MOVLW   H'C0'	    ;	Cursor at position (2,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'H'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'U'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'M'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'Y'         ;
    CALL    ESCREVE     ;
    RETURN		    ;
;---------------------------;
;------Welcome Message------;
MSG_INICIO
    COMANDAR_LCD	    ;
    MOVLW   H'01'	    ;	Clear Display
    CALL    ESCREVE	    ;
    MOVLW   H'80'	    ;	Cursor at position (1,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'D'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'H'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'E'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'N'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'S'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'O'         ;
    CALL    ESCREVE     ;
    MOVLW   'R'         ;
    CALL    ESCREVE     ;
    COMANDAR_LCD	    ;
    MOVLW   H'C0'	    ;	Cursor at position (2,1)
    CALL    ESCREVE	    ;
    ESCREVER_LCD	    ;
    MOVLW   'W'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'T'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'H'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;
    CALL    ESCREVE	    ;
    MOVLW   'P'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'I'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'C'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '1'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '6'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'F'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '8'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '7'		    ;
    CALL    ESCREVE	    ;
    MOVLW   '7'		    ;
    CALL    ESCREVE	    ;
    MOVLW   'A'		    ;
    CALL    ESCREVE	    ;
    MOVLW   ' '		    ;   DHT22 SENSOR
    CALL    ESCREVE	    ;   WITH PIC16F877A
    CALL    DELAY_500MS	    ;	Wait 3 seconds
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    CALL    DELAY_500MS	    ;
    RETURN		    ;
;--------------------------------------------------------;
;********************************************************;

END
    
