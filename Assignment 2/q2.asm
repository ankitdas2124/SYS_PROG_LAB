.MODEL SMALL
.STACK 200H

.DATA
    ; Banner and Prompts
    BANNER          DB '=========================================================', 0DH, 0AH
                    DB '      MASM DOS COMMAND-LINE SHELL EMULATOR v2.0          ', 0DH, 0AH
                    DB ' Supported: DIR | TYPE <file> | COPY <src> <dest> | EXIT ', 0DH, 0AH
                    DB '=========================================================', 0DH, 0AH, '$'
    PROMPT          DB 'C:\> ', '$'
    CRLF            DB 0DH, 0AH, '$'
    SPACE_STR       DB ' ', '$'

    ; Shell Messages
    MSG_BAD_CMD     DB 'Bad command or file name.', 0DH, 0AH, '$'
    MSG_EXIT        DB 'Exiting Shell Emulator. Goodbye!', 0DH, 0AH, '$'
    MSG_NOT_FOUND   DB 'File not found.', 0DH, 0AH, '$'
    MSG_COPIED      DB '        1 file(s) copied.', 0DH, 0AH, '$'
    MSG_DISK_FULL   DB 'Error: Simulated disk directory is full.', 0DH, 0AH, '$'
    MSG_TYPE_SYNTAX DB 'Syntax: TYPE <filename>', 0DH, 0AH, '$'
    MSG_COPY_SYNTAX DB 'Syntax: COPY <source> <destination>', 0DH, 0AH, '$'

    ; DIR Header/Footer
    MSG_DIR_HDR     DB ' Volume in drive C has no label.', 0DH, 0AH
                    DB ' Directory of C:\', 0DH, 0AH, 0DH, 0AH, '$'
    MSG_FILES_STR   DB ' File(s)    ', '$'
    MSG_BYTES_STR   DB ' bytes', 0DH, 0AH, '$'

    ; Command parsing buffers
    LINE_BUF        DB 100 DUP(?)
    LINE_LEN        DW 0
    TOKEN1          DB 20 DUP(?)     ; Command name (DIR, TYPE, COPY, EXIT)
    TOKEN2          DB 20 DUP(?)     ; Arg 1 (filename / src)
    TOKEN3          DB 20 DUP(?)     ; Arg 2 (dest)
    COL_COUNT       DB 0

    ; Command literals for comparison
    CMD_DIR         DB 'DIR', 0
    CMD_TYPE        DB 'TYPE', 0
    CMD_COPY        DB 'COPY', 0
    CMD_EXIT        DB 'EXIT', 0

    ; Mock File System Structure
    ; Max 5 files. Each file entry:
    ;   Status (1 byte): 1 = active, 0 = free
    ;   Name (16 bytes): null-terminated
    ;   Size (2 bytes, word): size in bytes
    ;   Data (100 bytes): file contents (null-terminated)
    ; Total entry size = 1 + 16 + 2 + 100 = 119 bytes
    ENTRY_SIZE      EQU 119
    MAX_FILES       EQU 5

    FILE_ACTIVE     DB 1, 1, 1, 0, 0
    FILE_NAMES      DB 'README.TXT', 0, 0, 0, 0, 0, 0, 0
                    DB 'NOTES.DOC', 0, 0, 0, 0, 0, 0, 0, 0
                    DB 'CONFIG.SYS', 0, 0, 0, 0, 0, 0, 0
                    DB 16 DUP(0)
                    DB 16 DUP(0)
    FILE_SIZES      DW 36, 33, 20, 0, 0
    FILE_DATA       DB 'Welcome to MASM Shell Emulator! Test', 0, 64 DUP(0)
                    DB 'System Programming Lab Assignment 2', 0, 65 DUP(0)
                    DB 'BUFFERS=30 FILES=30', 0, 81 DUP(0)
                    DB 100 DUP(0)
                    DB 100 DUP(0)

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

    ; Display Welcome Banner
    LEA DX, BANNER
    MOV AH, 09H
    INT 21H

