/*
 * RGB.c
 *
 * Created: 17.12.2022 19:26:29
 * Author : lolfa
 */ 


// сделать функицию кторая по координатам расчитывает цвет и сразу выводить на экран
#ifndef F_CPU
#define F_CPU 14745000UL
#endif

/*init RGB port*/
#define DDR_RGB DDRD
#define RGB PD6

#define set_bit(port, bit_msk) port |= (1<<bit_msk)
#define set_bits(port,bits, bits_pos) port |= (bits<<bits_pos)

#define clr_bit(port, bit_msk) port &= ~(1<<bit_msk)
#define clr_bits(port,bits, bits_pos) port &= ~(bits<<bits_pos)

#define RGB_G 0x00008000
#define RGB_R 0x00800000
#define RGB_B 0x00000080

#define extra_prescaler_value 56 // f = F_CPU/(256*1024*extra_prescaler_value)
#define size_of_array_h 8
#define size_of_array_w 16

#include <avr/io.h>
#include <avr/interrupt.h>

void send_0(void);
void send_1(void);
void send_array(void);
void timer_init(void);
void set_RGB(uint32_t array[size_of_array_h][size_of_array_w]);
void set_RGB_v2(uint32_t array[size_of_array_h][size_of_array_w]); //not working
void set_RGB_v3(uint32_t array[size_of_array_h][size_of_array_w]);
void init_array(uint32_t array[size_of_array_h][size_of_array_w], uint8_t TIME);
void clear_array(uint32_t array[size_of_array_h][size_of_array_w]);
uint32_t func(uint8_t x, uint8_t y, uint8_t TIME);
uint32_t rgb(double ratio);

uint8_t ZH;
uint8_t ZL;
uint8_t R0, R1;

uint8_t extra_prescaler = 0;
uint8_t code = 0;

int main(void)
{
	uint8_t t = 0;
	uint32_t color[size_of_array_h][size_of_array_w];
	set_bit(DDR_RGB, RGB);
	asm("sei");
	t = 5; //start point
	init_array(color, t);
	set_RGB_v3(color);

	timer_init();
	while(1){
		while(code){
			if(t > 15){
				t = 0;
			}
			else{
				t++;
			}
			init_array(color, t);
			set_RGB_v3(color);
			code = 0;
		}
	}
}

/*    1/F_CPU ~ 67.8 ns = 1 takt
		0.8 us ~ 12(11.79) taktov       */
void send_1(void){
	set_bit(PORTD, RGB); //(3 takt)
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	asm("nop");
	//asm("nop");
	//asm("nop");
	//asm("nop");
	clr_bit(PORTD, RGB);
}

/*    1/F_CPU ~ 67.8 ns = 1 takt
		0.4 us ~ 6(5.89) taktov       */
void send_0(void){
		set_bit(PORTD, RGB); //(3 takt)
		asm("nop");
		asm("nop");
		asm("nop");
		//asm("nop");
		//asm("nop");
		clr_bit(PORTD, RGB);
}

void set_RGB(uint32_t array[size_of_array_h][size_of_array_w]){ 
	uint32_t msk;
	//sending same array one more time to fill 16*16 rgb
	for(unsigned char segment = 0; segment < 2; segment++){
		for(unsigned char x = 0; x < (size_of_array_w * size_of_array_h) ; x++){//(16*8)
			for(unsigned char GRB = 0; GRB < 3; GRB++){
				switch(GRB){ //G, R, B -> R, G, B
					case 0	:	msk = RGB_G;	break;
					case 1	:	msk = RGB_R;	break;
					case 2	:	msk = RGB_B;	break;
					default	:	msk = 0;		break;
				}
				for(unsigned char bit = 0; bit < 8; bit++){
					if((*(*array + x) & msk) == 0x00000000)//(**(array + counter)
					send_0();
					else
					send_1();
					msk = msk>>1;
				}
			}
		}
		set_bit(PORTD, RGB); //to prevent reset(might ruin color)
	}
}

//not working
void set_RGB_v2(uint32_t array[size_of_array_h][size_of_array_w]){ 
	uint32_t msk;
	//uint8_t segment = 0;
	for(unsigned char y = 0; y < size_of_array_h; y++){
		for(unsigned char x = 0; x < size_of_array_w ; x++){//(size_of_array_w * size_of_array_h)
			for(unsigned char GRB = 0; GRB < 3; GRB++){
				switch(GRB){
					case 0 :
					msk = RGB_G;
					break;
					case 1 :
					msk = RGB_R;
					break;
					case 2 :
					msk = RGB_B;
					break;
					default:
					msk = 0;
					break;
				}
				for(unsigned char bit = 0; bit < 8; bit++){
					if((array[y][x] & msk) == 0x00000000)//(**(array + counter)
					send_0();
					else
					send_1();
					msk = msk>>1;
				}
			}
		}
	}
}

