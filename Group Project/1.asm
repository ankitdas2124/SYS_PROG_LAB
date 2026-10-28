; ============================================================
;  MOUSE PAINT + LETTER & DIGIT DIGITIZER - 16-bit 8086, MASM/TASM
;  - Hold LEFT button  : draws
;  - Release button    : pause (pen lifted)
;  - Press again       : new stroke
;  - [Undo]            : removes last stroke
;  - [OK]              : DIGITIZES drawing in place -> recognises
;                        hand-drawn CAPITAL LETTERS (A-Z) and
;                        DIGITS (0-9) separated by spaces, prints
;                        them in their original places on screen.
;                        Unrecognized characters print as '?'.
;  - [Exit] / ESC      : leave, normal mouse / text mode returns
;
;  Upgraded Recognition Engine:
;   1. Adaptive ink thresholding (DYN_INKMIN scales with box area)
;   2. AutoCenterGrid: 2D shift-invariance (horizontal/vertical)
;   3. 65 multi-prototype handwriting templates for variations
;   4. Strict 8086 instruction set compatibility
; ============================================================
.model small
.stack 200h

; ---- constants ----
CANVAS_BOTTOM equ 428
MAXPTS        equ 7000
MAXSTK        equ 120          ; max strokes analysed
MAXLET        equ 32           ; max letters/digits recognized
MARGIN        equ 6            ; strokes closer than this in X = same character
MARGIN_Y      equ 25           ; vertical tolerance for grouping strokes
MAXDIST       equ 12           ; worse match than this -> '?'
SPACE_GAP     equ 28           ; X distance between characters to consider a space
NUM_TEMPL     equ 36           ; 26 letters (0..25) + 10 digits (26..35)
NUM_PROTOS    equ 65           ; 65 handwriting prototype templates
QMARK_IDX     equ 36           ; template index for '?'

UNDO_X1 equ 300
UNDO_X2 equ 380
OK_X1   equ 400
OK_X2   equ 480
EXIT_X1 equ 500
EXIT_X2 equ 580
BTN_Y1  equ 440
BTN_Y2  equ 470

PENCOL  equ 14                 ; yellow ink
LINECOL equ 15                 ; white border

.data
CURX     dw 0
CURY     dw 0
PREVX    dw 0
PREVY    dw 0
WASDOWN  db 0
STARTFLG db 0

PTCOUNT  dw 0
PTS      dw MAXPTS*2 dup(0)

; line drawing variables
X0      dw 0
Y0      dw 0
X1      dw 0
Y1      dw 0
DELX    dw 0
DELY    dw 0
STEPX   dw 0
STEPY   dw 0
ERRV    dw 0

; rectangle variables
RX1     dw 0
RY1     dw 0
RX2     dw 0
RY2     dw 0
RCOL    db 0

; ---- recognition data ----
NSTK    dw 0
NEND    dw 0
CHG     db 0
GMINX   dw MAXSTK dup(0)
GMAXX   dw MAXSTK dup(0)
GMINY   dw MAXSTK dup(0)
GMAXY   dw MAXSTK dup(0)
GALIVE  dw MAXSTK dup(0)

PICK    dw 0
PICKX   dw 0
BMINX   dw 0
BMAXX   dw 0
BMINY   dw 0
BMAXY   dw 0
BOXW    dw 0
BOXH    dw 0

CELLR   dw 0
CELLC   dw 0
CELLX1  dw 0
CELLX2  dw 0
CELLY1  dw 0
CELLY2  dw 0
INKCNT  dw 0
GRID    db 7 dup(0)

DYN_INKMIN dw 4
BESTD      dw 0
BESTI      dw 0
BEST_P     dw 0
TIDX       dw 0

; recognition results and bounding boxes
RESCOUNT dw 0
TXTCOUNT dw 0
LAST_X2  dw 0
RES_X1   dw MAXLET dup(0)
RES_X2   dw MAXLET dup(0)
RES_Y1   dw MAXLET dup(0)
RES_Y2   dw MAXLET dup(0)
RESIDX   db MAXLET+2 dup(0)
RESULT   db (MAXLET*2)+4 dup(0)

; glyph rendering variables
GLX     dw 0
GLY     dw 0
GPITCH  dw 6
GDOTSZ  dw 4
GROW    dw 0
GCOL    dw 0
GBITS   db 0

; ============================================================
;  CANONICAL 5x7 TEMPLATES (37 chars: A..Z, 0..9, '?')
;  Used by DrawGlyph to render crisp dot-matrix characters
; ============================================================
TEMPL label byte
 ; A..Z (indices 0..25)
 db 01110b,10001b,10001b,11111b,10001b,10001b,10001b   ; 0: A
 db 11110b,10001b,10001b,11110b,10001b,10001b,11110b   ; 1: B
 db 01110b,10001b,10000b,10000b,10000b,10001b,01110b   ; 2: C
 db 11110b,10001b,10001b,10001b,10001b,10001b,11110b   ; 3: D
 db 11111b,10000b,10000b,11110b,10000b,10000b,11111b   ; 4: E
 db 11111b,10000b,10000b,11110b,10000b,10000b,10000b   ; 5: F
 db 01110b,10001b,10000b,10111b,10001b,10001b,01111b   ; 6: G
 db 10001b,10001b,10001b,11111b,10001b,10001b,10001b   ; 7: H
 db 01110b,00100b,00100b,00100b,00100b,00100b,01110b   ; 8: I
 db 00111b,00010b,00010b,00010b,00010b,10010b,01100b   ; 9: J
 db 10001b,10010b,10100b,11000b,10100b,10010b,10001b   ; 10: K
 db 10000b,10000b,10000b,10000b,10000b,10000b,11111b   ; 11: L
 db 10001b,11011b,10101b,10101b,10001b,10001b,10001b   ; 12: M
 db 10001b,11001b,10101b,10011b,10001b,10001b,10001b   ; 13: N
 db 01110b,10001b,10001b,10001b,10001b,10001b,01110b   ; 14: O
 db 11110b,10001b,10001b,11110b,10000b,10000b,10000b   ; 15: P
 db 01110b,10001b,10001b,10001b,10101b,10010b,01101b   ; 16: Q
 db 11110b,10001b,10001b,11110b,10100b,10010b,10001b   ; 17: R
 db 01111b,10000b,10000b,01110b,00001b,00001b,11110b   ; 18: S
 db 11111b,00100b,00100b,00100b,00100b,00100b,00100b   ; 19: T
 db 10001b,10001b,10001b,10001b,10001b,10001b,01110b   ; 20: U
 db 10001b,10001b,10001b,10001b,10001b,01010b,00100b   ; 21: V
 db 10001b,10001b,10001b,10101b,10101b,11011b,10001b   ; 22: W
 db 10001b,10001b,01010b,00100b,01010b,10001b,10001b   ; 23: X
 db 10001b,10001b,01010b,00100b,00100b,00100b,00100b   ; 24: Y
 db 11111b,00001b,00010b,00100b,01000b,10000b,11111b   ; 25: Z
 ; 0..9 (indices 26..35)
 db 01110b,10001b,10011b,10101b,11001b,10001b,01110b   ; 26: 0
 db 00100b,01100b,00100b,00100b,00100b,00100b,01110b   ; 27: 1
 db 01110b,10001b,00001b,00010b,00100b,01000b,11111b   ; 28: 2
 db 11110b,00001b,00001b,01110b,00001b,00001b,11110b   ; 29: 3
 db 00010b,00110b,01010b,10010b,11111b,00010b,00010b   ; 30: 4
 db 11111b,10000b,11110b,00001b,00001b,10001b,01110b   ; 31: 5
 db 00110b,01000b,10000b,11110b,10001b,10001b,01110b   ; 32: 6
 db 11111b,00001b,00010b,00100b,01000b,01000b,01000b   ; 33: 7
 db 01110b,10001b,10001b,01110b,10001b,10001b,01110b   ; 34: 8
 db 01110b,10001b,10001b,01111b,00001b,00010b,01100b   ; 35: 9
 ; ? (index 36)
 db 01110b,10001b,00001b,00010b,00100b,00000b,00100b   ; 36: ?

