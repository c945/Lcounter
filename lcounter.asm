;
;	LED RADIO Frequency-Counter	lcounter.asm
;
;	1999/10/24	S.Nishimura
;
;	RB<0-7> = 7Segment LED to <0>=a,<1>=b ,,, <7>=h
;	RA<0-3> = 7Segment LED Common(Kathode Common) <0>=0 ,,, <3>=3
;
;	RB<7>   = 455KHz Minus SW(2.2KOhm to GND)
;	RB<6>   = 455KHz Plus  SW(2.2kOhm to GND)
;	RA<4>   = Frequency Input
;
;   	 _a_         _a_         _a_         _a_
;      f|_g_|b     f|_g_|b     f|_g_|b     f|_g_|b
;      e|_d_|c .h  e|_d_|c .h  e|_d_|c .h  e|_d_|c .h
;         0           1           2           3
;

	PROCESSOR PIC16F84A
	__CONFIG _WDT_OFF & _PWRTE_OFF & _HS_OSC
	INCLUDE "P16F84A.INC"
	LIST            P=PIC16F84A

BYTE0		EQU		0DH		;Counter 0
BYTE1       EQU     0EH     ;Counter 1
BYTE2       EQU     0FH     ;Counter 2
BCD12       EQU     10H     ;BCD 12
BCD34		EQU		11H		;BCD 34
BCD56		EQU		12H		;BCD 56
BCD78		EQU		13H		;BCD 78
LED1		EQU		14H		;LED DATA 1
LED2		EQU		15H		;LED DATA 2
LED3		EQU		16H		;LED DATA 3
LED4		EQU		17H		;LED DATA 4
OVRFLW		EQU		18H		;Over Flow Flag
SHIFT		EQU		19H		;Shift counter
SAVE1		EQU		1AH		;save to BYTE1
SAVE2		EQU		1BH		;save to BYTE2
SWITCH		EQU		1CH		;SWITCH
;
TEMP1		EQU		1DH		;tempolary 1
TEMP2		EQU		1EH		;tempolary 2

M_OUT1	macro
	movlw	0
	movwf	PORTB
	movlw	0f7h
	movwf	PORTA
	movf	LED1,W
	movwf	PORTB
	call	TIMES
	endm
M_OUT2	macro
	movlw	0
	movwf	PORTB
	movlw	0fbh
	movwf	PORTA
	movf	LED2,W
	movwf	PORTB
	call	TIMES
	endm
M_OUT3	macro
	movlw	0
	movwf	PORTB
	movlw	0fdh
	movwf	PORTA
	movf	LED3,W
	movwf	PORTB
	call	TIMES
	endm
M_OUT4	macro
	movlw	0
	movwf	PORTB
	movlw	0feh
	movwf	PORTA
	movf	LED4,W
	movwf	PORTB
	call	TIMES
	endm
	
	org	0h
TEST
	movlw	080h
	movwf	BYTE0
	movwf	BYTE1
	movwf	BYTE2
	call	ADD455
	call	CONVRT


;***********************************************************
;Inhibit Intrrupt
	bcf	STATUS,RP0
	clrf	INTCON
	bsf	STATUS,RP0	;Bank-1
				;PORTB=<0-7>OUT
	movlw	0h		;1:IN 0:OUT
	movwf	TRISB
				;PORTA=<0-3>OUT,<4>IN
	movlw	010h		;1:IN 0:OUT
	movwf	TRISA

	bcf	OPTION_REG,NOT_RBPU	;PortB Pull-Up Enable
;;	bcf	OPTION_REG,T0CS		;1/4Clock to Counter
	bsf	OPTION_REG,T0CS		;RA4 to Counter(For TEST)
	bcf	OPTION_REG,PSA		;PreScaller to TMR0
	bcf	OPTION_REG,PS0		;1/8 Rate
	bsf	OPTION_REG,PS1
	bcf	OPTION_REG,PS2	
	bcf	STATUS,RP0		;Bank-0
;**********************************************************
MAIN_LOOP
	movlw	0
	movwf	TMR0
	bcf	INTCON,T0IF
;100ms COUNT Start
	M_OUT1
	M_OUT2
	M_OUT3
	M_OUT4
	M_OUT1
	M_OUT2
	M_OUT3
	M_OUT4
	M_OUT1
	M_OUT2
	M_OUT3
	M_OUT4
	M_OUT1
	M_OUT2
	M_OUT3
	M_OUT4
;100ms End
	movf	TMR0,W			;get timer0 to BYTE0
	movwf	BYTE0
	btfss	INTCON,T0IF		;check overflow?
	goto	MAIN_AFTER
	incfsz	BYTE1,F
	goto	MAIN_AFTER
	incf	BYTE2,F