SHELL_LOOP:
    ; Print Prompt C:\>
    LEA DX, PROMPT
    MOV AH, 09H
    INT 21H

    ; Read command line from user
    CALL READ_COMMAND_LINE

    ; If empty command line, loop again
    CMP LINE_LEN, 0
    JE SHELL_LOOP

    ; Parse tokens from command line
    CALL PARSE_LINE

    ; Check command
    ; 1. Check EXIT
    LEA SI, TOKEN1
    LEA DI, CMD_EXIT
    CALL STRCMP_UPPER
    CMP AX, 0
    JE EXEC_EXIT

    ; 2. Check DIR
    LEA SI, TOKEN1
    LEA DI, CMD_DIR
    CALL STRCMP_UPPER
    CMP AX, 0
    JE EXEC_DIR

    ; 3. Check TYPE
    LEA SI, TOKEN1
    LEA DI, CMD_TYPE
    CALL STRCMP_UPPER
    CMP AX, 0
    JE EXEC_TYPE

    ; 4. Check COPY
    LEA SI, TOKEN1
    LEA DI, CMD_COPY
    CALL STRCMP_UPPER
    CMP AX, 0
    JE EXEC_COPY

    ; Unknown command
    LEA DX, MSG_BAD_CMD
    MOV AH, 09H
    INT 21H
    JMP SHELL_LOOP

EXEC_DIR:
    CALL CMD_DO_DIR
    JMP SHELL_LOOP

EXEC_TYPE:
    CALL CMD_DO_TYPE
    JMP SHELL_LOOP

EXEC_COPY:
    CALL CMD_DO_COPY
    JMP SHELL_LOOP

EXEC_EXIT:
    LEA DX, MSG_EXIT
    MOV AH, 09H
    INT 21H

    ; Terminate Program
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;-----------------------------------------------------------
; READ_COMMAND_LINE:
; Reads a line from keyboard using INT 21H, AH=01H
; Stores characters into LINE_BUF up to 90 chars.
; Converts Enter (0DH) to null termination and computes LINE_LEN.
; Handles Backspace (08H).
;-----------------------------------------------------------
READ_COMMAND_LINE PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    XOR SI, SI
RCL_LOOP:
    MOV AH, 01H
    INT 21H

    CMP AL, 0DH             ; Enter key?
    JE RCL_DONE

    CMP AL, 08H             ; Backspace?
    JE RCL_BS

    CMP SI, 90
    JAE RCL_LOOP            ; Max length reached, ignore extra chars

    MOV LINE_BUF[SI], AL
    INC SI
    JMP RCL_LOOP

RCL_BS:
    CMP SI, 0
    JE RCL_LOOP
    DEC SI
    ; Visually erase character in terminal: space then backspace
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    MOV DL, 08H
    MOV AH, 02H
    INT 21H
    JMP RCL_LOOP

RCL_DONE:
    ; Print newline for aesthetic after Enter
    MOV DL, 0AH
    MOV AH, 02H
    INT 21H

    MOV LINE_BUF[SI], 0     ; Null-terminate
    MOV LINE_LEN, SI

    POP SI
    POP DX
    POP BX
    POP AX
    RET
READ_COMMAND_LINE ENDP

;-----------------------------------------------------------
; PARSE_LINE:
; Extracts TOKEN1, TOKEN2, TOKEN3 from LINE_BUF.
; Tokens are whitespace-delimited (spaces or tabs).
; Tokens are null-terminated.
;-----------------------------------------------------------
PARSE_LINE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    ; Clear tokens
    MOV TOKEN1[0], 0
    MOV TOKEN2[0], 0
    MOV TOKEN3[0], 0

    LEA SI, LINE_BUF

    ; Extract TOKEN1
    CALL SKIP_SPACES
    CMP BYTE PTR [SI], 0
    JE PARSE_DONE
    LEA DI, TOKEN1
    CALL EXTRACT_TOKEN

    ; Extract TOKEN2
    CALL SKIP_SPACES
    CMP BYTE PTR [SI], 0
    JE PARSE_DONE
    LEA DI, TOKEN2
    CALL EXTRACT_TOKEN

    ; Extract TOKEN3
    CALL SKIP_SPACES
    CMP BYTE PTR [SI], 0
    JE PARSE_DONE
    LEA DI, TOKEN3
    CALL EXTRACT_TOKEN

