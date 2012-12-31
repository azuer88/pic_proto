;############################################################################
;# TITLE   "USART Communication"
;#      Program:        main.ASM
;#      Version:        1.0
;#      Revision Date:
;#      Author:         Blue Cuenca
;############################################################################

		errorlevel      -302            ;Ignore Banksel warning

        list p=16f877A
        include <P16f877A.INC>

        include "UARTInt.inc"


#define DIR 00  ; direction bit
#define MLOOP MOTOR_STATUS,00 ; loop active, if unset, exit loop 

UARTTstRAM      UDATA
ISR_STAT    	RES 02			;For saving STATUS value
#define     ISR_PCLATH	ISR_STAT+1	;For saving PCLATH

; shared RAM
UARTTstShr	 	UDATA_SHR
ISR_W	    	RES 01					;For Saving W reg. value

STPMV1			RES 01					;For Stepper motor 1 value command
STPMD1			RES 01
STPMV2			RES 01	
STPMD2			RES 01
STPMV3			RES 01
STPMD3			RES 01

OVERFLOW		RES 01					; 1 char overflow, reading an extra byte, don't know why.
tmp1			RES 01					;Temp vars for nibble shifting
tmp2			RES 01
d1				RES 01					;Delay var
d2				RES 01					
d3				RES 01					
d4				RES 01	
MOTOR_STATUS	RES 01				
COUNTER			RES 01

STARThere       CODE    0x00
	goto    START



INTserv      CODE    0x04	     ;
	nop		             ;this is necessary because the Linker file only allows 1 instruction
				     ;if we use the goto instruction, the code might go to the wrong location
				     ;depending on PCLATH.  So using a nop allows the code to go to the next
				     ;location.  This is important for context saving.
;Else for better INT Latency

;	       movwf	ISR_W		     ;If INT latency is critical

InteruptServiceLocation     CODE    0x05
ISRoutine
;context savings (very important)
	movwf	ISR_W		     ;save Wreg in ISR_W, If NOP is used above
	swapf	STATUS,W
	banksel ISR_STAT
	movwf	ISR_STAT	     ;put STATUSreg (swapped) into ISR_STAT
	movf	PCLATH,W
	movwf	ISR_PCLATH	     ;put PCLATH into ISR_PCLATH

;call the interrupt function
	pagesel     UARTIntISR
	call	    UARTIntISR	     ;Call general purpose RTC interrupt service routine

;restore context
	banksel ISR_STAT
	movf	ISR_PCLATH,W	    ;put ISR_PCLATH back into PCLATH
	movwf	PCLATH
	swapf	ISR_STAT,W
	movwf	STATUS		    ;swap ISR_STAT back into STATUSreg
	swapf	ISR_W,f 	    ;swap ISR_W into itself
	swapf	ISR_W,W 	    ;swap ISR_W into Wreg.
	retfie






Main    CODE
	goto START

StepperForward
	andlw	B'00000011'
	addwf	PCL,f
	retlw	B'00000001'
	retlw   B'00000010'
	retlw	B'00000100'
	retlw   B'00001000'
StepperReverse
	andlw	B'00000011'
	addwf	PCL,f
	retlw	B'00000100'
	retlw   B'00000010'
	retlw	B'00000001'
	retlw   B'00001000'



START
        ;Define the required TRIS and PORT settings here
        
;Make sure that UART pins are defined as i/p
	pagesel UARTIntInit
	call    UARTIntInit
	
; initialize ports
	bcf 	STATUS,IRP			
	bsf     STATUS,RP0     ; select bank 1
	movlw 	6
	movwf	ADCON1
 	clrf	TRISA
 	clrf	TRISB
 	clrf	TRISC
	clrf    TRISD

 	bsf		TRISC,	7	; configure UART RX as input, not to collide with MAX232
	; !! also any pins connected to Vdd or GND should be configured as inputs, or else ... 	
 	bcf     STATUS,RP0     ; select bank 0

 	clrf	PORTA
 	clrf	PORTB
 	clrf	PORTC
	clrf	PORTD

;Display RDY.V

	movlw   'R'
	Pagesel UARTIntPutCh
	call    UARTIntPutCh
	movlw   'D'
	call    UARTIntPutCh
	movlw   'Y'
	call    UARTIntPutCh


;Change the pre-claculated baudrate, If required
;        mSetUARTBaud    .9600


WaitRxData
    banksel vUARTIntStatus
;Check if Receive buffer is full        
	btfss   vUARTIntStatus,UARTIntRxBufFul
	goto    WaitRxData

	movlw	0
	movwf	tmp2

;	setup FSR

;If receive buffer is full then read the data
ReadAgain
	Pagesel UARTIntGetCh
	call    UARTIntGetCh

	Pagesel	save_char
	call 	save_char


	banksel vUARTIntStatus
	btfss   vUARTIntStatus,UARTIntRxBufEmpty
	goto    ReadAgain


motor_step_loop
	bcf 	MLOOP

	movlw	0xC8
	movwf	COUNTER
motor_revolution_loop

