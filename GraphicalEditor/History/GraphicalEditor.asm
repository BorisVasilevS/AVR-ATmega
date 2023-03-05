.include "m8535def.inc"

.equ memory = 0x100

.def cursor_pos = R20 // (7 - 4) - number of seg, 3 - isOn (2 - 0) - number of position from 1 to 7

.org 0x0
	rjmp RESET ; Reset Handler
	rjmp EXT_INT0 ; IRQ0 Handler
.org 0x2
	rjmp EXT_INT1 ; IRQ1 Handler
.org 0x003
	rjmp TIM2_COMP ; Timer2 Compare Handler
.org 0x004
//	rjmp TIM2_OVF ; Timer2 Overflow Handler
//	rjmp TIM1_CAPT ; Timer1 Capture Handler
//	rjmp TIM1_COMPA ; Timer1 Compare A Handler
//	rjmp TIM1_COMPB ; Timer1 Compare B Handler
//	rjmp TIM1_OVF ; Timer1 Overflow Handler
.org 0x009
	rjmp TIM0_OVF ; Timer0 Overflow Handler
//	rjmp SPI_STC ; SPI Transfer Complete Handler
//	rjmp USART_RXC ; USART RX Complete Handler
//	rjmp USART_UDRE ; UDR Empty Handler
//	rjmp USART_TXC ; USART TX Complete Handler
//	rjmp ADC ; ADC Conversion Complete Handler
//	rjmp EE_RDY ; EEPROM Ready Handler
//	rjmp ANA_COMP ; Analog Comparator Handler
//	rjmp TWSI ; Two-wire Serial Interface Handler
//	rjmp EXT_INT2 ; IRQ2 Handler
//	rjmp TIM0_COMP ; Timer0 Compare Handler
//	rjmp SPM_RDY ; Store Program Memory Ready Handler

.org 0x15
RESET:
/***********STACK*************/

	ldi r16, LOW(RAMEND)
	out SPL, r16
	ldi r16, HIGH(RAMEND)
	out SPH, r16


	rcall InitPeriph
	rcall InitStart
/*	rcall ToggleCursor//100 us
	rcall AllON//90 us
	rcall AllOFF//90 us
	rcall DISPLAY//600 us
	*/
	sei

LOOP:

	rjmp LOOP

InitPeriph:
/*********DisplayInit*********/

	ldi r16, (0b11<<0)
	out DDRC, r16

/*********Keyboard************/

	ldi r16, (1<<4) | (1<<5) | (1<<6) | (1<<7)
	out DDRB, r16
	ldi r16, (0<<5) | (0<<6) | (0<<7)
	out DDRD, r16

/**********timer0 - update display (30 GHz)****/

	ldi r16, (1<<WGM01) | (0<<WGM00) | (0b101<<CS00)
	out TCCR0, r16
	in r16, TIMSK
	ori r16, 1
	out TIMSK, r16
	ldi r16, 250
	out OCR0, r16

/**********timer2 - generation and moving ships(bse freq 2 GHz)****/

	ldi r16, (1<<WGM21) | (0<<WGM20) | (0b111<<CS20)
	out TCCR2, r16
	in r16, TIMSK
	ori r16, (1<<OCIE2)
	out TIMSK, r16
	ldi r16, 243
	out OCR2, r16

/****ext int 0******************/

	ldi r16, (1<<PD2)|(1<<PD3)
	out DDRD, r16

	ldi r16, (1<<ISC11)|(0<<ISC10)|(1<<ISC01)|(0<<ISC00)
	out MCUCR, r16

	ldi r16, (1<<INT1)|(1<<INT0)
	out GICR, r16


	sbi DDRD, 4
ret

InitStart:
	rcall AllOFF
	ldi cursor_pos, 0b00100101
ret

SEGNUM:
	push r16
	push r18

		mov r16, cursor_pos
		clr r18
	SEGNUM_START:
		
		lsl r16
		brcs SEGNUM_OUT
		inc r18
		rjmp SEGNUM_START

	SEGNUM_OUT:
		mov r0, r18//num of segment

	pop r18
	pop r16
ret

MovLeft:

ret

