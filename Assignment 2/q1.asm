.MODEL SMALL
.STACK 100H

.DATA
    ; Hardcoded password
    PASSWORD        DB 'ADMIN123'
    PASS_LEN        EQU $ - PASSWORD

    ; Buffer to store entered password
    INPUT_BUF       DB 32 DUP(?)
    INPUT_LEN       DW 0
    RETRIES_LEFT    DB 3

    ; BIOS-like interface messages
    MSG_BANNER      DB 0DH, 0AH, '=====================================================', 0DH, 0AH
                    DB '        PHOENIX BIOS 4.0 RELEASE 6.0 (POST)          ', 0DH, 0AH
                    DB '         SECURITY PASSWORD AUTHENTICATION            ', 0DH, 0AH
                    DB '=====================================================', 0DH, 0AH, '$'
    MSG_PROMPT      DB 0DH, 0AH, 'Enter System Password: ', '$'
    MSG_SUCCESS     DB 0DH, 0AH, 0DH, 0AH, '[OK] Password Verified. Booting Operating System...', 0DH, 0AH, '$'
    MSG_FAIL        DB 0DH, 0AH, '[ERROR] Incorrect Password! Retries remaining: ', '$'
    MSG_LOCKED      DB 0DH, 0AH, 0DH, 0AH, '*****************************************************', 0DH, 0AH
                    DB ' [FATAL] SYSTEM LOCKED! Maximum attempts exceeded.   ', 0DH, 0AH
                    DB ' System halted. Power off to reboot.                 ', 0DH, 0AH
                    DB '*****************************************************', 0DH, 0AH, '$'
    CRLF            DB 0DH, 0AH, '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

    ; Display BIOS Splash Banner
    LEA DX, MSG_BANNER
    MOV AH, 09H
    INT 21H

TRY_AGAIN:
    ; Check remaining retries
    CMP RETRIES_LEFT, 0
    JE SYSTEM_LOCK

    ; Prompt for password
    LEA DX, MSG_PROMPT
    MOV AH, 09H
    INT 21H

    ; Read password with hidden input (no echo) using BIOS INT 16H
    CALL READ_PASSWORD_HIDDEN

    ; Compare entered password with hardcoded PASSWORD
    CALL VERIFY_PASSWORD
    CMP AX, 1
    JE ACCESS_GRANTED

    ; Password mismatch: decrement retries and notify user
    DEC RETRIES_LEFT
    LEA DX, MSG_FAIL
    MOV AH, 09H
    INT 21H

    ; Print remaining retries count
    MOV DL, RETRIES_LEFT
    ADD DL, '0'
    MOV AH, 02H
    INT 21H

    LEA DX, CRLF
    MOV AH, 09H
    INT 21H

    JMP TRY_AGAIN

ACCESS_GRANTED:
    LEA DX, MSG_SUCCESS
    MOV AH, 09H
    INT 21H
    JMP EXIT_PROGRAM

SYSTEM_LOCK:
    LEA DX, MSG_LOCKED
    MOV AH, 09H
    INT 21H

    ; Lock/Halt system: simulate BIOS lock
    ; In simulation, terminate after displaying lock message
EXIT_PROGRAM:
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;-----------------------------------------------------------
; READ_PASSWORD_HIDDEN:
; Reads keystrokes using BIOS INT 16H (AH = 00H).
; Does NOT echo characters to screen.
; Supports Enter (0DH) to finish and Backspace (08H) to delete.
; Stores characters in INPUT_BUF and sets INPUT_LEN.
;-----------------------------------------------------------
READ_PASSWORD_HIDDEN PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV WORD PTR [INPUT_LEN], 0
    XOR SI, SI                      ; SI will index into INPUT_BUF

KEY_LOOP:
    ; BIOS Interrupt 16H, Function 00H: Read Key
    ; Returns: AL = ASCII code, AH = Scan code
    MOV AH, 00H
    INT 16H

    ; Check if Enter key was pressed
    CMP AL, 0DH
    JE READ_DONE

    ; Check if Backspace was pressed
    CMP AL, 08H
    JE HANDLE_BS

    ; Check if printable ASCII (32 to 126)
    CMP AL, 20H
    JB KEY_LOOP
    CMP AL, 7EH
    JA KEY_LOOP

    ; Check if buffer is full (max 30 characters)
    CMP SI, 30
    JAE KEY_LOOP

    ; Store character into buffer without displaying (no echo)
    MOV INPUT_BUF[SI], AL
    INC SI
    JMP KEY_LOOP

HANDLE_BS:
    ; If backspace and buffer not empty, remove last character
    CMP SI, 0
    JE KEY_LOOP
    DEC SI
    JMP KEY_LOOP

READ_DONE:
    MOV INPUT_LEN, SI               ; Save length of entered password
    POP SI
    POP DX
    POP CX
    POP BX
    RET
READ_PASSWORD_HIDDEN ENDP

;-----------------------------------------------------------
; VERIFY_PASSWORD:
; Compares INPUT_BUF against hardcoded PASSWORD.
; Returns: AX = 1 if match, AX = 0 if mismatch.
;-----------------------------------------------------------
VERIFY_PASSWORD PROC
    PUSH CX
    PUSH SI
    PUSH DI

    ; First check if length matches
    MOV CX, INPUT_LEN
    CMP CX, PASS_LEN
    JNE MISMATCH

    ; Compare string bytes
    LEA SI, INPUT_BUF
    LEA DI, PASSWORD
    CLD
    REPE CMPSB
    JNE MISMATCH

MATCH:
    MOV AX, 1
    JMP VERIFY_EXIT

MISMATCH:
    MOV AX, 0

VERIFY_EXIT:
    POP DI
    POP SI
    POP CX
    RET
VERIFY_PASSWORD ENDP

END MAIN