MAIN_AFTER
			;increment BYTE1
	call	MULTI8			;Adjust PreScaller,*8
	call	GETSW
	btfss	SWITCH,7		;SUB 455KHz, If SW-7 to Low
	call	SUB455
	btfss	SWITCH,6		;ADD 455KHz, if SW-6 to Low
	call	ADD455
	call	CONVRT			;Binary To BCD
	call	BCD2LED_6543		;Display
	goto	MAIN_LOOP

;------------------------------------------------------------------------
;	sub	Get Switch
;------------------------------------------------------------------------
GETSW
;LED OFF
	bsf	PORTA,0
	bsf	PORTA,1
	bsf	PORTA,2
	bsf	PORTA,3
;Change INPUT-MODE for PORT-B
	bsf	STATUS,RP0		;Bank-1
					;PORTB=<0-7>IN
	movlw	0ffh			;1:IN 0:OUT
	movwf	TRISB
	bcf	STATUS,RP0		;Bank-0
;Get SWITCH
	nop				;Dummy Delay?
	nop
	nop
	nop
	movf	PORTB,W			;Sense SW from Port-B
	movwf	SWITCH
;ReChange OUTPUT-MODE for PORT-B
	bsf	STATUS,RP0		;Bank-1
					;PORTB=<0-7>OUT
	movlw	0h			;1:IN 0:OUT
	movwf	TRISB
	bcf	STATUS,RP0		;Bank-0
	return

;------------------------------------------------------------------------
;	add	455 KHz
;
;	BYTE0-2 =+ 455,000/10 
;				455KHz = 0x6F158H, 45.5KHz = 0xB1BCH
;------------------------------------------------------------------------
ADD455
	movlw	0BCh
	addwf	BYTE0,F
	btfss	STATUS,C
	goto	add455_c2
	movlw	1
	addwf	BYTE1,F
	btfss	STATUS,C
	goto	add455_c2
	incf	BYTE2,F
add455_c2
	movlw	0B1h
	addwf	BYTE1,F
	btfss	STATUS,C
	goto	add455_c3
	incf	BYTE2,F
add455_c3
	return
;------------------------------------------------------------------------
;	sub	455 KHz
;
;	BYTE0-2 =- 455,000/10 
;				455KHz = 0x6F158H, 45.5KHz = 0xB1BCH
;------------------------------------------------------------------------
SUB455
	movlw	0BCh
	subwf	BYTE0,F
	btfsc	STATUS,C
	goto	sub455_c2
	movlw	1
	subwf	BYTE1,F
	btfsc	STATUS,C
	goto	sub455_c2
	decf	BYTE2,F
sub455_c2
	movlw	0B1h
	subwf	BYTE1,F
	btfsc	STATUS,C
	goto	sub455_c3
	decf	BYTE2,F
sub455_c3
	return

;------------------------------------------------------------------------
;	6.25ms Loop. 
;
;	10.00MHz(15625.STEP)
;	10.08MHz(15750.STEP)
;	10.20MHz(15938.STEP)
;
;	How To Step N and M
;
;	M_OUT?						8 STEP
;	TIMES						4 STEP
;	1'st	(M-1)*14 + 16 
;	after	(255*14+16) * (N-1)
;	nop	* Y
;	return						2 STEP
;
;	10.20MHz(15938) =
;		8 + 4 + 2	   14
;	+	112*14+16	 1584
;	+	(255*14+16)*4	14344	= 15942.STEP
;
;	10.089MHz(15750) =
;		8 + 4 + 2	   14
;	+	98*14+16	 1388
;	+	(255*14+16)*4	14344	= 15746.STEP
;	+	nop x 4
;
;	10.00MHz(15625) =
;		8 + 4 + 2	   14
;	+	89*14+16	 1262
;	+	(255*14+16)*4	14344	= 15620.STEP
;	+	nop x 5
;
;------------------------------------------------------------------------
TIMES
	movlw	D'5'		;Value of N   10.08MHz=5  / 10.00MHz=5
	movwf	TEMP1
	movlw	D'99'		;Value of M   10.08MHz=99 / 10.00MHz=90
	movwf	TEMP2
TIM2
	btfsc	INTCON,T0IF	;check overflow?
	goto	INC1		;increment BYTE1
	nop			;Dummy 7 STEP
	nop
	nop
	nop
	nop
	nop
	nop
	goto	TIM_END
INC1
	bcf	INTCON,T0IF		;clear overflow
	incf	BYTE1,F
	btfsc	STATUS,Z
	goto	INC2
	nop
	nop
	goto	TIM_END
INC2
	incf	BYTE2,F
	goto	TIM_END
TIM_END
	decfsz	TEMP2,F
	goto	TIM2
	decfsz	TEMP1,F
	goto	TIM2
	nop			;Value of Y 10.08MHz=4 / 10.00MHz = 5
	nop
	nop
	nop
; Triming Cut&Try.(10.08MHz=+5  / 10.00MHz = ?)
	return