ToggleCursor:
	push r16
	push r17
	push r18

		mov r16, cursor_pos
		clr r18
	SEGNUM_START:
		
		lsl r16
		brcs SEGNUM_OUT
		inc r18
		rjmp SEGNUM_START

	SEGNUM_OUT:
		mov r0, r18//num of segment
		rcall LoadSegment
		mov r16, cursor_pos
		andi r16, 0b00000111
		ldi r18, 0b00000001 //mask

	SEGPOS_START:

		dec	r16
		breq SEGPOS_OUT
		lsl r18
		rjmp SEGPOS_START

	SEGPOS_OUT:
		
		sbrs cursor_pos, 3 //1 - bil vkluchen, 0 - bil vikluchen
		rjmp CURSOR_OFF
		andi cursor_pos, 0b11110111
		//nuzhno vikluchit'
		com r18
		and r17, r18
		mov r18, r0
		rcall StoreSegment
		
		rjmp ToggleCursor_OUT

	CURSOR_OFF:
		ori cursor_pos, 0b00001000
		ori r18, 0b10000000
		or r17, r18
		mov r18, r0
		rcall StoreSegment

	ToggleCursor_OUT:

	pop r18
	pop r17
	pop r16
ret

KeyboardScan:
	push r17
	push r18
	push r19
	push r20

		clr r16
		ldi r17, 0b11101111 //mask
	PORTB_ROLL:
		ldi r20, 3
		in r18, PORTB
		ori r18, 0b11110000
		and r18, r17
		out PORTB, r18
		nop
		nop

		in r19, PIND
		swap r19
		ror r19
	PIND_SCAN:
		inc r16	
		ror r19
		brcc KeyboardScan_OUT

		dec r20
		brne PIND_SCAN

		sec
		rol r17
		brcs PORTB_ROLL
		clr r16

	KeyboardScan_OUT:

	pop r20
	pop r19
	pop r18
	pop r17
ret

DISPLAY:
	push r18
	in r18,SREG
	push r18

		ldi r18, 0
	DISPLAY_START:
		rcall LoadSegment
		rcall SevenSegment
		inc r18
		cpi r18, 4
		brne DISPLAY_START

	pop r18
	out SREG, r18
	pop r18
ret

StoreSegment:
		ldi zl, LOW(memory)
		ldi zh, HIGH(memory)
		add ZL, r18
		BRCC StoreSegment_C
		INC ZH
	StoreSegment_C:
		st Z, r17
ret

LoadSegment:
		ldi ZL, LOW(memory)
		ldi ZH, HIGH(memory)
		add ZL, r18
		BRCC LoadSegment_C
		INC ZH
	LoadSegment_C:
		ld r17, Z
ret

SevenSegment:
	push r16

		ldi r16, 8
		start:
		lsl r17
		brcc C0
		sbi PORTC, 1
		rjmp clock
	C0:
		cbi PORTC, 1
		nop
		nop
	clock:
		sbi PORTC, 0
		nop
		nop
		cbi PORTC, 0
		dec r16
		brne start

	pop r16
ret

AllON:
	push r18
	in r18,SREG
	push r18

		ldi r18, 0
	AllON_START:
		ldi r17, 0b10000000
		rcall StoreSegment
		inc r18
		cpi r18, 4
		brne AllON_START

	pop r18
	out SREG, r18
	pop r18
ret

AllOFF:
	push r18
	in r18,SREG
	push r18

		ldi r18, 0
	AllOFF_START:
		ser r17
		rcall StoreSegment
		inc r18
		cpi r18, 4
		brne AllOFF_START

	pop r18
	out SREG, r18
	pop r18
ret

TIM0_OVF:
	push r16
	push r17
	push r18
	push r19
	push r20
	in r18,SREG
	mov r16, r18
	push r18

	
		
		rcall DISPLAY


	pop r18
	out SREG, r18
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
reti


TIM2_COMP:
	push r16
	push r17
	push r18
	in r18,SREG
	push r18

		rcall ToggleCursor
	
	pop r18
	out SREG, r18
	pop r18
	pop r17
	pop r16
reti

EXT_INT0:
	rcall AllON
reti

EXT_INT1:
	rcall AllOFF	
reti