; ============================================================
;  MULTI-PROTOTYPE HANDWRITING TEMPLATES (NUM_PROTOS = 65)
;  Captures real handwriting variations for robust matching
; ============================================================
PROTOS label byte
 ; --- A (2 styles: pointed, flat) ---
 db 00100b,01010b,10001b,11111b,10001b,10001b,10001b   ; 0: A pointed
 db 01110b,10001b,10001b,11111b,10001b,10001b,10001b   ; 1: A flat
 ; --- B (1 style) ---
 db 11110b,10001b,10001b,11110b,10001b,10001b,11110b   ; 2: B
 ; --- C (2 styles: round, open) ---
 db 01110b,10001b,10000b,10000b,10000b,10001b,01110b   ; 3: C round
 db 01111b,10000b,10000b,10000b,10000b,10000b,01111b   ; 4: C open
 ; --- D (1 style) ---
 db 11110b,10001b,10001b,10001b,10001b,10001b,11110b   ; 5: D
 ; --- E (1 style) ---
 db 11111b,10000b,10000b,11110b,10000b,10000b,11111b   ; 6: E
 ; --- F (1 style) ---
 db 11111b,10000b,10000b,11110b,10000b,10000b,10000b   ; 7: F
 ; --- G (1 style) ---
 db 01110b,10001b,10000b,10111b,10001b,10001b,01111b   ; 8: G
 ; --- H (1 style) ---
 db 10001b,10001b,10001b,11111b,10001b,10001b,10001b   ; 9: H
 ; --- I (2 styles: with bars, stick) ---
 db 01110b,00100b,00100b,00100b,00100b,00100b,01110b   ; 10: I bars
 db 00100b,00100b,00100b,00100b,00100b,00100b,00100b   ; 11: I stick
 ; --- J (2 styles: bar, no bar) ---
 db 00111b,00010b,00010b,00010b,00010b,10010b,01100b   ; 12: J with bar
 db 00010b,00010b,00010b,00010b,00010b,10010b,01100b   ; 13: J no bar
 ; --- K (1 style) ---
 db 10001b,10010b,10100b,11000b,10100b,10010b,10001b   ; 14: K
 ; --- L (1 style) ---
 db 10000b,10000b,10000b,10000b,10000b,10000b,11111b   ; 15: L
 ; --- M (2 styles: standard, deep V) ---
 db 10001b,11011b,10101b,10101b,10001b,10001b,10001b   ; 16: M standard
 db 10001b,11011b,10101b,10001b,10001b,10001b,10001b   ; 17: M deep V
 ; --- N (1 style) ---
 db 10001b,11001b,10101b,10011b,10001b,10001b,10001b   ; 18: N
 ; --- O (2 styles: oval, boxy) ---
 db 01110b,10001b,10001b,10001b,10001b,10001b,01110b   ; 19: O oval
 db 11111b,10001b,10001b,10001b,10001b,10001b,11111b   ; 20: O boxy
 ; --- P (1 style) ---
 db 11110b,10001b,10001b,11110b,10000b,10000b,10000b   ; 21: P
 ; --- Q (1 style) ---
 db 01110b,10001b,10001b,10001b,10101b,10010b,01101b   ; 22: Q
 ; --- R (1 style) ---
 db 11110b,10001b,10001b,11110b,10100b,10010b,10001b   ; 23: R
 ; --- S (2 styles: smooth, round) ---
 db 01111b,10000b,10000b,01110b,00001b,00001b,11110b   ; 24: S smooth
 db 01110b,10001b,10000b,01110b,00001b,10001b,01110b   ; 25: S round
 ; --- T (1 style) ---
 db 11111b,00100b,00100b,00100b,00100b,00100b,00100b   ; 26: T
 ; --- U (2 styles: round, boxy) ---
 db 10001b,10001b,10001b,10001b,10001b,10001b,01110b   ; 27: U round
 db 10001b,10001b,10001b,10001b,10001b,10001b,11111b   ; 28: U boxy
 ; --- V (2 styles: standard, narrow) ---
 db 10001b,10001b,10001b,10001b,10001b,01010b,00100b   ; 29: V standard
 db 10001b,10001b,01010b,01010b,01010b,00100b,00100b   ; 30: V narrow
 ; --- W (2 styles: standard, curved) ---
 db 10001b,10001b,10001b,10101b,10101b,11011b,10001b   ; 31: W standard
 db 10001b,10001b,10101b,10101b,10101b,01110b,00100b   ; 32: W curved
 ; --- X (1 style) ---
 db 10001b,10001b,01010b,00100b,01010b,10001b,10001b   ; 33: X
 ; --- Y (1 style) ---
 db 10001b,10001b,01010b,00100b,00100b,00100b,00100b   ; 34: Y
 ; --- Z (2 styles: standard, crossbar) ---
 db 11111b,00001b,00010b,00100b,01000b,10000b,11111b   ; 35: Z standard
 db 11111b,00001b,00110b,01100b,01000b,10000b,11111b   ; 36: Z crossbar

 ; --- 0 (3 styles: slashed, oval, boxy) ---
 db 01110b,10001b,10011b,10101b,11001b,10001b,01110b   ; 37: 0 slashed
 db 01110b,10001b,10001b,10001b,10001b,10001b,01110b   ; 38: 0 oval
 db 11111b,10001b,10001b,10001b,10001b,10001b,11111b   ; 39: 0 boxy

 ; --- 1 (4 styles: serif+base, stick, tick+stem, right stem) ---
 db 00100b,01100b,00100b,00100b,00100b,00100b,01110b   ; 40: 1 serif+base
 db 00100b,00100b,00100b,00100b,00100b,00100b,00100b   ; 41: 1 center stick
 db 01100b,00100b,00100b,00100b,00100b,00100b,00100b   ; 42: 1 tick+stem
 db 00010b,00010b,00010b,00010b,00010b,00010b,00010b   ; 43: 1 right stick

 ; --- 2 (3 styles: standard, flat top, loop base) ---
 db 01110b,10001b,00001b,00010b,00100b,01000b,11111b   ; 44: 2 standard
 db 11110b,00001b,00010b,00100b,01000b,10000b,11111b   ; 45: 2 flat top
 db 01110b,10001b,00001b,00010b,00100b,11000b,01111b   ; 46: 2 loop base

 ; --- 3 (3 styles: rounded, flat top, curved) ---
 db 11110b,00001b,00001b,01110b,00001b,00001b,11110b   ; 47: 3 rounded
 db 11111b,00001b,00010b,00100b,00010b,00001b,11110b   ; 48: 3 flat top
 db 01110b,10001b,00001b,00110b,00001b,10001b,01110b   ; 49: 3 curved

 ; --- 4 (3 styles: closed, open, centered) ---
 db 00010b,00110b,01010b,10010b,11111b,00010b,00010b   ; 50: 4 closed
 db 10010b,10010b,10010b,11111b,00010b,00010b,00010b   ; 51: 4 open
 db 00100b,01100b,10100b,11111b,00100b,00100b,00100b   ; 52: 4 centered

 ; --- 5 (2 styles: standard, sharp) ---
 db 11111b,10000b,11110b,00001b,00001b,10001b,01110b   ; 53: 5 standard
 db 11111b,10000b,11110b,00001b,00001b,00001b,11110b   ; 54: 5 sharp

 ; --- 6 (2 styles: curved back, full) ---
 db 00110b,01000b,10000b,11110b,10001b,10001b,01110b   ; 55: 6 curved
 db 01110b,10000b,10000b,11110b,10001b,10001b,01110b   ; 56: 6 full

 ; --- 7 (3 styles: plain slant, crossbar, steep) ---
 db 11111b,00001b,00010b,00100b,01000b,01000b,01000b   ; 57: 7 plain
 db 11111b,00001b,00010b,01110b,00100b,00100b,00100b   ; 58: 7 crossbar
 db 11111b,00010b,00010b,00100b,00100b,00100b,00100b   ; 59: 7 steep

 ; --- 8 (2 styles: standard, hourglass) ---
 db 01110b,10001b,10001b,01110b,10001b,10001b,01110b   ; 60: 8 standard
 db 01110b,10001b,01010b,00100b,01010b,10001b,01110b   ; 61: 8 hourglass

 ; --- 9 (3 styles: hook, straight, full) ---
 db 01110b,10001b,10001b,01111b,00001b,00010b,01100b   ; 62: 9 hook
 db 01110b,10001b,10001b,01111b,00001b,00001b,00001b   ; 63: 9 straight
 db 01110b,10001b,10001b,11111b,00001b,00001b,00001b   ; 64: 9 full

