;
; StarWarsTheGame.asm
;
; Created: 06.11.2022 19:11:43
; Author : lolfa
;


.include "m8535def.inc"

.equ hit = 1000000/262 //do
.equ moving_ships = 1000000/294 //re
.equ moving = 1000000/349 //fa
.equ miss = 1000000/494 //si

.equ ship_up = 0xFE//0b11111110
.equ ship_down = 0xBF//0b10111111
.equ ship_set = 0xF7//0b11110111
.equ ship_clr = 0x08//0b00001000
.equ generate = 0xAA//0b10101010
.equ top_level = 0b10101010
.equ bottom_level = 0b01010101
.equ memory = 0x100
.equ seg4 = 0
.equ seg3 = 1
.equ seg2 = 2
.equ seg1 = 3
.equ speed_def = 0x1F
.def sound = R19 //1 - hit, 2 - miss, 3 - mov ships, 4 - mov to wall
.def score = R20
.def status = R21
.def player_msk = R22 //11001111 - 1 pos
.def player_pos = R23 //0 - 1 - 2 - 3
.def counter = R24
.def speed = R25
.org 0x0
	rjmp RESET ; Reset Handler
//	rjmp EXT_INT0 ; IRQ0 Handler
.org 0x2
	rjmp EXT_INT1 ; IRQ1 Handler
.org 0x003
	rjmp TIM2_COMP ; Timer2 Compare Handler
.org 0x004
//	rjmp TIM2_OVF ; Timer2 Overflow Handler
//	rjmp TIM1_CAPT ; Timer1 Capture Handler
//	rjmp TIM1_COMPA ; Timer1 Compare A Handler
//	rjmp TIM1_COMPB ; Timer1 Compare B Handler
.org 0x008
	rjmp TIM1_OVF ; Timer1 Overflow Handler
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

/*********DisplayInit*********/

	ldi r16, (0b11<<0)
	out DDRC, r16

/*********Keyboard************/
	ldi r16, (1<<4) | (1<<5) | (1<<6) | (1<<7)
	out DDRB, r16
	ldi r16, (0<<5) | (0<<6) | (0<<7)
	out DDRD, r16
/*****init start didsplay*****/
//rcall UPDATE_SHIPS
	rcall INIT_STARTGAME

/**********timer0 - update display (30 GHz)****/
	ldi r16, (1<<WGM01) | (0<<WGM00) | (0b011<<CS00)
	out TCCR0, r16
	in r16, TIMSK
	ori r16, 1
	out TIMSK, r16
	ldi r16, 255
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
	ldi r16, 1<<PD2
	out DDRD, r16

	ldi r16, (1<<ISC11)|(0<<ISC10)
	out MCUCR, r16

	ldi r16, (1<<INT1)
	out GICR, r16

/**********16-bit timer****************************/
	ldi r16, (0<<WGM11)|(0<<WGM10)|(0b01<<COM1B0)
	out TCCR1A, r16
	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b000<<CS10)
	out TCCR1B, r16

	sbi DDRD, 4

	sei
	;set

LOOP:
	brtc S1
LOOP_GAMEOVER:
	in r16, TIMSK
	andi r16, 0xFE
	out TIMSK, r16
	rcall DELAY_500
	mov r18, score
	rcall SCORE_IND
LOOP_GAMEOVER_1:
	brts LOOP_GAMEOVER_1
	in r16, TIMSK
	ori r16, 1
	out TIMSK, r16
	rcall INIT_STARTGAME
	
S1:
	brts LOOP_GAMEOVER
	rcall KeyboardScan
	tst r16
	breq S1
	cpi r16, 1
	brne NOT_LEFT
	rcall PLAYER_LEFT
	//rcall DISPLAY
NOT_LEFT:
	cpi r16, 2
	brne NOT_SHOOT
	rcall SHOOT
	//rcall DISPLAY
NOT_SHOOT:
	cpi r16, 3
	brne S2
	rcall PLAYER_RIGHT
	//rcall DISPLAY
S2:
	rcall KeyboardScan
	tst r16
	brne S2


	rjmp LOOP

