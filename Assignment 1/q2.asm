.MODEL SMALL
.STACK 100H

.DATA
    ARR         DB 20 DUP(?)
    MSG_IN      DB 'Enter 20 numbers (separated by Space or Enter):', 0DH, 0AH, '$'
    MSG_ORIG    DB 0DH, 0AH, 'Original Array: ', '$'
    MSG_ZIGZAG  DB 0DH, 0AH, 'Zig-Zag Array at 4000H: ', '$'
    SPACE       DB ' ', '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Prompt user
    LEA DX, MSG_IN
    MOV AH, 09H
    INT 21H

    ; Read 20 numbers
    MOV CX, 20
    XOR SI, SI
READ_LOOP:
    CALL READ_NUM
    MOV ARR[SI], AL
    INC SI
    LOOP READ_LOOP

    ; Display original array
    LEA DX, MSG_ORIG
    MOV AH, 09H
    INT 21H
    MOV CX, 20
    XOR SI, SI
SHOW_ORIG:
    MOV AL, ARR[SI]
    MOV AH, 0
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    INC SI
    LOOP SHOW_ORIG

    ; Rearrange array in zig-zag order (a[0] <= a[1] >= a[2] <= a[3] ...)
    XOR SI, SI
ZIGZAG_LOOP:
    CMP SI, 19
    JGE COPY_TO_4000

    MOV AL, ARR[SI]
    MOV BL, ARR[SI+1]

    TEST SI, 1          ; Check even/odd index
    JNZ ODD_INDEX

EVEN_INDEX:
    CMP AL, BL          ; Even index: expect ARR[SI] <= ARR[SI+1]
    JBE NEXT_ELEM
    MOV ARR[SI], BL
    MOV ARR[SI+1], AL
    JMP NEXT_ELEM

ODD_INDEX:
    CMP AL, BL          ; Odd index: expect ARR[SI] >= ARR[SI+1]
    JAE NEXT_ELEM
    MOV ARR[SI], BL
    MOV ARR[SI+1], AL

NEXT_ELEM:
    INC SI
    JMP ZIGZAG_LOOP

    ; Store zig-zag array in memory location 4000H
COPY_TO_4000:
    XOR SI, SI
    MOV DI, 4000H
    MOV CX, 20
COPY_LOOP:
    MOV AL, ARR[SI]
    MOV [DI], AL
    INC SI
    INC DI
    LOOP COPY_LOOP

    ; Display zig-zag array from 4000H
    LEA DX, MSG_ZIGZAG
    MOV AH, 09H
    INT 21H
    MOV DI, 4000H
    MOV CX, 20
SHOW_ZIGZAG:
    MOV AL, [DI]
    MOV AH, 0
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    INC DI
    LOOP SHOW_ZIGZAG

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