; Mapping from prototype index (0..64) to canonical index (0..35)
PROTO_MAP label byte
 db 0, 0                ; 0..1: A
 db 1                   ; 2: B
 db 2, 2                ; 3..4: C
 db 3                   ; 5: D
 db 4                   ; 6: E
 db 5                   ; 7: F
 db 6                   ; 8: G
 db 7                   ; 9: H
 db 8, 8                ; 10..11: I
 db 9, 9                ; 12..13: J
 db 10                  ; 14: K
 db 11                  ; 15: L
 db 12, 12              ; 16..17: M
 db 13                  ; 18: N
 db 14, 14              ; 19..20: O
 db 15                  ; 21: P
 db 16                  ; 22: Q
 db 17                  ; 23: R
 db 18, 18              ; 24..25: S
 db 19                  ; 26: T
 db 20, 20              ; 27..28: U
 db 21, 21              ; 29..30: V
 db 22, 22              ; 31..32: W
 db 23                  ; 33: X
 db 24                  ; 34: Y
 db 25, 25              ; 35..36: Z
 db 26, 26, 26          ; 37..39: 0
 db 27, 27, 27, 27      ; 40..43: 1
 db 28, 28, 28          ; 44..46: 2
 db 29, 29, 29          ; 47..49: 3
 db 30, 30, 30          ; 50..52: 4
 db 31, 31              ; 53..54: 5
 db 32, 32              ; 55..56: 6
 db 33, 33, 33          ; 57..59: 7
 db 34, 34              ; 60..61: 8
 db 35, 35, 35          ; 62..64: 9

msgUndo  db 'Undo',0
msgOK    db 'OK',0
msgExit  db 'Exit',0
msgRec   db 'Recognized: ',0
msgNone  db 'No letters or digits found.',0
msgFin   db 'Click Exit (or press ESC) to quit.',0
msgNoMs  db 'Mouse driver not found.$'

.code
; ------------------------------------------------------------
main proc
    mov  ax, @data
    mov  ds, ax

    mov  ax, 0012h             ; 640x480 16-color VGA graphics mode
    int  10h

    mov  ax, 0                 ; check mouse driver
    int  33h
    cmp  ax, 0
    jne  mouse_ok
    mov  ax, 0003h
    int  10h
    mov  dx, offset msgNoMs
    mov  ah, 9
    int  21h
    jmp  exit_prog

mouse_ok:
    mov  ax, 7                 ; set mouse X limits (0..639)
    mov  cx, 0
    mov  dx, 639
    int  33h
    mov  ax, 8                 ; set mouse Y limits (0..479)
    mov  cx, 0
    mov  dx, 479
    int  33h

    call DrawUI
    mov  ax, 1                 ; show mouse cursor
    int  33h

; ------------------------- main loop ------------------------
poll:
    call CheckKey
    cmp  al, 1
    jne  read_mouse
    jmp  quit
read_mouse:
    mov  ax, 3
    int  33h
    mov  CURX, cx
    mov  CURY, dx
    test bx, 1
    jnz  is_down
    mov  WASDOWN, 0
    jmp  poll

is_down:
    cmp  WASDOWN, 1
    je   do_draw

    call HitExit
    cmp  al, 1
    jne  chk_undo
    jmp  quit
chk_undo:
    call HitUndo
    cmp  al, 1
    jne  chk_ok
    call DoUndo
    jmp  poll
