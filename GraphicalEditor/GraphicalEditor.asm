.include "m8535def.inc"

.equ memory_s = 0x100
.equ memory_c = 0x126

.def cursor_pos = R22 // (7 - 4) - number of seg, 3 - isOn (2 - 0) - number of position from 1 to 7

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
	set
	sei
	
LOOP:

	SCAN_START:
		rcall KeyboardScan
		tst r16
		breq SCAN_START
		cpi r16, 1
		breq CURSOR_ON_OFF
		cpi r16, 2
		breq UP
		cpi r16, 3
		breq INVERT
		cpi r16, 4
		breq LEFT
		cpi r16, 5
		breq ROTATE
		cpi r16, 6
		breq RIGHT
		cpi r16, 8
		breq DOWN
		cpi r16, 10
		breq FILL
		cpi r16, 11
		breq INVERSE
		cpi r16, 12
		breq CLEAR

	CURSOR_ON_OFF:
		in r16, SREG
		sbrc r16, 6
		clt
		sbrs r16, 6
		set
		rjmp SCAN_OUT
	UP:
		rcall MovUp
		rjmp SCAN_OUT
	LEFT:
		rcall MovLeft
		rjmp SCAN_OUT
	ROTATE:
		rcall MovRotate
		rjmp SCAN_OUT
	RIGHT:
		rcall MovRight
		rjmp SCAN_OUT
	DOWN:
		rcall MovDown
		rjmp SCAN_OUT
	INVERT:
		rcall AllINVERT
		rjmp SCAN_OUT
	FILL:
		rcall LightOn
		rjmp SCAN_OUT
	INVERSE:
		rcall LightInvert
		rjmp SCAN_OUT
	CLEAR:
		rcall LightOff

	SCAN_OUT:
		rcall KeyboardScan
		tst r16
		brne SCAN_OUT


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
	rcall ClearCursor
	ldi cursor_pos, 0b00010110
	rcall ToggleCursor
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

CreateMask:
	push r16
	push r18

		mov r16, cursor_pos
		andi r16, 0b00000111
		ldi r18, 0b00000001 //mask

	CreateMask_START:

		dec	r16
		breq CreateMask_OUT
		lsl r18
		rjmp CreateMask_START

	CreateMask_OUT:
		mov r1, r18

	pop r18
	pop r16
ret

MovLeft:
	push r16
	push r17
	push r18

		sbrs cursor_pos, 3
		rcall ToggleCursor
		rcall SEGNUM
		mov r18, r0
		mov r16, cursor_pos
		andi r16, 0b00000111
		cpi r16, 7
		breq ML_147
		cpi r16, 6
		breq ML_6
		cpi r16, 5
		breq ML_5
		cpi r16, 4
		breq ML_147
		cpi r16, 3
		breq ML_3
		cpi r16, 2
		breq ML_2
		//case 1
		ML_147:
			cpi r18, 0
			breq MovLeft_OUT
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsl r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
			rjmp MovLeft_OUT
		ML_2:
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			rjmp MovLeft_OUT
		ML_3:
			inc cursor_pos
			inc cursor_pos
			rjmp MovLeft_OUT
		ML_6:
			cpi r18, 0
			breq MovLeft_OUT
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsl r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
			rjmp MovLeft_OUT
		ML_5:
			cpi r18, 0
			breq MovLeft_OUT
			dec cursor_pos
			dec cursor_pos
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsl r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
		MovLeft_OUT:

	pop r18
	pop r17
	pop r16
ret