PARSE_DONE:
    POP DI
    POP SI
    POP CX
    POP BX
    POP AX
    RET
PARSE_LINE ENDP

; Helper: Skip spaces at [SI]
SKIP_SPACES PROC
SS_LOOP:
    MOV AL, [SI]
    CMP AL, ' '
    JE SS_NEXT
    CMP AL, 09H             ; Tab
    JE SS_NEXT
    RET
SS_NEXT:
    INC SI
    JMP SS_LOOP
SKIP_SPACES ENDP

; Helper: Extract token from [SI] into [DI]
EXTRACT_TOKEN PROC
ET_LOOP:
    MOV AL, [SI]
    CMP AL, 0
    JE ET_DONE
    CMP AL, ' '
    JE ET_DONE
    CMP AL, 09H
    JE ET_DONE
    MOV [DI], AL
    INC SI
    INC DI
    JMP ET_LOOP
ET_DONE:
    MOV BYTE PTR [DI], 0    ; Null-terminate token
    RET
EXTRACT_TOKEN ENDP

;-----------------------------------------------------------
; STRCMP_UPPER:
; Compares null-terminated string at SI with string at DI,
; converting SI chars to uppercase on the fly.
; Returns AX = 0 if match, AX = 1 if not match.
;-----------------------------------------------------------
STRCMP_UPPER PROC
    PUSH BX
    PUSH SI
    PUSH DI
SCU_LOOP:
    MOV AL, [SI]
    MOV BL, [DI]

    ; Uppercase AL if lowercase
    CMP AL, 'a'
    JB NOT_LOWER_A
    CMP AL, 'z'
    JA NOT_LOWER_A
    SUB AL, 32
NOT_LOWER_A:

    ; Uppercase BL if lowercase
    CMP BL, 'a'
    JB NOT_LOWER_B
    CMP BL, 'z'
    JA NOT_LOWER_B
    SUB BL, 32
NOT_LOWER_B:

    CMP AL, BL
    JNE SCU_DIFF
    CMP AL, 0
    JE SCU_SAME
    INC SI
    INC DI
    JMP SCU_LOOP

SCU_SAME:
    MOV AX, 0
    JMP SCU_END
SCU_DIFF:
    MOV AX, 1
SCU_END:
    POP DI
    POP SI
    POP BX
    RET
STRCMP_UPPER ENDP

;-----------------------------------------------------------
; CMD_DO_DIR:
; Displays mock directory list.
;-----------------------------------------------------------
CMD_DO_DIR PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA DX, MSG_DIR_HDR
    MOV AH, 09H
    INT 21H

    XOR CX, CX              ; File counter
    XOR BX, BX              ; Total bytes accumulator
    XOR SI, SI              ; Index (0 to MAX_FILES - 1)

DIR_LOOP:
    CMP SI, MAX_FILES
    JAE DIR_SUMMARY

    ; Check if slot active
    CMP FILE_ACTIVE[SI], 1
    JNE DIR_NEXT

    INC CX                  ; Increment active file count

    ; Print 2 leading spaces
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    INT 21H

    ; Print filename (up to 16 chars)
    MOV AX, SI
    MOV DX, 16
    MUL DX
    LEA DI, FILE_NAMES
    ADD DI, AX

    ; Print filename and pad with spaces to 14 columns
    MOV COL_COUNT, 0        ; Char count in filename
PRINT_FNAME:
    MOV AL, [DI]
    CMP AL, 0
    JE PAD_FNAME
    MOV DL, AL
    MOV AH, 02H
    INT 21H
    INC DI
    INC COL_COUNT
    JMP PRINT_FNAME