chk_ok:
    call HitOK
    cmp  al, 1
    jne  do_draw
    jmp  finish

do_draw:
    call DoDraw
    jmp  poll

; ------------------------- OK pressed -----------------------
finish:
    mov  ax, 2                 ; hide mouse while reading screen
    int  33h

    call Recognize             ; digitize the drawing -> RESULT & positions
    call ShowResultInPlace     ; print digitized characters in their places

    mov  ax, 1                 ; show mouse cursor
    int  33h
    call WaitRelease

final_wait:
    mov  ah, 1
    int  16h
    jz   final_mouse
    mov  ah, 0
    int  16h
    cmp  al, 27                ; ESC
    je   quit
    jmp  quit

final_mouse:
    mov  ax, 3
    int  33h
    test bx, 1
    jz   final_wait
    mov  CURX, cx
    mov  CURY, dx
    call HitExit
    cmp  al, 1
    je   quit
    call HitUndo
    cmp  al, 1
    jne  final_wait

    ; If Undo clicked after recognition: restore hand-drawn strokes
    call Redraw
    call DrawUI
    mov  ax, 1
    int  33h
    call WaitRelease
    jmp  poll

; ------------------------- exit -----------------------------
quit:
    mov  ax, 2                 ; hide mouse
    int  33h
    mov  ax, 0003h             ; restore standard 80x25 text mode
    int  10h
    mov  ax, 0                 ; reset mouse driver
    int  33h
exit_prog:
    mov  ax, 4C00h
    int  21h
main endp

; ============================================================
;                    DRAWING PART
; ============================================================
DoDraw proc
    push ax

    cmp  CURY, CANVAS_BOTTOM
    jbe  dd_inside
    mov  WASDOWN, 0
    jmp  dd_ret
dd_inside:
    cmp  PTCOUNT, MAXPTS
    jb   dd_room
    jmp  dd_ret
dd_room:
    cmp  WASDOWN, 0
    jne  dd_cont

    mov  ax, CURX
    mov  PREVX, ax
    mov  ax, CURY
    mov  PREVY, ax
    mov  STARTFLG, 1
    jmp  dd_record

dd_cont:
    mov  ax, CURX
    cmp  ax, PREVX
    jne  dd_moved
    mov  ax, CURY
    cmp  ax, PREVY
    jne  dd_moved
    jmp  dd_ret
dd_moved:
    mov  STARTFLG, 0

dd_record:
    call AddPoint

    mov  ax, PREVX
    mov  X0, ax
    mov  ax, PREVY
    mov  Y0, ax
    mov  ax, CURX
    mov  X1, ax
    mov  ax, CURY
    mov  Y1, ax

    mov  ax, 2
    int  33h
    call DrawLine
    mov  ax, 1
    int  33h

    mov  ax, CURX
    mov  PREVX, ax
    mov  ax, CURY
    mov  PREVY, ax
    mov  WASDOWN, 1
dd_ret:
    pop  ax
    ret
DoDraw endp

AddPoint proc
    push ax
    push bx
    mov  bx, PTCOUNT
    shl  bx, 1
    shl  bx, 1
    mov  ax, CURX
    mov  PTS[bx], ax
    mov  ax, CURY
    cmp  STARTFLG, 0
    je   ap_store
    or   ax, 8000h             ; high bit marks start of new stroke
ap_store:
    mov  PTS[bx+2], ax
    inc  PTCOUNT
    pop  bx
    pop  ax
    ret
AddPoint endp

DoUndo proc
    push ax
    push bx
    mov  ax, 2
    int  33h

    mov  bx, PTCOUNT
un_find:
    cmp  bx, 0
    je   un_set
    dec  bx
    push bx
    shl  bx, 1
    shl  bx, 1
    test word ptr PTS[bx+2], 8000h
    pop  bx
    jz   un_find
un_set:
    mov  PTCOUNT, bx
    call Redraw

    mov  ax, 1
    int  33h
    call WaitRelease
    pop  bx
    pop  ax
    ret
DoUndo endp

Redraw proc
    push ax
    push bx
    push cx
    push si

    mov  RX1, 0
    mov  RY1, 0
    mov  RX2, 639
    mov  RY2, CANVAS_BOTTOM+1
    mov  RCOL, 0
    call FillRect

    xor  si, si
rd_loop:
    cmp  si, PTCOUNT
    jb   rd_body
    jmp  rd_done
rd_body:
    mov  bx, si
    shl  bx, 1
    shl  bx, 1
    mov  ax, PTS[bx]
    mov  X1, ax
    mov  ax, PTS[bx+2]
    mov  cx, ax
    and  ax, 7FFFh
    mov  Y1, ax
    test cx, 8000h
    jz   rd_draw
    mov  ax, X1
    mov  X0, ax
    mov  ax, Y1
    mov  Y0, ax
rd_draw:
    call DrawLine
    inc  si
    jmp  rd_loop
rd_done:
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret
Redraw endp

DrawUI proc
    ; Separator line
    mov  RX1, 0
    mov  RY1, CANVAS_BOTTOM+2
    mov  RX2, 639
    mov  RY2, CANVAS_BOTTOM+2
    mov  RCOL, LINECOL
    call FillRect

    ; Clear status area to left of buttons
    mov  RX1, 0
    mov  RY1, CANVAS_BOTTOM+3
    mov  RX2, 290
    mov  RY2, 479
    mov  RCOL, 0
    call FillRect

    ; Undo button (Blue)
    mov  RX1, UNDO_X1
    mov  RY1, BTN_Y1
    mov  RX2, UNDO_X2
    mov  RY2, BTN_Y2
    mov  RCOL, 1
    call FillRect
    mov  dh, 28
    mov  dl, 41
    mov  si, offset msgUndo
    call PrintStr

    ; OK button (Green)
    mov  RX1, OK_X1
    mov  RY1, BTN_Y1
    mov  RX2, OK_X2
    mov  RY2, BTN_Y2
    mov  RCOL, 2
    call FillRect
    mov  dh, 28
    mov  dl, 54
    mov  si, offset msgOK
    call PrintStr

    call DrawExitBtn
    ret
DrawUI endp

DrawExitBtn proc
    mov  RX1, EXIT_X1
    mov  RY1, BTN_Y1
    mov  RX2, EXIT_X2
    mov  RY2, BTN_Y2
    mov  RCOL, 4               ; Red
    call FillRect
    mov  dh, 28
    mov  dl, 65
    mov  si, offset msgExit
    call PrintStr
    ret
DrawExitBtn endp

HitUndo proc
    mov  RX1, UNDO_X1
    mov  RX2, UNDO_X2
    jmp  HitTest