;
;	7Segment L.E.D Code.
;
LEDSEG
	andlw	0x0f;
	addwf	PCL,1
	retlw	03fh		;0
	retlw	006h		;1
	retlw	05bh		;2
	retlw	04fh		;3
	retlw	066h		;4
	retlw	06dh		;5
	retlw	07dh		;6
	retlw	027h		;7
	retlw	07fh		;8
	retlw	06fh		;9
	retlw	079h		;A
	retlw	07ch		;b
	retlw	039h		;C
	retlw	05eh		;d
	retlw	079h		;E
	retlw	071h		;F

;
; BCD to LED Work
;
BCD2LED_4321
	movf	BCD12,W
	call	LEDSEG
	movwf	LED1
	swapf	BCD12,W
	call	LEDSEG
	movwf	LED2
	movf	BCD34,W
	call	LEDSEG
	movwf	LED3
	swapf	BCD34,W
	call	LEDSEG
	movwf	LED4
	return

BCD2LED_5432
	swapf	BCD12,W
	call	LEDSEG
	movwf	LED1
	movf	BCD34,W
	call	LEDSEG
	movwf	LED2
	swapf	BCD34,W
	call	LEDSEG
	movwf	LED3
	movf	BCD56,W
	call	LEDSEG
	movwf	LED4
	return

BCD2LED_6543
	movf	BCD34,W
	call	LEDSEG
	movwf	LED1
	swapf	BCD34,W
	call	LEDSEG
	movwf	LED2
	movf	BCD56,W
	call	LEDSEG
	movwf	LED3
	swapf	BCD56,W
	call	LEDSEG
	movwf	LED4
	return

BCD2LED_7654
	swapf	BCD34,W
	call	LEDSEG
	movwf	LED1
	movf	BCD56,W
	call	LEDSEG
	movwf	LED2
	swapf	BCD56,W
	call	LEDSEG
	movwf	LED3
	movf	BCD78,W
	call	LEDSEG
	movwf	LED4
	return

BCD2LED_8765
	movf	BCD56,W
	call	LEDSEG
	movwf	LED1
	swapf	BCD56,W
	call	LEDSEG
	movwf	LED2
	movf	BCD78,W
	call	LEDSEG
	movwf	LED3
	swapf	BCD78,W
	call	LEDSEG
	movwf	LED4
	return
;
; BYTE0-2 *= 8
;
MULTI8
;prescaler ratio=8,Adjust prescaler
		BCF		STATUS,C
		RLF		BYTE0,F		;*2
		RLF		BYTE1,F
		RLF		BYTE2,F
		BCF		STATUS,C
		RLF		BYTE0,F		;*2
		RLF		BYTE1,F
		RLF		BYTE2,F
		BCF		STATUS,C
		RLF		BYTE0,F		;*2
		RLF		BYTE1,F
		RLF		BYTE2,F
		BTFSC		STATUS,C	;carry=on?
		BSF		OVRFLW,0	;overflow flag on
		return

;************************************
;Convert 3 bytes binary to BCD
;  This routine is refered to
;  application notes.
;      BYTE3 is not used
;************************************

CONVRT
		BCF		STATUS,C	;reset carry
		MOVLW		018H		;Shift bit counter
		MOVWF		SHIFT		;shift 32 times 
		CLRF		BCD12		;clear BCD
		CLRF		BCD34
		CLRF		BCD56
		CLRF		BCD78
LOOP
		RLF		BYTE0,F		;shift  BYTE to BCD
		RLF		BYTE1,F
		RLF		BYTE2,F
		RLF		BCD12,F
		RLF		BCD34,F
		RLF		BCD56,F
		RLF		BCD78,F
		DECFSZ		SHIFT,F		;end check
		GOTO		ADJST		;adjust to BCD
		RETURN
ADJST
		MOVF		BCD12,W	;BCD12 adjust TO BCD
		CALL		ADJBCD
		MOVWF		BCD12
		MOVF		BCD34,W	;BCD34 adjust to BCD
		CALL		ADJBCD
		MOVWF		BCD34
		MOVF		BCD56,W	;BCD56 adjust to BCD
		CALL		ADJBCD
		MOVWF		BCD56
		MOVF		BCD78,W	;BCD78 adjust to BCD
		CALL		ADJBCD
		MOVWF		BCD78
		GOTO		LOOP

;****  Each digit adjust to BCD  ****
ADJBCD
		MOVWF		TEMP1		;save
		MOVLW		3		;W+3
		ADDWF		TEMP1,W
		MOVWF		TEMP2
		BTFSC		TEMP2,3		;Test W+3>7
		MOVWF		TEMP1		;>7 then W+3 else W
		
		MOVLW		030H		;W+30
		ADDWF		TEMP1,W
		MOVWF		TEMP2	
		BTFSC		TEMP2,7		;Test W+30>7*
		MOVWF		TEMP1		;>70 then W+30 else W
		MOVF		TEMP1,W
		RETURN

	end
