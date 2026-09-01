.MODEL SMALL
.STACK 100H

.DATA
    HEX_BUF     DB 5 DUP('$')
    MSG_IN      DB 'Enter a hexadecimal number (1-4 hex digits, e.g. 41 or 3F): ', '$'
    MSG_CHAR    DB 0DH, 0AH, 'Equivalent ASCII Character: ', '$'
    MSG_DEC     DB 0DH, 0AH, 'Equivalent ASCII Decimal Value: ', '$'
    MSG_CODES   DB 0DH, 0AH, 'ASCII Codes of Hex Digits: ', '$'
    SPACE       DB ' ', '$'
    CRLF        DB 0DH, 0AH, '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Prompt user
    LEA DX, MSG_IN
    MOV AH, 09H
    INT 21H

    ; Read hexadecimal input into AX and HEX_BUF
    CALL READ_HEX

    ; Save parsed hex value
    PUSH AX

    ; Display ASCII Character representation
    LEA DX, MSG_CHAR
    MOV AH, 09H
    INT 21H
    POP AX
    PUSH AX
    MOV DL, AL
    MOV AH, 02H
    INT 21H

    ; Display ASCII Decimal equivalent value
    LEA DX, MSG_DEC
    MOV AH, 09H
    INT 21H
    POP AX
    PUSH AX
    CALL PRINT_NUM

    ; Display ASCII hex codes of individual digits
    LEA DX, MSG_CODES
    MOV AH, 09H
    INT 21H
    XOR SI, SI
PRINT_DIGIT_CODES:
    MOV AL, HEX_BUF[SI]
    CMP AL, '$'
    JE FINISH
    MOV AH, 0
    CALL PRINT_HEX_BYTE
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    INC SI
    JMP PRINT_DIGIT_CODES

FINISH:
    POP AX
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H

    ; Exit program
    MOV AH, 4CH
    INT 21H
MAIN ENDP

; Reads hexadecimal string from input, parses value into AX, stores chars in HEX_BUF
READ_HEX PROC
    PUSH BX
    PUSH CX
    PUSH DX
    XOR BX, BX
    XOR SI, SI
HEX_INPUT_LOOP:
    MOV AH, 01H
    INT 21H
    CMP AL, 0DH         ; Enter key
    JE HEX_INPUT_DONE
    CMP AL, ' '
    JE HEX_INPUT_DONE

    ; Store character in buffer
    MOV HEX_BUF[SI], AL
    INC SI

    ; Convert char to 4-bit nibble
    CMP AL, '0'
    JB HEX_INPUT_LOOP
    CMP AL, '9'
    JBE DIGIT_0_9
    CMP AL, 'A'
    JB CHECK_LOWER
    CMP AL, 'F'
    JBE DIGIT_A_F
CHECK_LOWER:
    CMP AL, 'a'
    JB HEX_INPUT_LOOP
    CMP AL, 'f'
    JA HEX_INPUT_LOOP
    SUB AL, 'a' - 10
    JMP ACCUMULATE
DIGIT_A_F:
    SUB AL, 'A' - 10
    JMP ACCUMULATE
DIGIT_0_9:
    SUB AL, '0'

ACCUMULATE:
    MOV CL, 4
    SHL BX, CL
    MOV AH, 0
    ADD BX, AX
    JMP HEX_INPUT_LOOP

HEX_INPUT_DONE:
    MOV HEX_BUF[SI], '$'
    MOV AX, BX
    POP DX
    POP CX
    POP BX
    RET
READ_HEX ENDP

; Prints an unsigned integer in AX as decimal
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

; Prints 1 byte in AL as 2 hex digits with 'H' suffix
PRINT_HEX_BYTE PROC
    PUSH AX
    PUSH BX
    PUSH DX
    MOV BL, AL
    ; High nibble
    MOV DL, BL
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    SHR DL, 1
    CALL NIBBLE_TO_ASCII
    MOV AH, 02H
    INT 21H
    ; Low nibble
    MOV DL, BL
    AND DL, 0FH
    CALL NIBBLE_TO_ASCII
    MOV AH, 02H
    INT 21H
    ; 'H' suffix
    MOV DL, 'H'
    MOV AH, 02H
    INT 21H
    POP DX
    POP BX
    POP AX
    RET
PRINT_HEX_BYTE ENDP

; Converts nibble in DL (0-15) to ASCII char in DL
NIBBLE_TO_ASCII PROC
    CMP DL, 9
    JBE NIBBLE_DEC
    ADD DL, 'A' - 10
    RET
NIBBLE_DEC:
    ADD DL, '0'
    RET
NIBBLE_TO_ASCII ENDP

END MAIN