/***********SubPrograms***********/
Generation:
	ldi r16, 0b10101010//7 bit - 1 ship, 6 bit - 1 ship na positciu nizhe i td
	or status, r16
ret

/*******************************/
DELAY_500:
push r20
push r21
push r22

    ldi  r20, 5
    ldi  r21, 138
    ldi  r22, 86
L1: dec  r22
    brne L1
    dec  r21
    brne L1
    dec  r20
    brne L1

pop r22
pop r21
pop r20
ret
/********************************/
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
/*******************************/

INIT_STARTGAME:
push r17
push r18

	clr r18
INIT_STARTGAME_LOOP:
	ser r17
	rcall StoreSegmets
	inc r18
	cpi r18, 4
	brne INIT_STARTGAME_LOOP

	ldi status, generate
	ldi player_pos, 1
	ldi player_msk, 0b11001111
	rcall UPDATE_SHIPS
	rcall PLAYER_UPDATE
	rcall DISPLAY
	clr score
	ldi speed, speed_def
	clt

pop r17
pop r18
ret
/********************************/
/* MUST CHECK GAME END CONDITION*/
MOV_SHIPS:
push r16
push r17

	lsr status
	ldi r16, 0b01010101 //ochistka lishnego
	and status, r16

	ldi sound, 3
/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                  3 - ships mov                                                                        */
	/*souond of moving*/