PAD_FNAME:
    CMP COL_COUNT, 14
    JAE PRINT_FSIZE
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    INC COL_COUNT
    JMP PAD_FNAME

PRINT_FSIZE:
    ; Print size
    MOV DI, SI
    SHL DI, 1               ; Word index
    MOV AX, FILE_SIZES[DI]
    ADD BX, AX              ; Add to total bytes
    CALL PRINT_NUM

    LEA DX, MSG_BYTES_STR
    MOV AH, 09H
    INT 21H

DIR_NEXT:
    INC SI
    JMP DIR_LOOP

DIR_SUMMARY:
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H

    ; Print summary: "    X File(s)    Y bytes"
    MOV DL, ' '
    MOV AH, 02H
    INT 21H
    INT 21H
    INT 21H
    INT 21H

    MOV AX, CX
    CALL PRINT_NUM

    LEA DX, MSG_FILES_STR
    MOV AH, 09H
    INT 21H

    MOV AX, BX
    CALL PRINT_NUM

    LEA DX, MSG_BYTES_STR
    MOV AH, 09H
    INT 21H

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
CMD_DO_DIR ENDP

;-----------------------------------------------------------
; CMD_DO_TYPE:
; Displays the contents of file specified in TOKEN2.
;-----------------------------------------------------------
CMD_DO_TYPE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; Check if argument provided
    CMP TOKEN2[0], 0
    JNE TYPE_FIND
    LEA DX, MSG_TYPE_SYNTAX
    MOV AH, 09H
    INT 21H
    JMP TYPE_EXIT

TYPE_FIND:
    ; Search for TOKEN2 in active files
    XOR SI, SI
TYPE_SEARCH_LOOP:
    CMP SI, MAX_FILES
    JAE TYPE_NOT_FOUND

    CMP FILE_ACTIVE[SI], 1
    JNE TYPE_SEARCH_NEXT

    ; Compare filename
    MOV AX, SI
    MOV DX, 16
    MUL DX
    LEA DI, FILE_NAMES
    ADD DI, AX

    LEA DX, TOKEN2
    PUSH SI
    MOV SI, DX
    CALL STRCMP_UPPER
    POP SI
    CMP AX, 0
    JE TYPE_FOUND

TYPE_SEARCH_NEXT:
    INC SI
    JMP TYPE_SEARCH_LOOP

TYPE_FOUND:
    ; Print file content from FILE_DATA
    MOV AX, SI
    MOV DX, 100
    MUL DX
    LEA DI, FILE_DATA
    ADD DI, AX

PRINT_CONTENT:
    MOV AL, [DI]
    CMP AL, 0
    JE TYPE_PRINT_DONE
    MOV DL, AL
    MOV AH, 02H
    INT 21H
    INC DI
    JMP PRINT_CONTENT

TYPE_PRINT_DONE:
    LEA DX, CRLF
    MOV AH, 09H
    INT 21H
    JMP TYPE_EXIT

TYPE_NOT_FOUND:
    LEA DX, MSG_NOT_FOUND
    MOV AH, 09H
    INT 21H

TYPE_EXIT:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
CMD_DO_TYPE ENDP

;-----------------------------------------------------------
; CMD_DO_COPY:
; Copies file TOKEN2 (source) to TOKEN3 (destination).
;-----------------------------------------------------------
CMD_DO_COPY PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; Check both arguments
    CMP TOKEN2[0], 0
    JE COPY_SYNTAX_ERR
    CMP TOKEN3[0], 0
    JE COPY_SYNTAX_ERR

    ; 1. Find source file
    XOR SI, SI
FIND_SRC:
    CMP SI, MAX_FILES
    JAE COPY_SRC_NOT_FOUND

    CMP FILE_ACTIVE[SI], 1
    JNE NEXT_SRC

    MOV AX, SI
    MOV DX, 16
    MUL DX
    LEA DI, FILE_NAMES
    ADD DI, AX

    PUSH SI
    LEA SI, TOKEN2
    CALL STRCMP_UPPER
    POP SI
    CMP AX, 0
    JE FOUND_SRC

