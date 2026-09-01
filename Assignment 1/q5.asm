.MODEL SMALL
.STACK 100H

.DATA
    STR1        DB 100 DUP(?)
    STR2        DB 100 DUP(?)
    CHOICE      DB ?

    MENU        DB 0DH, 0AH, '=== STRING OPERATIONS LIBRARY ===', 0DH, 0AH
                DB '1. STRLEN (Length of string)', 0DH, 0AH
                DB '2. STRCMP (Compare two strings)', 0DH, 0AH
                DB '3. STRREV (Reverse string in-place)', 0DH, 0AH
                DB '4. Exit', 0DH, 0AH
                DB 'Enter choice (1-4): ', '$'

    MSG_S1      DB 0DH, 0AH, 'Enter string: ', '$'
    MSG_S1_CMP  DB 0DH, 0AH, 'Enter first string: ', '$'
    MSG_S2_CMP  DB 'Enter second string: ', '$'
    MSG_LEN     DB 'String Length: ', '$'
    MSG_EQ      DB 'Result: Strings are EQUAL', 0DH, 0AH, '$'
    MSG_LT      DB 'Result: First string is LESS than second string (STR1 < STR2)', 0DH, 0AH, '$'
    MSG_GT      DB 'Result: First string is GREATER than second string (STR1 > STR2)', 0DH, 0AH, '$'
    MSG_REV     DB 'Reversed String (in-place): ', '$'
    MSG_INV     DB 'Invalid choice!', 0DH, 0AH, '$'
    CRLF        DB 0DH, 0AH, '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

OP_LOOP:
    ; Display menu
    LEA DX, MENU
    MOV AH, 09H
    INT 21H

    ; Read menu choice
    MOV AH, 01H
    INT 21H
    MOV CHOICE, AL

    CMP CHOICE, '4'
    JE EXIT_PROG
    CMP CHOICE, '1'
    JE DO_STRLEN
    CMP CHOICE, '2'
    JE DO_STRCMP
    CMP CHOICE, '3'
    JE DO_STRREV

    ; Invalid choice
    LEA DX, MSG_INV
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

DO_STRLEN:
    LEA DX, MSG_S1
    MOV AH, 09H
    INT 21H
    LEA DI, STR1
    CALL READ_STR

    LEA SI, STR1
    CALL STRLEN

    LEA DX, MSG_LEN
    MOV AH, 09H
    INT 21H
    CALL PRINT_NUM
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

DO_STRCMP:
    LEA DX, MSG_S1_CMP
    MOV AH, 09H
    INT 21H
    LEA DI, STR1
    CALL READ_STR

    LEA DX, MSG_S2_CMP
    MOV AH, 09H
    INT 21H
    LEA DI, STR2
    CALL READ_STR

    LEA SI, STR1
    LEA DI, STR2
    CALL STRCMP

    CMP AX, 0
    JE CMP_EQUAL
    CMP AX, 1
    JE CMP_GREATER

    LEA DX, MSG_LT
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

CMP_GREATER:
    LEA DX, MSG_GT
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

CMP_EQUAL:
    LEA DX, MSG_EQ
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

DO_STRREV:
    LEA DX, MSG_S1
    MOV AH, 09H
    INT 21H
    LEA DI, STR1
    CALL READ_STR

    LEA SI, STR1
    CALL STRREV

    LEA DX, MSG_REV
    MOV AH, 09H
    INT 21H
    LEA DX, STR1
    MOV AH, 09H
    INT 21H
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP OP_LOOP

EXIT_PROG:
    MOV AH, 4CH
    INT 21H
MAIN ENDP

; -------------------------------------------------------------
; STRLEN: Calculates length of $-terminated string at SI.
; Returns length in AX.
; -------------------------------------------------------------
STRLEN PROC
    PUSH SI
    XOR AX, AX
STRLEN_COUNT:
    CMP BYTE PTR [SI], '$'
    JE STRLEN_DONE
    CMP BYTE PTR [SI], 0
    JE STRLEN_DONE
    INC AX
    INC SI
    JMP STRLEN_COUNT
STRLEN_DONE:
    POP SI
    RET
STRLEN ENDP

; -------------------------------------------------------------
; STRCMP: Compares two $-terminated strings at SI and DI.
; Returns AX = 0 (Equal), AX = 1 (SI > DI), AX = -1 (SI < DI).
; -------------------------------------------------------------
STRCMP PROC
    PUSH SI
    PUSH DI
    PUSH BX
STRCMP_CHECK:
    MOV AL, [SI]
    MOV BL, [DI]

    CMP AL, '$'
    JE CHECK_DI_END
    CMP BL, '$'
    JE STR1_IS_GREATER

    CMP AL, BL
    JB STR1_IS_LESS
    JA STR1_IS_GREATER

    INC SI
    INC DI
    JMP STRCMP_CHECK

CHECK_DI_END:
    CMP BL, '$'
    JE STRINGS_EQUAL
    JMP STR1_IS_LESS

STR1_IS_LESS:
    MOV AX, -1
    JMP STRCMP_EXIT

STR1_IS_GREATER:
    MOV AX, 1
    JMP STRCMP_EXIT

STRINGS_EQUAL:
    XOR AX, AX

STRCMP_EXIT:
    POP BX
    POP DI
    POP SI
    RET
STRCMP ENDP

; -------------------------------------------------------------
; STRREV: Reverses $-terminated string at SI in place.
; -------------------------------------------------------------
STRREV PROC
    PUSH SI
    PUSH DI
    PUSH AX
    PUSH BX

    MOV DI, SI
FIND_END:
    CMP BYTE PTR [DI], '$'
    JE REACHED_END
    CMP BYTE PTR [DI], 0
    JE REACHED_END
    INC DI
    JMP FIND_END

REACHED_END:
    DEC DI              ; DI points to last character

REV_SWAP:
    CMP SI, DI
    JAE REV_DONE
    MOV AL, [SI]
    MOV BL, [DI]
    MOV [SI], BL
    MOV [DI], AL
    INC SI
    DEC DI
    JMP REV_SWAP

REV_DONE:
    POP BX
    POP AX
    POP DI
    POP SI
    RET
STRREV ENDP

; Reads string from keyboard into buffer at DI, terminates with '$'
READ_STR PROC
    PUSH AX
    PUSH DI
READ_CHAR_LOOP:
    MOV AH, 01H
    INT 21H
    CMP AL, 0DH         ; Enter key
    JE READ_STR_DONE
    MOV [DI], AL
    INC DI
    JMP READ_CHAR_LOOP
READ_STR_DONE:
    MOV BYTE PTR [DI], '$'
    POP DI
    POP AX
    RET
READ_STR ENDP

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