/*----------------------------------------------------------*/
	ldi sound, HIGH(moving_ships/2)
	out OCR1AH, r16
	ldi sound, LOW(moving_ships/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16
	
	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1 OCIE1A
	out TIMSK, r16
/*----------------------------------------------------------*/


pop r17
pop r16
	ret

/********************************/
GAME_OVER:
push r16
push r17

	ldi r16, 0
GAME_OVER_START:
	ldi ZL, LOW(GAMEOVER*2)
	ldi ZH, HIGH(GAMEOVER*2)
	add ZL, r16
	brcc NTS
	inc ZH
NTS:
	lpm r17, Z
	rcall SEV_SEG
	rcall DELAY_500
	inc r16
	cpi r16,11
	brne GAME_OVER_START

pop r16
pop r17
ret
/*******************************/
UPDATE_SHIPS:
push r16
push r17
push r18
push r19
push r20
in r18,SREG
push r18

	clr r16
	clr r17
	clr r18
	clr r19
	clr r20	

	ldi r16, 0x80 //maska proverki koroblya
SEG:	
	mov r17, status
	and r17, r16
	brne SEG_SET
	ser r17
	rjmp SEG_OUT
SEG_SET:	
	sbrs r19, 0 //proverka na chetnost'
	ldi r17, ship_up
	sbrc r19, 0
	ldi r17, ship_down
SEG_OUT:
	inc r19
	cpi r19, 2
	brne SEG_OUT_2
	clr r19
	and r20, r17//polozhenie korabley
	rcall LoadSegments	//to chto est' na ekrane
	ori r17, 0b01000001//clearing old position
	and r17, r20
	rcall StoreSegmets
	inc r18
SEG_OUT_2:
	mov r20, r17
	lsr r16
	cpi r18, 4
	brne SEG

pop r18
out SREG, r18
pop r20
pop r19
pop r18
pop r17
pop r16
ret
/*******************************/
DISPLAY:
push r18
in r18,SREG
push r18

	rcall UPDATE_SHIPS
	rcall PLAYER_UPDATE

	ldi r18, 0
DISPLAY_START:
	rcall LoadSegments
	rcall SEV_SEG
	inc r18
	cpi r18, 4
	brne DISPLAY_START

pop r18
out SREG, r18
pop r18
ret
/*******************************/
//sohranyaet r17 v yacheyku pod nimerom r18
StoreSegmets:
	ldi zl, LOW(memory)
	ldi zh, HIGH(memory)
	add ZL, r18
	BRCC StoreSegmets_C
	INC ZH
StoreSegmets_C:
	st Z, r17
	ret
/*******************************/
//zagruzhaet to chto pod nomerom r18 v r17
LoadSegments:
	ldi ZL, LOW(memory)
	ldi ZH, HIGH(memory)
	add ZL, r18
	BRCC LoadSegments_C
	INC ZH
LoadSegments_C:
	ld r17, Z
ret
/*******************************/
PLAYER_RIGHT:
push r16
push r17
push r18

	ldi r16, 2
	cpi player_pos, 3
	breq PLAYER_RIGHT_OUT
	mov r18, player_pos
	rcall LoadSegments
	ori r17, ship_clr
	rcall StoreSegmets
	inc player_pos
	mov r18, player_pos
	rcall LoadSegments
	andi r17, ship_set
	rcall StoreSegmets

PLAYER_RIGHT_MOV:
	sec
	ror player_msk
	dec r16
	brne PLAYER_RIGHT_MOV
PLAYER_RIGHT_OUT:

/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                 4 - moving                                                                       */
/*----------------------------------------------------------*/
	ldi sound, HIGH(moving/2)
	out OCR1AH, r16
	ldi sound, LOW(moving/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16
	
	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1
	out TIMSK, r16
/*----------------------------------------------------------*/

pop r18
pop r17
pop r16
ret
/*******************************/
PLAYER_LEFT:
push r16
push r17
push r18

	ldi r16, 2
	cpi player_pos, 0
	breq PLAYER_LEFT_OUT
	mov r18, player_pos
	rcall LoadSegments
	ori r17, ship_clr
	rcall StoreSegmets
	dec player_pos
	mov r18, player_pos
	rcall LoadSegments
	andi r17, ship_set
	rcall StoreSegmets
PLAYER_LEFT_MOV:
	sec
	rol player_msk
	dec r16
	brne PLAYER_LEFT_MOV
PLAYER_LEFT_OUT:

/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                 4 - moving   */
/*----------------------------------------------------------*/
	ldi sound, HIGH(moving/2)
	out OCR1AH, r16
	ldi sound, LOW(moving/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16
	
	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1
	out TIMSK, r16
/*----------------------------------------------------------*/

pop r18
pop r17
pop r16
ret
/*******************************/
PLAYER_UPDATE:
push r17
push r18

	mov r18, player_pos
	rcall LoadSegments
	andi r17, ship_set
	rcall StoreSegmets

pop r18
pop r17
ret
/*******************************/

SEV_SEG:
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
/*******************************/

SCORE_IND:
push r17
push r21
push r22
push r23
	ldi r21, 0
	ldi r20, 0
	ldi r19, 0
	Sot:
	subi r18, 100
	brcs dec_0
	inc r21
	rjmp Sot
	dec_0:
	ldi r22 , 100
	add r18, r22
	Desyatka:
	subi r18, 10
	brcs dec_1
	inc r20
	rjmp Desyatka
	dec_1:
	ldi r22, 10
	add r18,r22
	mov r19, r18


	ldi r17, 0xFF
	rcall Num_to_Seg
	rcall SEV_SEG

	mov r17, r21
	rcall Num_to_Seg
	rcall SEV_SEG

	mov r17, r20
	rcall Num_to_Seg
	rcall SEV_SEG

	mov r17, r19
	rcall Num_to_Seg
	rcall SEV_SEG
pop r23
pop r22
pop r21
pop r17
	ret
/*******************************/
Num_to_Seg:
	ldi ZL, LOW(NUMBERS*2)
	ldi ZH, HIGH(NUMBERS*2)
	add ZL, r17

	brcc NTS_1
	inc ZH

NTS_1:
	lpm r17, Z
ret
/*******************************/
SHOOT:
push r16
push r17

	mov r16, status
	andi r16, bottom_level
	mov r17, r16
	and r17, player_msk
	sub r16, r17
	brne SHOOT_HIT_BOT
	mov r16, status
	andi r16, top_level
	mov r17, r16
	and r17, player_msk
	sub r16, r17
	breq SHOOT_MISSED
	inc score /*hit top level*/
	ldi sound, 1

/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                 1 - hit                                                                        */
/*----------------------------------------------------------*/
	ldi sound, HIGH(hit/2)
	out OCR1AH, r16
	ldi sound, LOW(hit/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16
	
	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1
	out TIMSK, r16
/*----------------------------------------------------------*/
	mov r17, player_msk //to not change original player pos
	ori r17, bottom_level
	and status, r17
	rjmp SHOOT_OUT
SHOOT_HIT_BOT:
	inc score /*hit low level*/

/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                 1 - hit                                                                        */

/*----------------------------------------------------------*/
	ldi sound, HIGH(hit/2)
	out OCR1AH, r16
	ldi sound, LOW(hit/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16
	
	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1
	out TIMSK, r16
/*----------------------------------------------------------*/

	mov r17, player_msk
	ori r17, top_level //inversion logic bc ...
	and status, r17
	rjmp SHOOT_OUT
	/*hit -> sound of destruction*/
SHOOT_MISSED:
/*----------------------------------------------------------*/
	ldi sound, HIGH(miss/2)
	out OCR1AH, r16
	ldi sound, LOW(miss/2)
	out OCR1AL, sound

	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b001<<CS10)
	out TCCR1B, r16

	in r16, TIMSK
	ori r16, (0b101<<2) //TOIE1
	out TIMSK, r16
/*----------------------------------------------------------*/
/*vkluchenie 16 bit timer s prerivaniem v kotorom idet otschet + zagruzka sootvetstv chastoti
                 2 - miss                                                                        */
/*sound of miss*/
SHOOT_OUT:
rcall UPDATE_SHIPS

pop r17
pop r16
ret
/***********Interupts***********/
TIM0_OVF:
push r16
push r17
push r18
push r19
push r20
in r18,SREG
mov r16, r18
push r18

	
	sbrs r16, 6 //check flag T
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
push r19
push r20
in r18,SREG
mov r16, r18
push r18

	sbrc r16, 6// flag T check
	rjmp TIM2_OVF_EXIT
	cp counter, speed
	brne TIM2_OVF_OUT
	clr counter
	mov r16, status
	andi r16, bottom_level
	brne LOSE
	lsr status
	ori status, top_level //generation acn be random
	rjmp TIM2_OVF_OUT

LOSE:
	set
//	mov r16, status
	clr status
	rcall UPDATE_SHIPS
	clr r20 // счетчик позиции
	clr r17 //счнтчик сдвига
	ldi r18, 1 //счетчик четности
	

TIM2_OVF_LOSE_START:
	lsl r16
	in r19, SREG
	cpi r18, 2
	brne TIM2_OVF_LOSE_cnt
	clr r18
	inc r20
	sbrs r19, 0//check C flag
	rjmp TIM2_OVF_LOSE_cnt
	dec r20
	mov player_pos, r20
	inc r20
	rcall PLAYER_UPDATE
	

TIM2_OVF_LOSE_cnt:
	inc r17
	inc r18
	cpi r17, 8
	brne TIM2_OVF_LOSE_START

TIM2_OVF_OUT:
	inc counter
	rcall DISPLAY

TIM2_OVF_EXIT:
pop r18
in r19, SREG
sbrc r19, 6//T flag check
ori r18, (1<<6)

out SREG, r18
pop r20
pop r19
pop r18
pop r17
pop r16
reti

EXT_INT1:
	clt
reti

TIM1_OVF:
push r16
push r17
push r18
push r19
push r20
in r18,SREG
push r18

	cpi r26, 200
	brne TIM1_OVF_OUT
	clr r26
	inc r27
	cpi r27, 1
	brne TIM1_OVF_OUT
	clr r27
	ldi r16, (0<<WGM13)|(1<<WGM12)|(0b000<<CS10)
	out TCCR1B, r16
	in r16, TIMSK
	andi r16, 0b11101011 //TOIE1
	out TIMSK, r16

TIM1_OVF_OUT:

pop r18
out SREG, r18
pop r20
pop r19
pop r18
pop r17
pop r16
reti

//User Data
GAMEOVER:
.db 0xC2, 0x88, 0xAB, 0x86, 0xFF, 0xC0, 0xC1, 0x86, 0x8A, 0xFF, 0xFF
NUMBERS:
.DB 0b11000000, 0b11111001, 0b10100100, 0b10110000, 0b10011001, 0b10010010, 0b10000010, 0b11111000, 0b10000000, 0b10010000 