HitUndo endp

HitOK proc
    mov  RX1, OK_X1
    mov  RX2, OK_X2
    jmp  HitTest
HitOK endp

HitExit proc
    mov  RX1, EXIT_X1
    mov  RX2, EXIT_X2
    jmp  HitTest
HitExit endp

HitTest proc
    mov  RY1, BTN_Y1
    mov  RY2, BTN_Y2
    mov  ax, CURX
    cmp  ax, RX1
    jb   ht_no
    cmp  ax, RX2
    ja   ht_no
    mov  ax, CURY
    cmp  ax, RY1
    jb   ht_no
    cmp  ax, RY2
    ja   ht_no
    mov  al, 1
    ret
ht_no:
    mov  al, 0
    ret
HitTest endp

CheckKey proc
    mov  ah, 1
    int  16h
    jz   ck_no
    mov  ah, 0
    int  16h
    cmp  al, 27                ; ESC
    jne  ck_no
    mov  al, 1
    ret
ck_no:
    mov  al, 0
    ret
CheckKey endp

WaitRelease proc
    push ax
    push bx
    push cx
    push dx
wr_loop:
    mov  ax, 3
    int  33h
    test bx, 1
    jnz  wr_loop
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
WaitRelease endp

FillRect proc
    push ax
    push bx
    push cx
    push dx
    mov  dx, RY1
fr_row:
    mov  cx, RX1
fr_col:
    mov  ah, 0Ch
    mov  al, RCOL
    mov  bh, 0
    int  10h
    inc  cx
    cmp  cx, RX2
    jbe  fr_col
    inc  dx
    cmp  dx, RY2
    jbe  fr_row
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
FillRect endp

PrintStr proc
    push ax
    push bx
    push si
    mov  ah, 2
    mov  bh, 0
    int  10h
ps_next:
    lodsb
    cmp  al, 0
    je   ps_done
    mov  ah, 0Eh
    mov  bh, 0
    mov  bl, 15
    int  10h
    jmp  ps_next
ps_done:
    pop  si
    pop  bx
    pop  ax
    ret
PrintStr endp

PlotPt proc
    push ax
    push bx
    push cx
    push dx
    mov  ah, 0Ch
    mov  al, PENCOL
    mov  bh, 0
    mov  cx, X0
    mov  dx, Y0
    int  10h
    mov  ah, 0Ch
    mov  al, PENCOL
    mov  bh, 0
    mov  cx, X0
    inc  cx
    mov  dx, Y0
    int  10h
    mov  ah, 0Ch
    mov  al, PENCOL
    mov  bh, 0
    mov  cx, X0
    mov  dx, Y0
    inc  dx
    int  10h
    mov  ah, 0Ch
    mov  al, PENCOL
    mov  bh, 0
    mov  cx, X0
    inc  cx
    mov  dx, Y0
    inc  dx
    int  10h
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
PlotPt endp

DrawLine proc
    push ax
    push bx
    push cx

    mov  ax, X1
    sub  ax, X0
    mov  STEPX, 1
    jge  dx_ok
    neg  ax
    mov  STEPX, -1
dx_ok:
    mov  DELX, ax

    mov  ax, Y1
    sub  ax, Y0
    mov  STEPY, 1
    jge  dy_ok
    neg  ax
    mov  STEPY, -1
dy_ok:
    mov  DELY, ax

    mov  ax, DELX
    sub  ax, DELY
    mov  ERRV, ax

dl_loop:
    call PlotPt

    mov  ax, X0
    cmp  ax, X1
    jne  dl_cont
    mov  ax, Y0
    cmp  ax, Y1
    je   dl_done
dl_cont:
    mov  bx, ERRV
    shl  bx, 1

    mov  cx, DELY
    neg  cx
    cmp  bx, cx
    jle  dl_skip1
    mov  ax, DELY
    sub  ERRV, ax
    mov  ax, STEPX
    add  X0, ax
dl_skip1:
    cmp  bx, DELX
    jge  dl_skip2
    mov  ax, DELX
    add  ERRV, ax
    mov  ax, STEPY
    add  Y0, ax
dl_skip2:
    jmp  dl_loop

dl_done:
    pop  cx
    pop  bx
    pop  ax
    ret
DrawLine endp

; ============================================================
;              DIGITIZER / RECOGNITION ENGINE
; ============================================================

; ------------------------------------------------------------
; Recognize : analyzes drawn strokes -> characters in RESULT,
;             RESIDX, RESCOUNT, and records their bounding boxes
;             in RES_X1, RES_X2, RES_Y1, RES_Y2.
; ------------------------------------------------------------
Recognize proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov  RESCOUNT, 0
    mov  TXTCOUNT, 0
    mov  RESULT[0], 0
    mov  LAST_X2, 0

    call BuildStrokes
    mov  ax, NSTK
    shl  ax, 1
    mov  NEND, ax
    call MergeGroups

rc_next:
    mov  PICK, 0FFFFh          ; find leftmost remaining group
    mov  PICKX, 7FFFh
    xor  si, si
rc_scan:
    cmp  si, NEND
    jae  rc_pick
    cmp  GALIVE[si], 0
    je   rc_snext
    mov  ax, GMINX[si]
    cmp  ax, PICKX
    jge  rc_snext
    mov  PICKX, ax
    mov  PICK, si
rc_snext:
    add  si, 2
    jmp  rc_scan

rc_pick:
    cmp  PICK, 0FFFFh
    jne  rc_have
    jmp  rc_done

rc_have:
    mov  si, PICK
    mov  GALIVE[si], 0         ; mark group as processed
    mov  ax, GMINX[si]
    mov  BMINX, ax
    mov  ax, GMAXX[si]
    mov  BMAXX, ax
    mov  ax, GMINY[si]
    mov  BMINY, ax
    mov  ax, GMAXY[si]
    mov  BMAXY, ax

    call ClassifyBox           ; AX = canonical index (0..35, 36='?', 0FFFFh=noise)
    cmp  ax, 0FFFFh
    jne  rc_store
    jmp  rc_next

rc_store:
    ; Space detection: if gap between this character and previous >= SPACE_GAP
    cmp  RESCOUNT, 0
    je   rc_no_space
    mov  cx, BMINX
    sub  cx, LAST_X2
    cmp  cx, SPACE_GAP
    jb   rc_no_space

    ; Append space to text result string
    mov  bx, TXTCOUNT
    mov  RESULT[bx], ' '
    inc  TXTCOUNT
    inc  bx
    mov  RESULT[bx], 0

