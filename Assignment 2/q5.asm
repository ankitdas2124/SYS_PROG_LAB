.MODEL SMALL
.STACK 200H

.DATA
    BANNER          DB '=====================================================', 0DH, 0AH
                    DB '   STACK-BASED BRACKET BALANCE EVALUATOR (MASM 8086) ', 0DH, 0AH
                    DB '   Checks (), {}, [] for balanced and proper nesting ', 0DH, 0AH
                    DB '=====================================================', 0DH, 0AH, '$'

    MSG_PROMPT      DB 0DH, 0AH, 'Enter expression with brackets (or ENTER on empty to quit):', 0DH, 0AH, '> ', '$'
    MSG_BALANCED    DB 0DH, 0AH, 'Result: Balanced', 0DH, 0AH, '$'
    MSG_NON_BAL     DB 0DH, 0AH, 'Result: Non-Balanced', 0DH, 0AH, '$'
    MSG_GOODBYE     DB 0DH, 0AH, 'Exiting program. Goodbye!', 0DH, 0AH, '$'
    CRLF            DB 0DH, 0AH, '$'

    ; Input expression buffer
    EXPR_BUF        DB 120 DUP(?)
    EXPR_LEN        DW 0

    ; Simulated Stack
    STACK_MAX       EQU 100
    SIM_STACK       DB STACK_MAX DUP(?)
    STACK_TOP       DW 0

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Banner
    LEA DX, BANNER
    MOV AH, 09H
    INT 21H

MAIN_LOOP:
    ; Prompt user
    LEA DX, MSG_PROMPT
    MOV AH, 09H
    INT 21H

    ; Read input string into EXPR_BUF
    CALL READ_EXPR

    ; Check if string is empty (user just pressed Enter)
    CMP EXPR_LEN, 0
    JE EXIT_PROG

    ; Evaluate brackets in expression using simulated stack
    CALL EVAL_BRACKETS
    CMP AX, 1
    JE SHOW_BALANCED

SHOW_NON_BALANCED:
    LEA DX, MSG_NON_BAL
    MOV AH, 09H
    INT 21H
    JMP MAIN_LOOP

SHOW_BALANCED:
    LEA DX, MSG_BALANCED
    MOV AH, 09H
    INT 21H
    JMP MAIN_LOOP

EXIT_PROG:
    LEA DX, MSG_GOODBYE
    MOV AH, 09H
    INT 21H

    MOV AH, 4CH
    INT 21H
MAIN ENDP

;-----------------------------------------------------------
; READ_EXPR:
; Reads characters until Enter (0DH) from standard input.
; Stores characters in EXPR_BUF and sets EXPR_LEN.
; Handles Backspace (08H).
;-----------------------------------------------------------
READ_EXPR PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    XOR SI, SI
RE_LOOP:
    MOV AH, 01H
    INT 21H

    CMP AL, 0DH             ; Enter
    JE RE_DONE

    CMP AL, 08H             ; Backspace
    JE RE_BS

    CMP SI, 110
    JAE RE_LOOP

    MOV EXPR_BUF[SI], AL
    INC SI
    JMP RE_LOOP

RE_BS:
    CMP SI, 0
    JE RE_LOOP
    DEC SI
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    MOV DL, 08H
    MOV AH, 02H
    INT 21H
    JMP RE_LOOP

RE_DONE:
    MOV EXPR_BUF[SI], 0     ; Null terminate
    MOV EXPR_LEN, SI

    POP SI
    POP DX
    POP BX
    POP AX
    RET
READ_EXPR ENDP

;-----------------------------------------------------------
; EVAL_BRACKETS:
; Evaluates bracket balance in EXPR_BUF.
; Simulates a stack in SIM_STACK with pointer STACK_TOP.
; Returns: AX = 1 if Balanced, AX = 0 if Non-Balanced.
;-----------------------------------------------------------
EVAL_BRACKETS PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Reset stack top to 0 (empty stack)
    MOV WORD PTR [STACK_TOP], 0

    MOV CX, EXPR_LEN
    XOR SI, SI

SCAN_LOOP:
    MOV AL, EXPR_BUF[SI]

    ; Check for opening brackets: '(', '{', '['
    CMP AL, '('
    JE PUSH_BRACKET
    CMP AL, '{'
    JE PUSH_BRACKET
    CMP AL, '['
    JE PUSH_BRACKET

    ; Check for closing bracket ')'
    CMP AL, ')'
    JE CHECK_PAREN

    ; Check for closing bracket '}'
    CMP AL, '}'
    JE CHECK_BRACE

    ; Check for closing bracket ']'
    CMP AL, ']'
    JE CHECK_BRACKET

    ; Other non-bracket characters are ignored
    JMP SCAN_NEXT

PUSH_BRACKET:
    ; Check if stack full
    MOV BX, STACK_TOP
    CMP BX, STACK_MAX
    JAE NOT_BALANCED_EXIT

    ; Push AL onto simulated stack
    MOV SIM_STACK[BX], AL
    INC WORD PTR [STACK_TOP]
    JMP SCAN_NEXT

CHECK_PAREN:
    ; Stack must not be empty
    CMP WORD PTR [STACK_TOP], 0
    JE NOT_BALANCED_EXIT

    ; Pop element
    DEC WORD PTR [STACK_TOP]
    MOV BX, STACK_TOP
    MOV AH, SIM_STACK[BX]

    ; Must match '('
    CMP AH, '('
    JNE NOT_BALANCED_EXIT
    JMP SCAN_NEXT

CHECK_BRACE:
    ; Stack must not be empty
    CMP WORD PTR [STACK_TOP], 0
    JE NOT_BALANCED_EXIT

    ; Pop element
    DEC WORD PTR [STACK_TOP]
    MOV BX, STACK_TOP
    MOV AH, SIM_STACK[BX]

    ; Must match '{'
    CMP AH, '{'
    JNE NOT_BALANCED_EXIT
    JMP SCAN_NEXT

CHECK_BRACKET:
    ; Stack must not be empty
    CMP WORD PTR [STACK_TOP], 0
    JE NOT_BALANCED_EXIT

    ; Pop element
    DEC WORD PTR [STACK_TOP]
    MOV BX, STACK_TOP
    MOV AH, SIM_STACK[BX]

    ; Must match '['
    CMP AH, '['
    JNE NOT_BALANCED_EXIT
    JMP SCAN_NEXT

SCAN_NEXT:
    INC SI
    LOOP SCAN_LOOP

    ; After reading whole string, stack MUST be empty (STACK_TOP == 0)
    CMP WORD PTR [STACK_TOP], 0
    JNE NOT_BALANCED_EXIT

BALANCED_EXIT:
    MOV AX, 1
    JMP EVAL_DONE

NOT_BALANCED_EXIT:
    MOV AX, 0

EVAL_DONE:
    POP SI
    POP DX
    POP CX
    POP BX
    RET
EVAL_BRACKETS ENDP

END MAIN
