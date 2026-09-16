.MODEL SMALL
.STACK 100H

.DATA
    BANNER          DB '=====================================================', 0DH, 0AH
                    DB '   FCFS (FIRST-COME-FIRST-SERVED) DISK SCHEDULING     ', 0DH, 0AH
                    DB '=====================================================', 0DH, 0AH, '$'

    MSG_PROMPT_HEAD DB 0DH, 0AH, 'Enter Initial Head Position (e.g. 50): ', '$'
    MSG_PROMPT_N    DB 'Enter Number of Cylinder Requests (N): ', '$'
    MSG_PROMPT_REQ  DB 'Enter the requests (separated by Space or Enter):', 0DH, 0AH, '$'

    MSG_TRACE_HDR   DB 0DH, 0AH, '--- Disk Head Movement Trace ---', 0DH, 0AH, '$'
    MSG_STEP        DB 'Step ', '$'
    MSG_FROM        DB ': Move from ', '$'
    MSG_TO          DB ' to ', '$'
    MSG_SEEK        DB ' -> Seek movement = ', '$'
    MSG_CYL         DB ' cylinders', 0DH, 0AH, '$'

    MSG_TOTAL       DB 0DH, 0AH, 'Total Head Movement : ', '$'
    MSG_AVG         DB 'Average Seek Length : ', '$'
    MSG_REM         DB ' (Remainder: ', '$'
    MSG_SLASH       DB '/', '$'
    MSG_CLOSE       DB ')', 0DH, 0AH, '$'
    CRLF            DB 0DH, 0AH, '$'

    ; Variables
    HEAD_POS        DW ?
    CURR_HEAD       DW ?
    NUM_REQ         DW ?
    TOTAL_HM        DW 0
    STEP_NUM        DW 1

    ; Max 50 requests
    REQ_ARR         DW 50 DUP(?)

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Banner
    LEA DX, BANNER
    MOV AH, 09H
    INT 21H

    ; 1. Read Initial Head Position
    LEA DX, MSG_PROMPT_HEAD
    MOV AH, 09H
    INT 21H
    CALL READ_NUM
    MOV HEAD_POS, AX
    MOV CURR_HEAD, AX

    ; 2. Read Number of Requests (N)
    LEA DX, MSG_PROMPT_N
    MOV AH, 09H
    INT 21H
    CALL READ_NUM
    MOV NUM_REQ, AX

    ; If N == 0, exit gracefully
    CMP NUM_REQ, 0
    JLE PROGRAM_EXIT

    ; 3. Read Request Sequence
    LEA DX, MSG_PROMPT_REQ
    MOV AH, 09H
    INT 21H

    MOV CX, NUM_REQ
    XOR SI, SI
INPUT_LOOP:
    CALL READ_NUM
    MOV REQ_ARR[SI], AX
    ADD SI, 2
    LOOP INPUT_LOOP

    ; 4. Simulate FCFS Disk Scheduling
    LEA DX, MSG_TRACE_HDR
    MOV AH, 09H
    INT 21H

    MOV WORD PTR [TOTAL_HM], 0
    MOV WORD PTR [STEP_NUM], 1
    MOV CX, NUM_REQ
    XOR SI, SI

FCFS_LOOP:
    PUSH CX                 ; Preserve loop counter

    ; Print "Step X"
    LEA DX, MSG_STEP
    MOV AH, 09H
    INT 21H
    MOV AX, STEP_NUM
    CALL PRINT_NUM

    ; Print ": Move from [CURR_HEAD]"
    LEA DX, MSG_FROM
    MOV AH, 09H
    INT 21H
    MOV AX, CURR_HEAD
    CALL PRINT_NUM

    ; Print " to [Target]"
    LEA DX, MSG_TO
    MOV AH, 09H
    INT 21H
    MOV AX, REQ_ARR[SI]
    CALL PRINT_NUM

    ; Calculate Absolute Difference: |Target - CURR_HEAD|
    MOV BX, REQ_ARR[SI]
    CMP BX, CURR_HEAD
    JAE CALC_DIFF_POS
    ; If Target < CURR_HEAD
    MOV AX, CURR_HEAD
    SUB AX, BX
    JMP DIFF_DONE

CALC_DIFF_POS:
    MOV AX, BX
    SUB AX, CURR_HEAD

DIFF_DONE:
    ; AX now contains seek distance for this step
    PUSH AX                 ; Save seek distance

    ; Print " -> Seek movement = [AX] cylinders"
    LEA DX, MSG_SEEK
    MOV AH, 09H
    INT 21H
    POP AX
    PUSH AX
    CALL PRINT_NUM
    LEA DX, MSG_CYL
    MOV AH, 09H
    INT 21H

    ; Accumulate into TOTAL_HM
    POP AX
    ADD TOTAL_HM, AX

    ; Update CURR_HEAD to Target
    MOV AX, REQ_ARR[SI]
    MOV CURR_HEAD, AX

    ; Advance step number and array pointer
    INC STEP_NUM
    ADD SI, 2

    POP CX
    DEC CX
    JNZ FCFS_LOOP

    ; 5. Display Total Head Movement
    LEA DX, MSG_TOTAL
    MOV AH, 09H
    INT 21H
    MOV AX, TOTAL_HM
    CALL PRINT_NUM
    LEA DX, MSG_CYL
    MOV AH, 09H
    INT 21H

    ; 6. Display Average Seek Length = TOTAL_HM / NUM_REQ
    LEA DX, MSG_AVG
    MOV AH, 09H
    INT 21H

    XOR DX, DX
    MOV AX, TOTAL_HM
    DIV NUM_REQ             ; AX = Quotient, DX = Remainder
    PUSH DX                 ; Save remainder
    CALL PRINT_NUM          ; Print quotient

    ; Print remainder details: " (Remainder: DX/NUM_REQ)"
    LEA DX, MSG_REM
    MOV AH, 09H
    INT 21H

    POP DX                  ; Restore remainder
    MOV AX, DX
    CALL PRINT_NUM

    LEA DX, MSG_SLASH
    MOV AH, 09H
    INT 21H

    MOV AX, NUM_REQ
    CALL PRINT_NUM

    LEA DX, MSG_CLOSE
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