rc_no_space:
    mov  cx, BMAXX
    mov  LAST_X2, cx

    ; Record bounding box
    mov  bx, RESCOUNT
    mov  di, bx
    shl  di, 1
    mov  cx, BMINX
    mov  RES_X1[di], cx
    mov  cx, BMAXX
    mov  RES_X2[di], cx
    mov  cx, BMINY
    mov  RES_Y1[di], cx
    mov  cx, BMAXY
    mov  RES_Y2[di], cx

    ; Store canonical template index
    mov  RESIDX[bx], al

    ; Convert canonical index AL to ASCII character in DL
    cmp  al, 26
    jb   rc_alpha
    cmp  al, 36
    jb   rc_digit
    mov  dl, '?'               ; unrecognized -> '?'
    jmp  rc_put_ascii
rc_digit:
    mov  dl, al
    sub  dl, 26
    add  dl, '0'
    jmp  rc_put_ascii
rc_alpha:
    mov  dl, al
    add  dl, 'A'
rc_put_ascii:
    mov  bx, TXTCOUNT
    mov  RESULT[bx], dl
    inc  TXTCOUNT
    inc  bx
    mov  RESULT[bx], 0

    inc  RESCOUNT
    cmp  RESCOUNT, MAXLET
    jae  rc_done
    jmp  rc_next

rc_done:
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
Recognize endp

; ------------------------------------------------------------
; BuildStrokes : computes bounding box of every stroke -> G...
; ------------------------------------------------------------
BuildStrokes proc
    push ax
    push bx
    push cx
    push si
    push di

    mov  NSTK, 0
    xor  si, si
bs_loop:
    cmp  si, PTCOUNT
    jb   bs_body
    jmp  bs_done
bs_body:
    mov  bx, si
    shl  bx, 1
    shl  bx, 1
    mov  ax, PTS[bx]           ; x
    mov  cx, PTS[bx+2]         ; y + flag
    test cx, 8000h
    jz   bs_extend

    and  cx, 7FFFh             ; --- new stroke ---
    cmp  NSTK, MAXSTK
    jb   bs_new
    jmp  bs_done
bs_new:
    mov  di, NSTK
    shl  di, 1
    mov  GMINX[di], ax
    mov  GMAXX[di], ax
    mov  GMINY[di], cx
    mov  GMAXY[di], cx
    mov  GALIVE[di], 1
    inc  NSTK
    jmp  bs_next

bs_extend:                     ; --- grow current stroke's box ---
    mov  di, NSTK
    dec  di
    shl  di, 1
    cmp  ax, GMINX[di]
    jge  bs_a
    mov  GMINX[di], ax
bs_a:
    cmp  ax, GMAXX[di]
    jle  bs_b
    mov  GMAXX[di], ax
bs_b:
    cmp  cx, GMINY[di]
    jge  bs_c
    mov  GMINY[di], cx
bs_c:
    cmp  cx, GMAXY[di]
    jle  bs_next
    mov  GMAXY[di], cx
bs_next:
    inc  si
    jmp  bs_loop
bs_done:
    pop  di
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret
BuildStrokes endp

; ------------------------------------------------------------
; MergeGroups : merge strokes that overlap in X and Y (same char)
; ------------------------------------------------------------
MergeGroups proc
    push ax
    push si
    push di
mg_again:
    mov  CHG, 0
    xor  si, si
mg_i:
    cmp  si, NEND
    jb   mg_ichk
    jmp  mg_chk
mg_ichk:
    cmp  GALIVE[si], 0
    jne  mg_istart
    jmp  mg_inext
mg_istart:
    mov  di, si
    add  di, 2
mg_j:
    cmp  di, NEND
    jae  mg_inext
    cmp  GALIVE[di], 0
    je   mg_jnext
    call Overlap
    cmp  al, 1
    jne  mg_jnext
    call UnionJ
mg_jnext:
    add  di, 2
    jmp  mg_j
mg_inext:
    add  si, 2
    jmp  mg_i
mg_chk:
    cmp  CHG, 0
    je   mg_done
    jmp  mg_again
mg_done:
    pop  di
    pop  si
    pop  ax
    ret
MergeGroups endp

; AL=1 if group SI and group DI overlap in X (with MARGIN) and Y (with MARGIN_Y)
Overlap proc
    mov  ax, GMAXX[si]
    add  ax, MARGIN
    cmp  GMINX[di], ax
    jg   ov_no
    mov  ax, GMAXX[di]
    add  ax, MARGIN
    cmp  GMINX[si], ax
    jg   ov_no

    mov  ax, GMAXY[si]
    add  ax, MARGIN_Y
    cmp  GMINY[di], ax
    jg   ov_no
    mov  ax, GMAXY[di]
    add  ax, MARGIN_Y
    cmp  GMINY[si], ax
    jg   ov_no

    mov  al, 1
    ret
ov_no:
    mov  al, 0
    ret
Overlap endp

; merge group DI into group SI, kill DI
UnionJ proc
    push ax
    mov  ax, GMINX[di]
    cmp  ax, GMINX[si]
    jge  uj1
    mov  GMINX[si], ax
uj1:
    mov  ax, GMAXX[di]
    cmp  ax, GMAXX[si]
    jle  uj2
    mov  GMAXX[si], ax
uj2:
    mov  ax, GMINY[di]
    cmp  ax, GMINY[si]
    jge  uj3
    mov  GMINY[si], ax
uj3:
    mov  ax, GMAXY[di]
    cmp  ax, GMAXY[si]
    jle  uj4
    mov  GMAXY[si], ax
uj4:
    mov  GALIVE[di], 0
    mov  CHG, 1
    pop  ax
    ret
UnionJ endp

; ------------------------------------------------------------
; ClassifyBox : AX = canonical index (0..35), 36 = '?', 0FFFFh = noise
; ------------------------------------------------------------
ClassifyBox proc
    push bx
    mov  ax, BMAXX
    sub  ax, BMINX
    add  ax, 2                 ; +2 for pen thickness
    mov  BOXW, ax
    mov  ax, BMAXY
    sub  ax, BMINY
    add  ax, 2
    mov  BOXH, ax

    cmp  BOXH, 12              ; too small -> noise
    jae  cb_ok_size
    mov  ax, 0FFFFh
    jmp  cb_ret

cb_ok_size:
    ; Compute adaptive ink threshold based on bounding box area
    ; Area / 210 gives ~16% of average cell area
    mov  ax, BOXW
    mov  bx, BOXH
    mul  bx                    ; DX:AX = BOXW * BOXH
    mov  bx, 210
    div  bx
    cmp  ax, 2
    jge  dim_min
    mov  ax, 2
dim_min:
    cmp  ax, 14
    jle  dim_max
    mov  ax, 14