NEXT_SRC:
    INC SI
    JMP FIND_SRC

FOUND_SRC:
    MOV BX, SI              ; BX = Source index

    ; 2. Check if destination already exists
    XOR SI, SI
FIND_DEST:
    CMP SI, MAX_FILES
    JAE ALLOC_DEST

    CMP FILE_ACTIVE[SI], 1
    JNE NEXT_DEST

    MOV AX, SI
    MOV DX, 16
    MUL DX
    LEA DI, FILE_NAMES
    ADD DI, AX

    PUSH SI
    LEA SI, TOKEN3
    CALL STRCMP_UPPER
    POP SI
    CMP AX, 0
    JE FOUND_DEST_SLOT

NEXT_DEST:
    INC SI
    JMP FIND_DEST

ALLOC_DEST:
    ; Find first inactive slot
    XOR SI, SI
FIND_FREE_SLOT:
    CMP SI, MAX_FILES
    JAE COPY_DISK_FULL

    CMP FILE_ACTIVE[SI], 0
    JE FOUND_FREE_SLOT

    INC SI
    JMP FIND_FREE_SLOT

FOUND_FREE_SLOT:
    MOV FILE_ACTIVE[SI], 1

    ; Copy name from TOKEN3 into FILE_NAMES[SI]
    MOV AX, SI
    MOV DX, 16
    MUL DX
    LEA DI, FILE_NAMES
    ADD DI, AX
    LEA DX, TOKEN3
    PUSH SI
    MOV SI, DX
    MOV CX, 15
COPY_NAME_LOOP:
    MOV AL, [SI]
    MOV [DI], AL
    CMP AL, 0
    JE FINISH_NAME
    INC SI
    INC DI
    LOOP COPY_NAME_LOOP
    MOV BYTE PTR [DI], 0
FINISH_NAME:
    POP SI

FOUND_DEST_SLOT:
    ; SI = destination index, BX = source index
    ; Copy size
    MOV DI, BX
    SHL DI, 1
    MOV AX, FILE_SIZES[DI]
    MOV DI, SI
    SHL DI, 1
    MOV FILE_SIZES[DI], AX

    ; Copy data buffer (100 bytes)
    ; Source pointer
    MOV AX, BX
    MOV DX, 100
    MUL DX
    LEA DI, FILE_DATA
    ADD DI, AX
    PUSH DI                 ; Source data ptr on stack

    ; Destination pointer
    MOV AX, SI
    MOV DX, 100
    MUL DX
    LEA DI, FILE_DATA
    ADD DI, AX              ; Destination data ptr

    POP SI                  ; SI = source data, DI = dest data
    MOV CX, 100
    CLD
    REP MOVSB

    LEA DX, MSG_COPIED
    MOV AH, 09H
    INT 21H
    JMP COPY_EXIT

COPY_SYNTAX_ERR:
    LEA DX, MSG_COPY_SYNTAX
    MOV AH, 09H
    INT 21H
    JMP COPY_EXIT

COPY_SRC_NOT_FOUND:
    LEA DX, MSG_NOT_FOUND
    MOV AH, 09H
    INT 21H
    JMP COPY_EXIT

COPY_DISK_FULL:
    LEA DX, MSG_DISK_FULL
    MOV AH, 09H
    INT 21H

COPY_EXIT:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
CMD_DO_COPY ENDP

;-----------------------------------------------------------
; PRINT_NUM:
; Prints an unsigned integer in AX to standard output.
; Handles multi-digit numbers cleanly.
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

    ; If 0, print '0' directly
    MOV DL, '0'
    MOV AH, 02H
    INT 21H
    JMP PN_EXIT

PN_DIV_LOOP:
    XOR DX, DX
    DIV BX
    PUSH DX
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
