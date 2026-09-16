.MODEL SMALL
.STACK 100H

.DATA
    BANNER          DB '=====================================================', 0DH, 0AH
                    DB '        ARRAY SORTING PROGRAM (MASM 8086)             ', 0DH, 0AH
                    DB '=====================================================', 0DH, 0AH, '$'

    MSG_PROMPT_N    DB 0DH, 0AH, 'Enter number of elements (N): ', '$'
    MSG_PROMPT_ARR  DB 'Enter elements (separated by Space or Enter):', 0DH, 0AH, '$'

    MSG_ORIG        DB 0DH, 0AH, 'Original Array: ', '$'
    MSG_SORTED      DB 0DH, 0AH, 'Sorted Array (Ascending): ', '$'
    SPACE           DB ' ', '$'
    CRLF            DB 0DH, 0AH, '$'

    N               DW ?
    ARR             DW 100 DUP(?)   ; Supports up to 100 16-bit multi-digit integers

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Banner
    LEA DX, BANNER
    MOV AH, 09H
    INT 21H

    ; 1. Read N from user
    LEA DX, MSG_PROMPT_N
    MOV AH, 09H
    INT 21H
    CALL READ_NUM
    MOV N, AX

    ; Check if N == 0
    CMP N, 0
    JLE PROGRAM_EXIT

    ; 2. Read N elements from user
    LEA DX, MSG_PROMPT_ARR
    MOV AH, 09H
    INT 21H

    MOV CX, N
    XOR SI, SI
INPUT_LOOP:
    CALL READ_NUM
    MOV ARR[SI], AX
    ADD SI, 2
    LOOP INPUT_LOOP

    ; 3. Display Original Array
    LEA DX, MSG_ORIG
    MOV AH, 09H
    INT 21H

    MOV CX, N
    XOR SI, SI
DISPLAY_ORIG:
    MOV AX, ARR[SI]
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    ADD SI, 2
    LOOP DISPLAY_ORIG

    ; 4. Sort Array using Bubble Sort (Ascending Order)
    MOV CX, N
    DEC CX
    JZ DISPLAY_SORTED_RESULT    ; If N == 1, array is already sorted

OUTER_SORT:
    PUSH CX                     ; Save outer loop counter
    XOR SI, SI                  ; Start at first element (index 0)

INNER_SORT:
    MOV AX, ARR[SI]             ; Current element
    MOV BX, ARR[SI + 2]         ; Next element

    CMP AX, BX
    JBE NO_SWAP                 ; If ARR[i] <= ARR[i+1], no swap

    ; Swap ARR[i] and ARR[i+1]
    MOV ARR[SI], BX
    MOV ARR[SI + 2], AX

NO_SWAP:
    ADD SI, 2                   ; Move to next word
    LOOP INNER_SORT

    POP CX                      ; Restore outer loop counter
    LOOP OUTER_SORT

DISPLAY_SORTED_RESULT:
    ; 5. Display Sorted Array
    LEA DX, MSG_SORTED
    MOV AH, 09H
    INT 21H

    MOV CX, N
    XOR SI, SI
DISPLAY_SORTED:
    MOV AX, ARR[SI]
    CALL PRINT_NUM
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    ADD SI, 2
    LOOP DISPLAY_SORTED

    LEA DX, CRLF
    MOV AH, 09H
    INT 21H

PROGRAM_EXIT:
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;-----------------------------------------------------------
; READ_NUM:
; Reads an unsigned decimal integer from standard input.
; Supports multi-digit input and skips leading delimiters.
; Returns value in AX.
;-----------------------------------------------------------
READ_NUM PROC
    PUSH BX
    PUSH CX
    PUSH DX

SKIP_LEADING:
    MOV AH, 01H
    INT 21H
    CMP AL, ' '
    JE SKIP_LEADING
    CMP AL, 0DH             ; Carriage return
    JE SKIP_LEADING
    CMP AL, 0AH             ; Line feed
    JE SKIP_LEADING
    CMP AL, 09H             ; Tab
    JE SKIP_LEADING

    ; First digit
    XOR BX, BX
    CMP AL, '0'
    JB READ_NOT_DIGIT
    CMP AL, '9'
    JA READ_NOT_DIGIT

    SUB AL, '0'
    MOV BL, AL
    MOV BH, 0

DIGIT_LOOP:
    MOV AH, 01H
    INT 21H

    CMP AL, '0'
    JB DIGIT_FINISH
    CMP AL, '9'
    JA DIGIT_FINISH

    SUB AL, '0'
    MOV AH, 0
    PUSH AX                 ; Push new digit

    MOV AX, BX
    MOV CX, 10
    MUL CX                  ; AX = BX * 10
    POP DX                  ; DX = new digit
    ADD AX, DX              ; AX = (BX * 10) + DX
    MOV BX, AX
    JMP DIGIT_LOOP

DIGIT_FINISH:
    MOV AX, BX
    JMP READ_DONE

READ_NOT_DIGIT:
    MOV AX, 0

READ_DONE:
    POP DX
    POP CX
    POP BX
    RET
READ_NUM ENDP

;-----------------------------------------------------------
; PRINT_NUM:
; Prints an unsigned 16-bit integer in AX in decimal.
; Supports multi-digit values up to 65535.
;-----------------------------------------------------------
PRINT_NUM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    XOR CX, CX
    MOV BX, 10

    CMP AX, 0
    JNE PN_DIV_LOOP

    ; If 0, print single '0'
    MOV DL, '0'
    MOV AH, 02H
    INT 21H
    JMP PN_EXIT

PN_DIV_LOOP:
    XOR DX, DX
    DIV BX                  ; AX / 10, Remainder in DX
    PUSH DX                 ; Push digit onto stack
    INC CX
    CMP AX, 0
    JNE PN_DIV_LOOP

PN_PRINT_LOOP:
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    LOOP PN_PRINT_LOOP

PN_EXIT:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

END MAIN
