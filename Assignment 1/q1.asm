.MODEL SMALL
.STACK 100H

.DATA
    MSG_IN      DB 'Enter 10 numbers (separated by Space or Enter):', 0DH, 0AH, '$'
    MSG_ORIG    DB 0DH, 0AH, 'Original Block at 3000H: ', '$'
    MSG_TRANS   DB 0DH, 0AH, 'Transformed Block at 4000H: ', '$'
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

    ; Read 10 numbers into memory starting at 3000H
    MOV DI, 3000H
    MOV CX, 10
INPUT_LOOP:
    CALL READ_NUM
    MOV [DI], AL
    INC DI
    LOOP INPUT_LOOP

    ; Transfer from 3000H to 4000H with (X * 5 + 10)
    MOV SI, 3000H
    MOV DI, 4000H
    MOV CX, 10
TRANS_LOOP:
    MOV AL, [SI]
    MOV BL, 5
    MUL BL              ; AL = AL * 5
    ADD AL, 10          ; AL = AL + 10
    MOV [DI], AL
    INC SI
    INC DI
    LOOP TRANS_LOOP

    ; Display original block at 3000H
    LEA DX, MSG_ORIG
    MOV AH, 09H
    INT 21H
    MOV SI, 3000H
    MOV CX, 10
PRINT_ORIG:
    MOV AL, [SI]
    MOV AH, 0
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    INC SI
    LOOP PRINT_ORIG

    ; Display transformed block at 4000H
    LEA DX, MSG_TRANS
    MOV AH, 09H
    INT 21H
    MOV DI, 4000H
    MOV CX, 10
PRINT_TRANS:
    MOV AL, [DI]
    MOV AH, 0
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    INC DI
    LOOP PRINT_TRANS

    ; Exit program
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