void set_RGB_v3(uint32_t array[size_of_array_h][size_of_array_w]){
	uint32_t msk;
	for(unsigned char x = 0; x < (size_of_array_w * size_of_array_h) ; x++){
		for(unsigned char GRB = 0; GRB < 3; GRB++){
			switch(GRB){ //G, R, B -> R, G, B
				case 0	:	msk = RGB_G;	break;
				case 1	:	msk = RGB_R;	break;
				case 2	:	msk = RGB_B;	break;
				default	:	msk = 0;		break;
			}
			for(unsigned char bit = 0; bit < 8; bit++){
				if((*(*array + x) & msk) == 0x00000000)//(**(array + counter)
				send_0();
				else
				send_1();
				msk = msk>>1;
			}
		}
	}
	//sending same array one more time to fill 16*16 rgb
	for(unsigned char x = 0; x < (size_of_array_w * size_of_array_h) ; x++){//(16*8)
		for(unsigned char GRB = 0; GRB < 3; GRB++){
			switch(GRB){ //G, R, B -> R, G, B
				case 0	:	msk = RGB_G;	break;
				case 1	:	msk = RGB_R;	break;
				case 2	:	msk = RGB_B;	break;
				default	:	msk = 0;		break;
			}
			for(unsigned char bit = 0; bit < 8; bit++){
				if((*(*array + x) & msk) == 0x00000000)//(**(array + counter)
				send_0();
				else
				send_1();
				msk = msk>>1;
			}
		}
	}
}

void init_array(uint32_t array[size_of_array_h][size_of_array_w], uint8_t TIME){
	for(unsigned char y = 0; y < size_of_array_h; y++){
		for(unsigned char x = 0; x < size_of_array_w; x++){
			array[y][x] = func(x, y, TIME);
		}
	}	
}

void clear_array(uint32_t array[size_of_array_h][size_of_array_w]){
	for(unsigned char y = 0; y < size_of_array_h; y++){
		for(unsigned char x = 0; x < size_of_array_w; x++){
			array[y][x] = 0;
		}
	}
}

void timer_init(void){
	clr_bits(TCCR0A,0b11,WGM00);	//Normal
	set_bits(TCCR0B, 0b101, CS00);	//1024
	set_bit(TIMSK0, TOIE0);			//interrupt
	
}

uint32_t func(uint8_t x, uint8_t y, uint8_t TIME){
	uint32_t f;
	if((x + TIME) > 15){
		f = rgb(((double)(x + TIME - 16))/(size_of_array_w));
	}
	else{
		f = rgb(((double)(x + TIME))/(size_of_array_w));
	}
	return f;
}

uint32_t rgb(double ratio)//ratio between 0.0 to 1.0
{
	//we want to normalize ratio so that it fits in to 6 regions
	//where each region is 256 units long
	uint32_t normalized = (uint32_t)(ratio * 256 * 6);

	//find the region for this position
	uint32_t region = normalized / 256;

	//find the distance to the start of the closest region
	uint8_t x = normalized % 256;

	uint8_t r = 0, g = 0, b = 0;
	switch (region)
	{
		case 0: r = 0xFF; g = 0;	b = 0;    g += x; break;
		case 1: r = 0xFF; g = 0xFF;	b = 0;    r -= x; break;
		case 2: r = 0;	  g = 0xFF;	b = 0;    b += x; break;
		case 3: r = 0;    g = 0xFF;	b = 0xFF; g -= x; break;
		case 4: r = 0;    g = 0;	b = 0xFF; r += x; break;
		case 5: r = 0xFF; g = 0;	b = 0xFF; b -= x; break;
	}
	uint32_t color = ((uint32_t)r << 16) + ((uint32_t)g << 8) + ((uint32_t)b << 0);
	return color;
}

// f = F_CPU/(256*1024*extra_prescaler_value)
ISR (TIMER0_OVF_vect)
{
	if(extra_prescaler == extra_prescaler_value){
		code = 1;
		extra_prescaler = 0;
		return;
	}
	else{
		extra_prescaler++;
		return;
	}
}