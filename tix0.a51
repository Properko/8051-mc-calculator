#include <REG51F380.h>
; include table
$include(DISPLAY_LOOKUP.INC)

; define global variables
BLOCK_SIZE EQU 8

PB1 EQU P0.6
PB2 EQU P0.7

NUMBER_1 EQU R1
NUMBER_2 EQU R2
OPERATOR EQU R3
	
NOT_INITIALIZED EQU 0FFH

; we have a way of representing 16 numbers on the display (0-F)
NUMBER_COUNT EQU 16

; CALL INIT
CSEG	AT	0H
	LJMP	INIT
CSEG	AT	50H

INIT:
	MOV PCA0MD, #0
	; needed for using buttons and screen
	MOV XBR1, #40H
	SETB PB1
	SETB PB2
	
	LJMP MAIN
MAIN:
	; set registers to init values
	MOV R0, #0
	CALL RESET_REGISTERS
	
LOOP:
	CALL SELECT_NUMBER
	CALL SELECT_OPERATOR
	
	; -- if operator is binary jump to SET_NUMBER_2, else jump to PRINT
	CJNE OPERATOR, #2, CHECK_ROTL
	SJMP PRINT
	CHECK_ROTL:
		CJNE OPERATOR, #6, CHECK_ROTR
		SJMP PRINT
	CHECK_ROTR:
		CJNE OPERATOR, #7, SET_NUMBER_2
		SJMP PRINT
		
	; --- select number 2
	SET_NUMBER_2:
		CALL SELECT_NUMBER
	PRINT:
		CALL PRINT_RESULT
		
	CALL RESET_REGISTERS
	
	; block until button pressed
	JB PB2, $
	JNB PB2, $

SJMP LOOP

RESET_REGISTERS:
	MOV NUMBER_1, #NOT_INITIALIZED
	MOV NUMBER_2, #NOT_INITIALIZED
	MOV OPERATOR, #NOT_INITIALIZED
RET

PRINT_RESULT:
	CALL CALCULATE_RESULT_R0
	
	;  C = 1 if A € [0 - F]
    CLR  C
    MOV  R1, A
    MOV  A, #0FH
    SUBB A, R1
    
	; --- if carry bit not set, display result without overflow
	JNC DISPLAY_RESULT_NO_OVERFLOW

	; --- else display with overflow
	MOV R4, #NUMBER_COUNT
	CALL MOD_R0_R4
	CALL DISPLAY
	CALL DISPLAY_OVERFLOW
	RET

	DISPLAY_RESULT_NO_OVERFLOW:
		CALL DISPLAY
RET


CALCULATE_RESULT_R0:
	MOV A, R1
	MOV B, R2

	DO_AND:	
		CJNE OPERATOR, #0, DO_OR
		ANL A, B
		SJMP SAVE_RESULT_AND_RETURN
	DO_OR:
		CJNE OPERATOR, #1, DO_NOT
		ORL A, B
		SJMP SAVE_RESULT_AND_RETURN
	DO_NOT:
		CJNE OPERATOR, #2, DO_XOR
		; NOT limited to (0 - F) is done via XOR 1111 (instead of CPL which would set the overflow flag)
		XRL A, #0FH
		SJMP SAVE_RESULT_AND_RETURN
	DO_XOR:
		CJNE OPERATOR, #3, DO_ADD
		XRL A, B
		SJMP SAVE_RESULT_AND_RETURN
	DO_ADD:
		CJNE OPERATOR, #4, DO_SUB
		ADD A, B
		SJMP SAVE_RESULT_AND_RETURN
	DO_SUB:
 		CJNE OPERATOR, #5, DO_ROTL
		SUBB A, B
		JNC A_IS_GREATER_THAN_B
		; if it's not, switch operands and repeat SUBB
		CLR C
		MOV A, R2
		MOV B, R1
		SUBB A, B
		ADD A, #NUMBER_COUNT ; make sure overflow will be set later

		A_IS_GREATER_THAN_B:
		SJMP SAVE_RESULT_AND_RETURN
	DO_ROTL:
		CJNE OPERATOR, #6, DO_ROTR
		RL A
		; if a bit was not rotated outside of the 4-bit space we use (to represent 16 numbers) exit
		JNB ACC.4, SAVE_RESULT_AND_RETURN
		; else move MSB TO LSB
		CLR ACC.4
		SETB ACC.0
		SJMP SAVE_RESULT_AND_RETURN
	DO_ROTR:
		RR A
		JNB ACC.7, SAVE_RESULT_AND_RETURN
		CLR ACC.7
		SETB ACC.3
	SAVE_RESULT_AND_RETURN:
		MOV R0, A
RET
	
SELECT_OPERATOR:
	; --- add 10
	MOV A, R0
	ADD A, #NUMBER_COUNT
	MOV R0, A
	
	CALL DISPLAY
	
	; --- minus 10
	MOV A, R0
	SUBB A, #NUMBER_COUNT
	MOV R0, A
	
	; if PB1 is pushed => change operator for selecting
	JNB PB1, CHANGE_OPERATOR
	
	; if PB2 is pushed => set operator
	JNB PB2, SET_OPERATOR
	
	SJMP SELECT_OPERATOR
	CHANGE_OPERATOR:
		JNB PB1, $
		INC R0
		
		; --- mod 8
		MOV R4, #8
		CALL MOD_R0_R4
		
		SJMP SELECT_OPERATOR
	SET_OPERATOR:
		JNB PB2, $
		
		; --- set register to value of selected operator
		MOV A, R0
		MOV OPERATOR, A
		MOV R0, #0
RET

SELECT_NUMBER:
	CALL DISPLAY
	; if PB1 is pushed => change number for selecting
	JNB PB1, CHANGE_NUMBER
	
	; if PB2 is pushed => set number
	JNB PB2, SET_NUMBER
	
	SJMP SELECT_NUMBER
	CHANGE_NUMBER:
		JNB PB1, $
		INC R0
		
		; --- mod 10
		MOV R4, #NUMBER_COUNT
		CALL MOD_R0_R4
		
		SJMP SELECT_NUMBER
	SET_NUMBER:
		JNB PB2, $
		
		; if number_1 is alrady set, set number 2
		CJNE NUMBER_1, #NOT_INITIALIZED, SET_NUMBER2
		
		; --- else set number 1
		MOV A, R0
		MOV NUMBER_1, A
		MOV R0, #0
		RET

	SET_NUMBER2:
		MOV A, R0
		MOV NUMBER_2, A
		MOV R0, #0
RET

MOD_R0_R4:
	; --- modulus used by register R4
	MOV A, R0
	MOV B, R4
	DIV AB
	MOV R0, B
RET

DISPLAY:
	; --- display number/operator based on value in #TABLE
	MOV DPTR, #TABLE
	MOV A, R0
	MOVC A, @A+DPTR
	MOV P2, A
RET

DISPLAY_OVERFLOW:
	; light up the (overflow) dot
	CLR P2.7
RET

END
