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


UARTTstRAM      UDATA
ISR_STAT    	RES 02			;For saving STATUS value
#define     ISR_PCLATH	ISR_STAT+1	;For saving PCLATH

; shared RAM
UARTTstShr	 	UDATA_SHR
ISR_W	    	RES 01					;For Saving W reg. value
STPMV1			RES 01					;For Stepper motor 1 value command
STPMV2			RES 01	
STPMV3			RES 01
STPM1			RES 01					;For Stepper motor 1 current bit
STPM2			RES 01	
STPM3			RES 01
STPMDIR			RES 01					;Durrent direction of stepper 1=fwd, 0=rev bit1=m1, bit2=m2, bit3=m3
tmp1			RES 01					;Temp vars for nibble shifting
tmp2			RES 01
d1				RES 01					;Delay var
d2				RES 01					
d3				RES 01					
d4				RES 01					

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
 	;clrf	TRISA
 	clrf	TRISB
 	;clrf	TRISC
 	bsf		TRISC,	7	; configure UART RX as input, not to collide with MAX232
	; !! also any pins connected to Vdd or GND should be configured as inputs, or else ... 	
 	bcf     STATUS,RP0     ; select bank 0
 	;clrf	PORTA
 	clrf	PORTB
 	;clrf	PORTC

;Display RDY.V

	movlw   'R'
	Pagesel UARTIntPutCh
	call    UARTIntPutCh
	movlw   'D'
	call    UARTIntPutCh
	movlw   'Y'
	call    UARTIntPutCh
	

; init motor vars
	movlw	1
	movwf	STPM1
	movwf	STPM2
	movwf	STPM3
	movlw	0
	movwf	STPMV1
	movwf	STPMV2
	movwf	STPMV3
	movlw	0
	movwf	STPMDIR
	call  	run_motors


;test_loop
;
;	movlw	0x85
;	movwf	STPMV1
;	movlw	0x0A
;	movwf	STPMV2
;	movlw	0x00
;	movwf	STPMV3
;
;motor_step_test
;	bcf		STPMDIR, 3
;	movlw	STPMV1
;	call	motor_step
;	movlw	STPMV2
;	call	motor_step
;	call  	run_motors
;
;	btfss	STPMDIR, 3
;	goto	motor_step_test_end
;
;	movlw	'.'
;	call	UARTIntPutCh
;
;	movlw	1
;	call	delay
;
;	goto	motor_step_test
;motor_step_test_end
;	movlw	'O'
;	call	UARTIntPutCh
;	movlw	'K'
;	call	UARTIntPutCh
;
;	goto	test_loop
;	
	

;Change the pre-claculated baudrate, If required
;        mSetUARTBaud    .9600


WaitRxData
    banksel vUARTIntStatus
;Check if Receive buffer is full        
	btfss   vUARTIntStatus,UARTIntRxBufFul
	goto    WaitRxData

	movlw	0
	movwf	STPMDIR


;If receive buffer is full then read the data
ReadAgain
	Pagesel UARTIntGetCh
	call    UARTIntGetCh

	call	store_chars

;;check if Tx buffer is empty
;        banksel vUARTIntStatus
;WaitForTxBufEmpty
;        btfsc   vUARTIntStatus,UARTIntTxBufFul
;        goto    WaitForTxBufEmpty
;
;;Echo back the received data                
;        Pagesel UARTIntPutCh
;        call    UARTIntPutCh
;
;Check if Rx Buffer is empty. If not keep reading it.
	banksel vUARTIntStatus
	btfss   vUARTIntStatus,UARTIntRxBufEmpty
	goto    ReadAgain

	;bsf		STPMV2, 7 ; force motor 2 to reverse
	;call	move_motors

	movfw	STPM1
	call	UARTIntPutCh

motor_step_loop
	bcf		STPMDIR, 3			; clear it so, if none of the motor_step calls sets it, exit loop

	movlw	STPMV3
	call	motor_step

	movlw	STPMV2
	call	motor_step

	movlw	STPMV1
	call	motor_step
	
	call	run_motors

	btfss	STPMDIR, 3			; if set, skip next instruction
	goto	motor_step_loop_end

	movlw	1
	call	delay

	goto	motor_step_loop