MovRight:
	push r16
	push r17
	push r18

		sbrs cursor_pos, 3
		rcall ToggleCursor
		rcall SEGNUM
		mov r18, r0
		mov r16, cursor_pos
		andi r16, 0b00000111
		cpi r16, 7
		breq MR_147
		cpi r16, 6
		breq MR_6
		cpi r16, 5
		breq MR_5
		cpi r16, 4
		breq MR_147
		cpi r16, 3
		breq MR_3
		cpi r16, 2
		breq MR_2
		//case 1
		MR_147:
			cpi r18, 3
			breq MovRight_OUT
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsr r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
			rjmp MovRight_OUT
		MR_2:
			cpi r18, 3
			breq MovRight_OUT
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos	
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsr r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
			rjmp MovRight_OUT
		MR_3:
			cpi r18, 3
			breq MovRight_OUT
			inc cursor_pos
			inc cursor_pos
			mov r17, cursor_pos
			andi r17, 0b11110000
			lsr r17
			andi cursor_pos, 0b00001111
			or cursor_pos, r17
			rjmp MovRight_OUT
		MR_5:
			dec cursor_pos
			dec cursor_pos
			rjmp MovRight_OUT
		MR_6:
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			
		MovRight_OUT:

	pop r18
	pop r17
	pop r16
ret

MovUp:
	push r16
	push r17
	push r18

		sbrs cursor_pos, 3
		rcall ToggleCursor
		rcall SEGNUM
		mov r18, r0
		mov r16, cursor_pos
		andi r16, 0b00000111
		cpi r16, 7
		breq MU_7
		cpi r16, 6
		breq MU_126
		cpi r16, 5
		breq MU_5
		cpi r16, 4
		breq MU_4
		cpi r16, 3
		breq MU_3
		cpi r16, 2
		breq MU_126
		cpi r16, 1
		breq MovUp_OUT
	
		MU_126:
			rjmp MovUp_OUT
		MU_3:
			dec cursor_pos
			rjmp MovUp_OUT
		MU_5:
			inc cursor_pos
			rjmp MovUp_OUT
		MU_4:
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			rjmp MovUp_OUT
		MU_7:
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
	
		MovUp_OUT:

	pop r18
	pop r17
	pop r16
ret

MovDown:
	push r16
	push r17
	push r18

		sbrs cursor_pos, 3
		rcall ToggleCursor
		rcall SEGNUM
		mov r18, r0
		mov r16, cursor_pos
		andi r16, 0b00000111
		cpi r16, 7
		breq MD_7
		cpi r16, 6
		breq MD_6
		cpi r16, 5
		breq MD_345
		cpi r16, 4
		breq MD_345
		cpi r16, 3
		breq MD_345
		cpi r16, 2
		breq MD_2
		cpi r16, 1
		breq MD_1
	
		MD_1:
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			rjmp MovDown_OUT
		MD_2:
			inc cursor_pos
			rjmp MovDown_OUT
		MD_345:
			rjmp MovDown_OUT
		MD_6:
			dec cursor_pos
			rjmp MovDown_OUT
		MD_7:
			dec cursor_pos
			dec cursor_pos
			dec cursor_pos
		MovDown_OUT:

	pop r18
	pop r17
	pop r16
ret

MovRotate:
	push r16
	push r17
	push r18

		sbrs cursor_pos, 3
		rcall ToggleCursor
		rcall SEGNUM
		mov r18, r0
		mov r16, cursor_pos
		andi r16, 0b00000111
		cpi r16, 7
		breq MRR_7
		cpi r16, 6
		breq MRR_6
		cpi r16, 5
		breq MRR_5
		cpi r16, 4
		breq MRR_34
		cpi r16, 3
		breq MRR_34
		cpi r16, 2
		breq MRR_12
		cpi r16, 1
		breq MRR_12
		MRR_12:
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			inc cursor_pos
			rjmp MovRotate_OUT
		MRR_34:
			inc cursor_pos
			rjmp MovRotate_OUT
		MRR_5:
			dec cursor_pos
			rjmp MovRotate_OUT
		MRR_6:
			inc cursor_pos
			rjmp MovRotate_OUT
		MRR_7:
			dec cursor_pos
		MovRotate_OUT:

	pop r18
	pop r17
	pop r16
ret

