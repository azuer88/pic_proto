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
STPMDIR			RES 01					;Durrent direction of stepper 1=fwd, 0=rev bit1=m1, bit2=m2, bit3=m3
STPM1			RES 01					;For Stepper motor 1 current bit
STPM2			RES 01	
STPM3			RES 01
tmp1			RES 01					;Temp vars for nibble shifting
tmp2			RES 01

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
	movwf	STPMDIR
	call  	run_motors


;Change the pre-claculated baudrate, If required
;        mSetUARTBaud    .9600


        banksel vUARTIntStatus
WaitRxData
;Check if Receive buffer is full        
        btfss   vUARTIntStatus,UARTIntRxBufFul
        goto    WaitRxData

; setup indirect addressing
        movf     STPM1,W                ;STPM1..3 are on shared and will always
        addlw    low(STPM1)             ;be available.
        movwf   FSR    

;If receive buffer is full then read the data
ReadAgain
        Pagesel UARTIntGetCh
        call    UARTIntGetCh

		; save data	assumes buffer is 3 bytes long	
		movwf	INDF

;check if Tx buffer is empty
        banksel vUARTIntStatus
WaitForTxBufEmpty
        btfsc   vUARTIntStatus,UARTIntTxBufFul
        goto    WaitForTxBufEmpty

;Echo back the received data                
        Pagesel UARTIntPutCh
        call    UARTIntPutCh

;Check if Rx Buffer is empty. If not keep reading it.
        banksel vUARTIntStatus
        btfss   vUARTIntStatus,UARTIntRxBufEmpty
        goto    ReadAgain


		call	move_motors

	;Display OK
		movlw   'O'
		Pagesel UARTIntPutCh
		call    UARTIntPutCh
		movlw   'K'
		call    UARTIntPutCh
		movlw   '.'
		call    UARTIntPutCh

        goto    WaitRxData

move_motors
	; transfer direction bit to STPMDIR	
	movlw	0xFF - 7
	andwf	STPMDIR, f
	btfsc	STPMV1, 7
	bsf		STPMDIR, 0
	btfsc	STPMV2, 7
	bsf		STPMDIR, 1
	btfsc	STPMV3, 7
	bsf		STPMDIR, 2
	; clear last bit of all STPMV, so we can use it as counters
	bcf		STPMV1, 7
	bcf		STPMV2, 7
	bcf		STPMV3, 7

	; process stepper motor 1
stp_m1
	movf	STPMV1, w
	addlw	0
	btfsc	STATUS, Z
	goto    stp_m1_backward
	
	decf	STPMV1, f

	movf	STPM1, w
	btfss	STPMDIR, 0
	goto	stp_m1_backward

	call 	step_forward
	goto    stp_m1_continue
stp_m1_backward
	call	step_reverse

stp_m1_continue
	movwf	STPM1
stp_m2
	movf	STPMV2, w
	addlw	0
	skpz	stp_m3
	
	decf	STPMV2, f

	movf	STPM2, w
	btfss	STPMDIR, 1
	goto	stp_m2_backward

	call 	step_forward
	goto    stp_m2_continue
stp_m2_backward
	call	step_reverse

stp_m2_continue
	movwf	STPM2

stp_m3
	movf	STPMV3, w
	addlw	0
	skpz	run_motors
	
	decf	STPMV3, f

	movf	STPM3, w
	btfss	STPMDIR, 2
	goto	stp_m3_backward

	call 	step_forward
	goto    stp_m3_continue
stp_m3_backward
	call	step_reverse

stp_m3_continue
	movwf	STPM3

run_motors
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

        END