dim_max:
    mov  DYN_INKMIN, ax

    ; Build 5x7 grid from screen pixels
    call BuildGrid

    ; Auto-center the grid horizontally and vertically for shift invariance
    call AutoCenterGrid

    ; Match against handwriting prototypes
    call Match
    cmp  BESTD, MAXDIST
    jbe  cb_ret
    mov  ax, QMARK_IDX         ; no good match -> 36 = '?'
cb_ret:
    pop  bx
    ret
ClassifyBox endp

; ------------------------------------------------------------
; BuildGrid : fill GRID (7 rows x 5 bits) from screen pixels
; ------------------------------------------------------------
BuildGrid proc
    push ax
    push bx
    xor  bx, bx
bg_clr:
    mov  GRID[bx], 0
    inc  bx
    cmp  bx, 7
    jb   bg_clr

    mov  CELLR, 0
bg_r:
    mov  CELLC, 0
bg_c:
    call DoCell
    inc  CELLC
    cmp  CELLC, 5
    jb   bg_c
    inc  CELLR
    cmp  CELLR, 7
    jb   bg_r
    pop  bx
    pop  ax
    ret
BuildGrid endp

; AX = AX*CX/BX
ScaleDiv proc
    push dx
    mul  cx
    div  bx
    pop  dx
    ret
ScaleDiv endp

; ------------------------------------------------------------
; DoCell : check ink in cell (CELLR, CELLC), set GRID bit
; ------------------------------------------------------------
DoCell proc
    push ax
    push bx
    push cx
    push dx

    ; ---- y range ----
    mov  ax, CELLR
    mov  cx, BOXH
    mov  bx, 7
    call ScaleDiv
    add  ax, BMINY
    mov  CELLY1, ax
    mov  ax, CELLR
    inc  ax
    mov  cx, BOXH
    mov  bx, 7
    call ScaleDiv
    add  ax, BMINY
    dec  ax
    cmp  ax, CELLY1
    jge  dc_y
    mov  ax, CELLY1
dc_y:
    mov  CELLY2, ax

    ; ---- x range ----
    mov  ax, CELLC
    mov  cx, BOXW
    mov  bx, 5
    call ScaleDiv
    add  ax, BMINX
    mov  CELLX1, ax
    mov  ax, CELLC
    inc  ax
    mov  cx, BOXW
    mov  bx, 5
    call ScaleDiv
    add  ax, BMINX
    dec  ax
    cmp  ax, CELLX1
    jge  dc_x
    mov  ax, CELLX1
dc_x:
    mov  CELLX2, ax

    call CellInk               ; AL = 1 if ink found
    cmp  al, 1
    jne  dc_done
    mov  cx, 4
    sub  cx, CELLC
    mov  al, 1
    shl  al, cl                ; bit (4 - column)
    mov  bx, CELLR
    or   GRID[bx], al
dc_done:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
DoCell endp

; ------------------------------------------------------------
; CellInk : AL=1 if >= DYN_INKMIN pen pixels in cell
; ------------------------------------------------------------
CellInk proc
    push bx
    push cx
    push dx
    mov  INKCNT, 0
    mov  dx, CELLY1
ci_row:
    mov  cx, CELLX1
ci_col:
    push cx
    push dx
    mov  ah, 0Dh               ; read pixel -> AL
    mov  bh, 0
    int  10h
    pop  dx
    pop  cx
    cmp  al, PENCOL
    jne  ci_no
    inc  INKCNT
    mov  ax, INKCNT
    cmp  ax, DYN_INKMIN
    jae  ci_yes
ci_no:
    inc  cx
    cmp  cx, CELLX2
    jbe  ci_col
    inc  dx
    cmp  dx, CELLY2
    jbe  ci_row
    mov  al, 0
    jmp  ci_ret
ci_yes:
    mov  al, 1
ci_ret:
    pop  dx
    pop  cx
    pop  bx
    ret
CellInk endp

; ------------------------------------------------------------
; AutoCenterGrid : centers the 5x7 binary grid horizontally
;                  and vertically to achieve shift invariance
; ------------------------------------------------------------
AutoCenterGrid proc
    push ax
    push bx
    push cx

    ; ---- Horizontal centering check ----
    xor  al, al
    xor  bx, bx
ac_or:
    or   al, GRID[bx]
    inc  bx
    cmp  bx, 7
    jb   ac_or

    test al, al
    jz   ac_done               ; grid is completely empty

    ; Bit 4 = column 0 (leftmost: 10000b)
    ; Bit 0 = column 4 (rightmost: 00001b)
    test al, 10000b
    jnz  ac_check_right

    ; Left column is empty
    test al, 00001b
    jz   ac_vert               ; both col 0 and col 4 empty -> already centered
    ; Shift all rows left by 1 bit
    xor  bx, bx
ac_shl:
    shl  GRID[bx], 1
    inc  bx
    cmp  bx, 7
    jb   ac_shl
    jmp  ac_vert

ac_check_right:
    ; Left column has ink. If right column is empty -> shift right by 1 bit
    test al, 00001b
    jnz  ac_vert
    xor  bx, bx
ac_shr:
    shr  GRID[bx], 1
    inc  bx
    cmp  bx, 7
    jb   ac_shr

    ; ---- Vertical centering check ----
ac_vert:
    cmp  GRID[0], 0
    jne  ac_check_bottom
    cmp  GRID[6], 0
    je   ac_done               ; both row 0 and 6 empty
    ; Row 0 is empty, row 6 has ink -> shift up by 1 row
    mov  al, GRID[1]
    mov  GRID[0], al
    mov  al, GRID[2]
    mov  GRID[1], al
    mov  al, GRID[3]
    mov  GRID[2], al
    mov  al, GRID[4]
    mov  GRID[3], al
    mov  al, GRID[5]
    mov  GRID[4], al
    mov  al, GRID[6]
    mov  GRID[5], al
    mov  GRID[6], 0
    jmp  ac_done

ac_check_bottom:
    cmp  GRID[6], 0
    jne  ac_done
    ; Row 6 is empty, row 0 has ink -> shift down by 1 row
    mov  al, GRID[5]
    mov  GRID[6], al
    mov  al, GRID[4]
    mov  GRID[5], al
    mov  al, GRID[3]
    mov  GRID[4], al
    mov  al, GRID[2]
    mov  GRID[3], al
    mov  al, GRID[1]
    mov  GRID[2], al
    mov  al, GRID[0]
    mov  GRID[1], al
    mov  GRID[0], 0

ac_done:
    pop  cx
    pop  bx
    pop  ax
    ret
AutoCenterGrid endp

; ------------------------------------------------------------
; Match : compare GRID with 65 handwriting prototypes
;         Returns: AX = canonical index (0..35) of closest match,
;                  BESTD = lowest Hamming distance found
; ------------------------------------------------------------
Match proc
    push bx
    push cx
    push dx
    push si

    mov  BESTD, 0FFFFh
    mov  BEST_P, 0
    mov  TIDX, 0
    mov  si, offset PROTOS
