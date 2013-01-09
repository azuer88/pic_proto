
#ifndef __Timer0Int_INC           ;Check if inc file already included

#define __Timer0Int_INC


#ifndef __Timer0IntSource

;****************************************************************************
;Definations of Shared Parameters
;****************************************************************************

;    EXTERN  vTimer0IntStatus         					   ;Defined in Usart.asm
;    EXTERN  vTimer0IntTxBuffer, vTimer0IntTxBufDataCnt     ;Defined in Usart.asm
;    EXTERN  vTimer0IntRxBuffer, vTimer0IntRxBufDataCnt     ;Defined in Usart.asm

	EXTERN  timer0Delay  ; timer delay (255 - timer0delay = timer countdown)

    EXTERN  Timer0IntInit, Timer0IntISR     ;Defined in USART.asm


#else

;****************************************************************************
;Definations of Shared Parameters
;****************************************************************************

;    GLOBAL  vTimer0IntStatus         ;Defined in UsartDef.h
;    GLOBAL  vTimer0IntTxBuffer, vTimer0IntTxBufDataCnt     ;Defined in UsartDef.h
;    GLOBAL  vTimer0IntRxBuffer, vTimer0IntRxBufDataCnt     ;Defined in UsartDef.h

	GLOBAL  timer0Delay

    GLOBAL  Timer0IntInit, Timer0IntISR     ;Defined in USART.asm

#endif 

#endif