; do motor 1
	movlw	B'00001000'
	movwf	d1

	movfw	STPMV1
	addlw	0x00
	btfsc	STATUS,Z    
	goto	skip_motor1 	; count for this motor as reached zero, do not move

	btfsc	STPMD1, DIR     ; check direction
	goto	motor_forward1	
	movfw	COUNTER
	call	StepperReverse
	goto	motor_cont1
motor_forward1
	movfw	COUNTER
	call	StepperForward

motor_cont1
	movwf	d1
skip_motor1

; do motor 2
	movlw	B'00001000'
	movwf	d2

	movfw	STPMV2
	addlw	0x00
	btfsc	STATUS,Z    
	goto	skip_motor2 	; count for this motor as reached zero, do not move

	btfsc	STPMD2, DIR     ; check direction
	goto	motor_forward2	
	movfw	COUNTER
	call	StepperReverse
	goto	motor_cont2
motor_forward2
	movfw	COUNTER
	call	StepperForward

motor_cont2
	movwf	d2
skip_motor2

; do motor 3
	movlw	B'00001000'
	movwf	d3

	movfw	STPMV3
	addlw	0x00
	btfsc	STATUS,Z    
	goto	skip_motor3 	; count for this motor as reached zero, do not move

	btfsc	STPMD3, DIR     ; check direction
	goto	motor_forward3	
	movfw	COUNTER
	call	StepperReverse
	goto	motor_cont3
motor_forward3
	movfw	COUNTER
	call	StepperForward

motor_cont3
	movwf	d3
skip_motor3


; combine d2 and d2 
	rlf		d2
	rlf		d2
	rlf		d2
	rlf		d2
	movfw	d2
	iorwf	d1,w

;	movfw	d1
	banksel	PORTB
	movwf	PORTB

; shift left d3 so it'll be at d4-d7
	rlf		d3	
	rlf		d3
	rlf		d3
	rlf		d3
	movfw	d3
	banksel	PORTD
	movwf	PORTD

	; 2 @ 12V
	; 3 @ 12V stronger
	; slow = stronger?
	movlw	3
	call	delay
  
	decfsz	COUNTER
	goto motor_revolution_loop

; check: if motor counters are not zero, dec
	movfw	STPMV1
	addlw	0x00
	btfsc	STATUS,Z
	goto    skip_check1  

	decf	STPMV1,f
	bsf		MLOOP
skip_check1

; do motor check 2
	movfw	STPMV2
	addlw	0x00
	btfsc	STATUS,Z
	goto    skip_check2  

	decf	STPMV2,f
	bsf		MLOOP
skip_check2

; do motor check 3
	movfw	STPMV3
	addlw	0x00
	btfsc	STATUS,Z
	goto    skip_check3  

	decf	STPMV3,f
	bsf		MLOOP
skip_check3
	
	btfsc	MLOOP
	goto 	motor_step_loop

WaitForTxBufEmpty
	btfsc   vUARTIntStatus,UARTIntTxBufFul
	goto    WaitForTxBufEmpty

	;Display OK
	movlw   'O'
	Pagesel UARTIntPutCh
	call    UARTIntPutCh
	movlw   'K'
	call    UARTIntPutCh

	goto    WaitRxData
	
;	return	
	
save_char
	movwf	tmp1  ; save current char

	; have we exceeded the buffer size?
	movfw	tmp2
	addlw	.255 - UARTINT_RX_BUFFER_SIZE + .1
	;.253 ; if w is less than 3 ([.255 - 3] + 1)
	btfsc	STATUS, C
	goto	save_chars_skip  ; yes, ignore char


	movlw	STPMV1           ; put address of STPMV1 into w
	addwf	tmp2,w           ; tmp2 contains the offset (0..2) 
	movwf	FSR              ; set indirect address register to above result
	movfw	tmp1             ; retrieve value to store into w
	movwf	INDF             ; save w into current location pointed by indrect register
	incf	tmp2, f          ; move to next location
	return 
save_chars_skip
	movfw	tmp1
	return

ldelay
	movwf	d4
ldelay_loop
	call	SleepH
	decfsz	d4, f
	goto ldelay_loop
	return

delay
	movwf	d4
delay_loop
	call	SleepM
	decfsz	d4, f
	goto delay_loop
	return

; Delay = 0.5 seconds
; Clock frequency = 4 MHz

; Actual delay = 0.5 seconds = 500000 cycles
; Error = 0 %
SleepH
			;499,994 cycles
	movlw	0x03
	movwf	d1
	movlw	0x18
	movwf	d2
	movlw	0x02
	movwf	d3
SleepH_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	$+2
	decfsz	d3, f
	goto	SleepH_0

			;2 cycles
	goto	$+1

			;4 cycles (including call)
	return


; Delay = 0.001 seconds
; Clock frequency = 4 MHz

; Actual delay = 0.001 seconds = 1000 cycles
; Error = 0 %

SleepM
			;993 cycles
	movlw	0xC6
	movwf	d1
	movlw	0x01
	movwf	d2
SleepM_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	SleepM_0

			;3 cycles
	goto	$+1
	nop

			;4 cycles (including call)
	return

        END