mt_next:
    xor  dx, dx                ; DX = distance accumulator
    xor  bx, bx                ; BX = row 0..6
mt_row:
    mov  al, GRID[bx]
    xor  al, [si+bx]           ; differing bits
    mov  cx, 5
mt_bit:
    shr  al, 1
    adc  dx, 0
    loop mt_bit
    inc  bx
    cmp  bx, 7
    jb   mt_row

    cmp  dx, BESTD
    jae  mt_skip
    mov  BESTD, dx
    mov  ax, TIDX
    mov  BEST_P, ax
mt_skip:
    add  si, 7
    inc  TIDX
    cmp  TIDX, NUM_PROTOS
    jb   mt_next

    ; Map best prototype to canonical index (0..35)
    mov  bx, BEST_P
    xor  ax, ax
    mov  al, PROTO_MAP[bx]

    pop  si
    pop  dx
    pop  cx
    pop  bx
    ret
Match endp

; ============================================================
;             SHOW RESULT IN PLACE (WHERE DRAWN)
; ============================================================
ShowResultInPlace proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Clear drawing canvas area to black (erases hand-drawn yellow strokes)
    mov  RX1, 0
    mov  RY1, 0
    mov  RX2, 639
    mov  RY2, CANVAS_BOTTOM
    mov  RCOL, 0
    call FillRect

    cmp  RESCOUNT, 0
    jne  srip_have

    mov  dh, 12
    mov  dl, 15
    mov  si, offset msgNone
    call PrintStr
    jmp  srip_bottom

srip_have:
    xor  si, si                ; SI = character index 0 .. RESCOUNT - 1
srip_loop:
    cmp  si, RESCOUNT
    jae  srip_bottom

    mov  di, si
    shl  di, 1

    ; Box width and height
    mov  ax, RES_X2[di]
    sub  ax, RES_X1[di]
    add  ax, 2
    mov  BOXW, ax

    mov  ax, RES_Y2[di]
    sub  ax, RES_Y1[di]
    add  ax, 2
    mov  BOXH, ax

    ; Calculate pitch: P = BOXH / 7 (clamped to 3..8)
    mov  ax, BOXH
    xor  dx, dx
    mov  bx, 7
    div  bx                    ; AX = BOXH / 7
    cmp  ax, 3
    jge  srip_pmin
    mov  ax, 3
srip_pmin:
    cmp  ax, 8
    jle  srip_pmax
    mov  ax, 8
srip_pmax:
    mov  GPITCH, ax
    dec  ax
    dec  ax
    mov  GDOTSZ, ax            ; GDOTSZ = GPITCH - 2

    ; Compute CX = (X1 + X2) / 2
    mov  ax, RES_X1[di]
    add  ax, RES_X2[di]
    shr  ax, 1                 ; AX = CX

    ; Compute (5 * GPITCH) / 2
    push ax
    mov  ax, GPITCH
    mov  bx, 5
    mul  bx
    shr  ax, 1
    mov  cx, ax                ; CX = (5 * GPITCH) / 2
    pop  ax
    sub  ax, cx                ; AX = CX - (5 * GPITCH) / 2
    mov  GLX, ax

    ; Bound GLX within screen
    cmp  GLX, 0
    jge  srip_glx_ge0
    mov  GLX, 0
srip_glx_ge0:
    mov  ax, GPITCH
    mov  bx, 5
    mul  bx                    ; AX = 5 * GPITCH
    mov  bx, 638
    sub  bx, ax
    cmp  GLX, bx
    jbe  srip_glx_ok
    mov  GLX, bx
srip_glx_ok:

    ; Compute CY = (Y1 + Y2) / 2
    mov  ax, RES_Y1[di]
    add  ax, RES_Y2[di]
    shr  ax, 1                 ; AX = CY

    ; Compute (7 * GPITCH) / 2
    push ax
    mov  ax, GPITCH
    mov  bx, 7
    mul  bx
    shr  ax, 1
    mov  cx, ax                ; CX = (7 * GPITCH) / 2
    pop  ax
    sub  ax, cx                ; AX = CY - (7 * GPITCH) / 2
    mov  GLY, ax

    ; Bound GLY within canvas
    cmp  GLY, 0
    jge  srip_gly_ge0
    mov  GLY, 0
srip_gly_ge0:
    mov  ax, GPITCH
    mov  bx, 7
    mul  bx                    ; AX = 7 * GPITCH
    mov  bx, CANVAS_BOTTOM
    sub  bx, ax
    cmp  GLY, bx
    jbe  srip_gly_ok
    mov  GLY, bx
srip_gly_ok:

    ; Draw the digitized glyph in its place (light green)
    mov  bx, si
    xor  ax, ax
    mov  al, RESIDX[bx]
    call DrawGlyph

    inc  si
    jmp  srip_loop

srip_bottom:
    ; Clear bottom text area (left of buttons)
    mov  RX1, 0
    mov  RY1, CANVAS_BOTTOM + 4
    mov  RX2, 290
    mov  RY2, 479
    mov  RCOL, 0
    call FillRect

    call DrawExitBtn

    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
ShowResultInPlace endp

; ------------------------------------------------------------
; DrawGlyph : AX = canonical index (0..35 for letters/digits,
;             36 for '?'). Draws 5x7 dot-matrix character at
;             (GLX, GLY) with GPITCH and GDOTSZ.
; ------------------------------------------------------------
DrawGlyph proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov  bx, 7
    mul  bx                    ; AX = index * 7
    mov  si, offset TEMPL
    add  si, ax

    mov  GROW, 0
dg_row:
    mov  bx, GROW
    mov  al, [si+bx]
    mov  GBITS, al
    mov  GCOL, 0
dg_col:
    mov  cx, 4
    sub  cx, GCOL
    mov  al, GBITS
    shr  al, cl
    test al, 1
    jz   dg_next

    mov  ax, GCOL
    mov  bx, GPITCH
    mul  bx
    add  ax, GLX
    mov  RX1, ax
    mov  bx, GDOTSZ
    add  ax, bx
    mov  RX2, ax

    mov  ax, GROW
    mov  bx, GPITCH
    mul  bx
    add  ax, GLY
    mov  RY1, ax
    mov  bx, GDOTSZ
    add  ax, bx
    mov  RY2, ax

    mov  RCOL, 10              ; light green
    call FillRect
dg_next:
    inc  GCOL
    cmp  GCOL, 5
    jb   dg_col
    inc  GROW
    cmp  GROW, 7
    jb   dg_row

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
DrawGlyph endp

end main