LightOn:
	push r16
	push r17
	push r18

		rcall SEGNUM
		mov r18, r0
		rcall LoadSegment_s
		rcall CreateMask
		mov r18, r1
		com r18
		and r17, r18
		mov r18, r0
		rcall StoreSegment_s

	pop r18
	pop r17
	pop r16
ret

LightOff:
	push r16
	push r17
	push r18

		rcall SEGNUM
		mov r18, r0
		rcall LoadSegment_s
		rcall CreateMask
		mov r18, r1
		or r17, r18
		mov r18, r0
		rcall StoreSegment_s

	pop r18
	pop r17
	pop r16
ret

LightInvert:
	push r16
	push r17
	push r18

		rcall SEGNUM
		mov r18, r0
		rcall LoadSegment_s
		rcall CreateMask
		mov r18, r1
		mov r16, r17
		and r16, r18
		breq turnOn
		com r18
		and r17, r18
		rjmp LightInvert_OUT
	turnOn:
		or r17, r18
	LightInvert_OUT:
		mov r18, r0
		rcall StoreSegment_s

	pop r18
	pop r17
	pop r16
ret

ToggleCursor:
	push r16
	push r17
	push r18

		rcall SEGNUM
		mov r18, r0
		rcall LoadSegment_c
		rcall CreateMask
		mov r18, r1
		
		sbrs cursor_pos, 3 //1 - bil vkluchen, 0 - bil vikluchen
		rjmp CURSOR_OFF
		brts CURSOR_OFF
		andi cursor_pos, 0b11110111
		//nuzhno vikluchit'
		com r18
		and r17, r18
		mov r18, r0
		rcall StoreSegment_c
		
		rjmp ToggleCursor_OUT

	CURSOR_OFF:
		ori cursor_pos, 0b00001000
		ori r18, 0b10000000
		or r17, r18
		mov r18, r0
		rcall StoreSegment_c

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
		rcall LoadSegment_s
		mov r16, r17
		rcall LoadSegment_c
		and r17, r16
		rcall SevenSegment
		inc r18
		cpi r18, 4
		brne DISPLAY_START

	pop r18
	out SREG, r18
	pop r18
ret

StoreSegment_c:
		ldi zl, LOW(memory_c)
		ldi zh, HIGH(memory_c)
		add ZL, r18
		BRCC StoreSegment_c_C
		INC ZH
	StoreSegment_c_C:
		st Z, r17
ret

StoreSegment_s:
		ldi zl, LOW(memory_s)
		ldi zh, HIGH(memory_s)
		add ZL, r18
		BRCC StoreSegment_s_C
		INC ZH
	StoreSegment_s_C:
		st Z, r17
ret

LoadSegment_c:
		ldi ZL, LOW(memory_c)
		ldi ZH, HIGH(memory_c)
		add ZL, r18
		BRCC LoadSegment_c_C
		INC ZH
	LoadSegment_c_C:
		ld r17, Z
ret

LoadSegment_s:
		ldi ZL, LOW(memory_s)
		ldi ZH, HIGH(memory_s)
		add ZL, r18
		BRCC LoadSegment_s_C
		INC ZH
	LoadSegment_s_C:
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
		rcall StoreSegment_s
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
		rcall StoreSegment_s
		inc r18
		cpi r18, 4
		brne AllOFF_START

	pop r18
	out SREG, r18
	pop r18
ret

AllINVERT:

	ldi r18, 0
	AllINVERT_START:
		rcall LoadSegment_s
		com r17
		ori r17, 0x80
		rcall StoreSegment_s
		inc r18
		cpi r18, 4
		brne AllINVERT_START
ret

ClearCursor:
	push r18


		ldi r18, 0
	ClearCursor_START:
		ser r17
		rcall StoreSegment_c
		inc r18
		cpi r18, 4
		brne ClearCursor_START

	pop r18
ret

TIM0_OVF:
	push r16
	push r17
	push r18
	push r19
	push r20
	in r18,SREG
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
