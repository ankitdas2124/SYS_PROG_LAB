.MODEL SMALL
.STACK 100H

.DATA
    NUM1        DW ?
    NUM2        DW ?
    CHOICE      DB ?
    
    MENU        DB 0DH, 0AH, '=== BASIC CALCULATOR ===', 0DH, 0AH
                DB '1. Addition (+)', 0DH, 0AH
                DB '2. Subtraction (-)', 0DH, 0AH
                DB '3. Multiplication (*)', 0DH, 0AH
                DB '4. Division (/)', 0DH, 0AH
                DB '5. Exit', 0DH, 0AH
                DB 'Enter choice (1-5): ', '$'

    MSG_N1      DB 0DH, 0AH, 'Enter first number: ', '$'
    MSG_N2      DB 'Enter second number: ', '$'
    MSG_RES     DB 'Result: ', '$'
    MSG_QUOT    DB 'Quotient: ', '$'
    MSG_REM     DB ', Remainder: ', '$'
    MSG_ERR_DIV DB 'Error: Division by zero!', 0DH, 0AH, '$'
    MSG_INV     DB 'Invalid choice!', 0DH, 0AH, '$'
    CRLF        DB 0DH, 0AH, '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

CALC_LOOP:
    ; Display menu
    LEA DX, MENU
    MOV AH, 09H
    INT 21H

    ; Read choice
    MOV AH, 01H
    INT 21H
    MOV CHOICE, AL

    CMP CHOICE, '5'
    JE EXIT_PROG
    CMP CHOICE, '1'
    JB INVALID_CHOICE
    CMP CHOICE, '4'
    JA INVALID_CHOICE

    ; Read First Number
    LEA DX, MSG_N1
    MOV AH, 09H
    INT 21H
    CALL READ_NUM
    MOV NUM1, AX

    ; Read Second Number
    LEA DX, MSG_N2
    MOV AH, 09H
    INT 21H
    CALL READ_NUM
    MOV NUM2, AX

    ; Perform operation
    CMP CHOICE, '1'
    JE DO_ADD
    CMP CHOICE, '2'
    JE DO_SUB
    CMP CHOICE, '3'
    JE DO_MUL
    CMP CHOICE, '4'
    JE DO_DIV

DO_ADD:
    LEA DX, MSG_RES
    MOV AH, 09H
    INT 21H
    MOV AX, NUM1
    ADD AX, NUM2
    CALL PRINT_NUM
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

DO_SUB:
    LEA DX, MSG_RES
    MOV AH, 09H
    INT 21H
    MOV AX, NUM1
    MOV BX, NUM2
    CMP AX, BX
    JAE SUB_POS
    ; Negative result
    MOV DL, '-'
    MOV AH, 02H
    INT 21H
    MOV AX, NUM2
    SUB AX, NUM1
    CALL PRINT_NUM
    JMP SUB_DONE
SUB_POS:
    SUB AX, BX
    CALL PRINT_NUM
SUB_DONE:
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

DO_MUL:
    LEA DX, MSG_RES
    MOV AH, 09H
    INT 21H
    MOV AX, NUM1
    MOV BX, NUM2
    MUL BX              ; AX = NUM1 * NUM2
    CALL PRINT_NUM
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

DO_DIV:
    MOV BX, NUM2
    CMP BX, 0
    JE DIV_ZERO
    LEA DX, MSG_QUOT
    MOV AH, 09H
    INT 21H
    MOV AX, NUM1
    XOR DX, DX
    DIV BX              ; AX = Quotient, DX = Remainder
    PUSH DX
    CALL PRINT_NUM
    LEA DX, MSG_REM
    MOV AH, 09H
    INT 21H
    POP AX
    CALL PRINT_NUM
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

DIV_ZERO:
    LEA DX, MSG_ERR_DIV
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

INVALID_CHOICE:
    LEA DX, MSG_INV
    MOV AH, 09H
    INT 21H
    JMP CALC_LOOP

EXIT_PROG:
    MOV AH, 4CH
    INT 21H
MAIN ENDP

; Reads an unsigned integer from standard input into AX
READ_NUM PROC
    PUSH BX
    PUSH CX
    PUSH DX
    XOR BX, BX
READ_DIGITS:
    MOV AH, 01H
    INT 21H
    CMP AL, 0DH         ; Enter
    JE READ_END
    CMP AL, ' '         ; Space
    JE READ_END
    CMP AL, '0'
    JB READ_DIGITS
    CMP AL, '9'
    JA READ_DIGITS
    SUB AL, '0'
    MOV AH, 0
    PUSH AX
    MOV AX, BX
    MOV CX, 10
    MUL CX
    POP DX
    ADD AX, DX
    MOV BX, AX
    JMP READ_DIGITS
READ_END:
    MOV AX, BX
    POP DX
    POP CX
    POP BX
    RET
READ_NUM ENDP

; Prints an unsigned integer in AX to standard output
PRINT_NUM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    XOR CX, CX
    MOV BX, 10
    CMP AX, 0
    JNE DIV_LOOP
    MOV DL, '0'
    MOV AH, 02H
    INT 21H
    JMP PRINT_EXIT
DIV_LOOP:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    CMP AX, 0
    JNE DIV_LOOP
PRINT_LOOP:
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    LOOP PRINT_LOOP
PRINT_EXIT:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

END MAIN