motor_step_loop_end

;	movlw	0xff
;	movwf	PORTB
;	movlw	.2
;	call	delay
;	movf	STPMV1, w
;	movwf	PORTB
;	addlw	'0'
;	Pagesel	UARTIntPutCh
;	call	UARTIntPutCh
;	movlw	.6
;	call	delay
;	movf	STPMV2, w
;	movwf	PORTB
;	addlw	'0'
;	Pagesel	UARTIntPutCh
;	call	UARTIntPutCh
;	movlw	.6
;	call	delay
;	movf	STPMV3, w
;	movwf	PORTB
;	addlw	'0'
;	Pagesel	UARTIntPutCh
;	call	UARTIntPutCh
;	movlw	.6
;	call	delay
;	movlw	0
;	movwf	PORTB
	

WaitForTxBufEmpty
	btfsc   vUARTIntStatus,UARTIntTxBufFul
	goto    WaitForTxBufEmpty
	;Display OK
	movlw   'O'
	Pagesel UARTIntPutCh
	call    UARTIntPutCh
	movlw   'K'
	call    UARTIntPutCh
;	movlw   ' '
;	call    UARTIntPutCh
	
	goto    WaitRxData

store_chars
	movwf	tmp1				; use shift tmp var to store current char

	incf	STPMDIR, f
	movf	STPMDIR, w

	addlw	253					; will carry if w is greater than 3. 
	btfsc	STATUS, C
	return						; do nothing if if greater than 3.

	movlw	STPMV1
	addwf	STPMDIR,w			
	; addlw	STPMV1 - 1			; w = STPMV1 + [1..3] - 1
	movwf	FSR
	movfw	tmp1
	movwf	INDF
	
	return	
	

run_motors
	; combine m1 & m2, with m2 on higher nibble
	movfw	STPM2
	movwf	tmp1 ; use temp var used by nibble shift
	bcf		STATUS, C
	rlf		tmp1, f
	rlf		tmp1, f
	rlf		tmp1, f
	rlf		tmp1, f
	movlw	0xF0
	andwf	tmp1, w
	iorwf	STPM1, w

	banksel PORTB
	movwf	PORTB


	return

motor_step
	movwf	FSR
	movfw	INDF
	movwf	tmp1		; read char from serial port
;	Pagesel	UARTIntPutCh
;	call	UARTIntPutCh
	movlw	0x7F		; ignore MSB
	andwf	tmp1, w
	btfsc	STATUS, Z
	return				; count reached zero, do nothing
	
	bsf		STPMDIR, 3	; set status to not done
	decf	INDF, f		; else dec, count

;	movfw	INDF
;	Pagesel	UARTIntPutCh
;	call	UARTIntPutCh

	movlw	STPM1 - STPMV1
	addwf	FSR, f
	movfw	INDF		; w is the current bit pattern for stepper

	btfsc	tmp1, 7
	goto	motor_step_fwd

	call	step_reverse
	goto    motor_step_cont
motor_step_fwd
	call	step_forward
motor_step_cont
	movwf	INDF
	return


step_forward
	goto shift_left_nibble

step_reverse
	goto shift_right_nibble

shift_left_nibble
	movwf	tmp2
	movwf	tmp1
	bcf		STATUS,C
	btfsc	tmp1, 3
	bsf		STATUS,C
	rlf		tmp1, f
	movlw	0x0F
	andwf	tmp1, f
	movlw	0xF0
	andwf	tmp2, w
	iorwf	tmp1, w
	return

shift_right_nibble
	movwf	tmp2
	movwf	tmp1
	movlw	0x0F
	andwf	tmp1, f
	btfsc	tmp1, 0
	bsf		tmp1, 4	
;	bcf		STATUS, C
	rrf		tmp1, f

	movlw	0xF0
	andwf	tmp2,w
	iorwf	tmp1,w
	return



delay
	movwf	d4
delay_loop
	call	SleepH
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
