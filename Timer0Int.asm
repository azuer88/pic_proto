        include <P16f877A.INC>

#define __Timer0IntSource 

		include "Timer0Int.inc"

Timer0IntData	udata
	timer0Delay	res 1

	m1			res 1  ; these are the counter initializers
	m2			res 1
	m3			res 1
 
	mc			res 1  ; this is the count for the '1' mcx motor
	mc1			res 1  ; these are the actual counters that gets decremented every timer trigger
	mc2			res 1
	mc3			res 1	
	
	

_Timer0IntCode	code 

checkmotor1
	

Timer0IntISR:
	GLOBAL Timer0IntISR
		; return

		banksel	INTCON
		btfss	INTCON, T0IF  ; check if interrupt is caused by Timer0
		return				  ; if not, exit to calling routine

		movlw	.255
		banksel PORTD
		;movfw	PORTD
		movlw	B'00010000'
		rlf		PORTD
		btfsc	STATUS,C
		movwf	PORTD
		;xorwf	PORTB, f
	

		banksel INTCON
		bcf		INTCON, T0IF	; clear Timer0 interrupt flag, otherwise interrupt will not occur again
		bsf		INTCON, T0IE	; enable Timer0 interrupt again

		banksel	timer0Delay
		movfw	timer0Delay
		addlw	.255
		movwf	TMR0			; start Timer again from 6
		return


Timer0IntInit:
	GLOBAL Timer0IntInit

		movlw	b'11000111'
		;First three bits (bit«2:0») are prescaler value. We set prescaler to 1:2 (PS«2:0»=000)
		;bit 3 = 0 assigns prescaler to Timer0
		;bit 5 = 0 assigns instruction cycle as clock source
		;bit 4 = NA it assigns edge select of external clock, we use internal clock
		;bit 6 = NA
		;bit 7 = NA
		banksel	OPTION_REG
		movwf	OPTION_REG

		banksel INTCON
		bcf		INTCON, T0IF
		bsf		INTCON, T0IE

		bsf		INTCON, GIE   ; this is enable by the usart init routine

		movlw	.248
		banksel timer0Delay
		movwf	timer0Delay
		movwf	TMR0

		movlw	B'00010000'
		movwf	PORTD

		return
	

		END

