org 0x100
cpu 8086

slop equ 76*4

  jmp loader

videoDisplayCombination:  ; Don't bother with subfunction 1
  mov al,0x1a   ; mode.com checks this to see if VGA services are available
  mov bl,8 ;VGA (2 for CGA card)
  iret

videoSubsystemConfiguration:  ; Don't actually need to do anything here
  mov al,12
  iret

characterGeneratorRoutine:
  push ds
  push ax
  xor ax,ax
  mov ds,ax
  pop ax
  push ax
  cmp al,0x30
  je .getInfo
  and al,0x0f
  cmp al,0x02
  je .eightLineFont
  mov byte[0x485],16
  jmp .done
.eightLineFont:
  mov byte[0x485],8
.done:
  pop ax

  push ax
  test al,0x10
  jz .noModeSet
  mov ah,0
  mov al,[0x449]       ; Current screen mode
  int 0x10
.noModeSet:
  pop ax

  pop ds
  iret
.getInfo:
  mov cl,byte[0x485]
  mov ch,0
  mov dl,byte[0x484]
  pop ax
  pop ds
  iret

setCursorType:
  push ds
  push ax
  xor ax,ax
  mov ds,ax

  mov [0x460],cx
  push dx
  mov dx,0x3d4
  mov al,0x0a
  mov ah,ch
  and ah,0x1e
  out dx,ax
  inc ax
  mov ah,cl
  and ah,0x1e
  out dx,ax
  pop dx

  pop ax
  pop ds
  iret

int10Routine:
  sti
  cmp ah,0
;  je setMode

   jne notSetMode
   jmp setMode
notSetMode:
  cmp ah,1
  je setCursorType

  cmp ah,0xe
;  je writeTTY

   jne notWriteTTY
   jmp writeTTY
notWriteTTY:

  cmp ah,0x10
;  jl oldInterrupt10
  jge notOldInterrupt10
  jmp oldInterrupt10
notOldInterrupt10:

%if 0
  push bx

  push ax
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax

  push ax
  shr al,1
  shr al,1
  shr al,1
  shr al,1
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax

  push ax
  mov al,ah
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax

  push ax
  mov al,ah
  shr al,1
  shr al,1
  shr al,1
  shr al,1
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax

  pop bx

  push bx
  push ax
  mov al,bl
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax
  pop bx

  push bx
  push ax
  mov al,bl
  shr al,1
  shr al,1
  shr al,1
  shr al,1
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax
  pop bx

  push bx
  push ax
  mov al,bh
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  pop ax
  pop bx

  push bx
  push ax
  mov al,bh
  shr al,1
  shr al,1
  shr al,1
  shr al,1
  and al,0x0f
  add al,'0'
  mov ah,0x0e
  mov bh,0
  int 0x10
  mov ah,0
  int 0x16
  pop ax
  pop bx
%endif

  cmp ah,0x11
;  je characterGeneratorRoutine
   jne notCharacterGeneratorRoutine
   jmp characterGeneratorRoutine
notCharacterGeneratorRoutine:

  cmp ah,0x12
;  je videoSubsystemConfiguration

   jne notVideoSubsystemConfiguration
   jmp videoSubsystemConfiguration
notVideoSubsystemConfiguration:

  cmp ah,0x1a
;  je videoDisplayCombination

   jne notVideoDisplayCombination
   jmp videoDisplayCombination
notVideoDisplayCombination:

  cmp ah,0x1b
  je videoBIOSFunctionalityAndStateInformation

oldInterrupt10:
  jmp far 0x9999:0x9999

videoBIOSFunctionalityAndStateInformation:
  mov ax,cs
  mov es,ax
  mov di,dynamicVideoStateTable+4
  push ds
  push si
  push cx
  xor ax,ax
  mov ds,ax
  mov cx,16
  mov si,0x449
  rep movsw
  mov ax,[0x485]
  mov [es:di+0x23],ax
  pop cx
  pop si
  pop ds
  mov di,dynamicVideoStateTable
  mov al,0x1b
  iret

setMode:
  push ds
  push ax
  call stopISAV
  pop ax
  push ax

  pushf
  call far [cs:oldInterrupt10+1]

  pop ax
  cmp al,4
  jge doneInt10  ; Don't start ISAV for graphics modes

  push ax
  xor ax,ax
  mov ds,ax
  cmp byte[0x485],16
  je lines25

  pop ax
  push ax
  test al,2
  jnz isav80
  mov ax,0x2d11
  jmp isavPatch
isav80:
  mov ax,0x5a21
isavPatch:
  mov [cs:isav1_patch+2],al
  mov [cs:isav2_patch+2],ah
  mov [cs:isav4_patch+2],al
  mov [cs:isav5_patch+2],ah

  call startISAV

.safeWaitLoop:
  cmp byte[cs:isavActive],0
  je .safeWaitLoop

;  push es
;  push di
;  push cx
;  ; Clear screen
;  mov ax,0xb800
;  mov es,ax
;  mov ax,0x100
;  xor di,di
;  mov cx,80*50
;loopTop:
;  stosw
;  inc ax
;  loop loopTop
;  pop cx
;  pop di
;  pop es
;
;  mov ah,0
;  int 0x16

  mov byte[0x484],49  ; Number of rows-1
  mov ax,0x2000

  test byte[0x449],2  ; Requested video mode
  jnz doneCols
  mov ax,0x1000
  jmp doneCols

lines25:
  mov byte[0x484],24  ; Number of lines-1
  mov ax,0x800

  test byte[0x449],2  ; Requested video mode
  jnz doneCols
  mov ax,0x1000
doneCols:
  mov word[0x44c],ax

  pop ax
doneInt10:
  pop ds
  iret


writeTTY:
  push ds
  push bx
  push cx
  push dx

        PUSH    AX                      ; SAVE REGISTERS
        PUSH    AX                      ; SAVE CHAR TO WRITE
  xor ax,ax
  mov ds,ax
        MOV     AH,3
        MOV     BH,[0x462]              ; GET THE CURRENT ACTIVE PAGE
        INT     10H                     ; READ THE CURRENT CURSOR POSITION
        POP     AX                      ; RECOVER CHAR

;----- DX NOW HAS THE CURRENT CURSOR POSITION

        CMP     AL,8                    ; IS IT A BACKSPACE ?
        JE      U8                      ;  BACK_SPACE
        CMP     AL,0DH                  ; IS IT A CARRIAGE RETURN ?
        JE      U9                      ; CAR_RET
        CMP     AL,0AH                  ; IS IT A LINE FEED ?
        JE      U10                     ; LINE_FEED
        CMP     AL,07H                  ; IS IT A BELL ?
        JE      U11                     ; BELL

;----- WRITE THE CHAR TO THE SCREEN

        MOV     AH,10                   ; WRITE CHAR ONLY
        MOV     CX,1                    ; ONLY ONE CHAR
        INT     10H                     ; WRITE THE CHAR

;----- POSITION THE CURSOR FOR THE NEXT CHAR

        INC     DL
        CMP     DL,[0x44a]              ; TEST FOR COLUMN OVERFLOW
        JNZ     U7                      ; SET_CURSOR
        MOV     DL,0                    ; COLUMN FOR CURSOR
        CMP     DH,[0x484]  ; rows-1
        JNZ     U6                      ; SET_CURSOR_INC

;----- SCROLL REQUIRED

U1:
        MOV     AH,2
        INT     10H                     ; SET THE CURSOR

;----- DETERMINE VALUE TO FILL WITH DURING SCROLL

        MOV     AL,[0x449]              ; GET THE CURRENT MODE
        CMP     AL,4
        JC      U2                      ; READ_CURSOR
        CMP     AL,7
        MOV     BH,0                    ; FILL WITH BACKGROUND
        JNE     U3                      ; SCROLL_UP
U2:                                     ; READ_CURSOR
        MOV     AH,8
        INT     10H                     ; READ CHAR/ATTR AT CURRENT CURSOR
        MOV     BH,AH                   ; STORE IN BH
U3:                                     ; SCROLL_UP
        MOV     AX,601H                 ; SCROLL ONE LINE
        SUB     CX,CX                   ; UPPER LEFT CORNER
        MOV     DH,[0x484]              ; LOWER RIGHT ROW
        MOV     DL,[0x44a]              ;LOWER RIGHT COLUMN
        DEC     DL
U4:                                     ; VIDEO_CALL_RETURN
        INT     10H                     ; SCROLL UP THE SCREEN
U5:                                     ; TTY_RETURN
        POP     AX                      ; RESTORE THE CHARACTER
        JMP     VIDEO_RETURN            ; RETURN TO CALLER
U6:                                     ; SET_CURSOR_INC
        INC     DH                      ; NEXT ROW
U7:                                     ; SET_CURSOR
        MOV     AH,2
        JMP     U4                      ; ESTABLISH THE NEW CURSOR

;----- BACK SPACE FOUND

U8:
        CMP     DL,0                    ; ALREADY AT END OF LINE ?
        JE      U7                      ; SET_CURSOR
        DEC     DL                      ; NO -- JUST MOVE IT BACK
        JMP     U7                      ; SET_CURSOR

;----- CARRIAGE RETURN FOUND

U9:
        MOV     DL,0                    ; MOVE TO FIRST COLUMN
        JMP     U7                      ; SET_CURSOR

;----- LINE FEED FOUND

U10:
        CMP     DH,[0x484]              ; BOTTOM OF SCREEN  ?
        JNE     U6                      ; NO, JUST SET THE CURSOR
        JMP     U1                      ; YES, SCROLL THE SCREEN

;------ BELL FOUND

U11:
        MOV     BL,2                    ; SET UP COUNT FOR BEEP
        CALL    BEEP                    ; SOUND THE POD BELL
        JMP     U5                      ; TTY_RETURN


BEEP:
        MOV     AL,10110110B            ; SEL TIM 2,LSB,MSB,BINARY
        OUT     0x43,AL              ; WRITE THE TIMER MODE REG
        MOV     AX,533H                 ; DIVISOR FOR 1000 HZ
        OUT     0x42,AL              ; WRITE TIMER 2 CNT - LSB
        MOV     AL,AH
        OUT     0x42,AL              ; WRITE TIMER 2 CNT - MSB
        IN      AL,0x61               ; GET CURRENT SETTING OF PORT
        MOV     AH,AL                   ; SAVE THAT SETTING
        OR      AL,03                   ; TURN SPEAKER ON
        OUT     0x61,AL
        SUB     CX,CX                   ; SET CNT TO WAIT 500 MS
G7:
        LOOP    G7                      ; DELAY BEFORE TURNING OFF
        DEC     BL                      ; DELAY CNT EXPIRED?
        JNZ     G7                      ; NO - CONTINUE BEEPING SPK
        MOV     AL,AH                   ; RECOVER VALUE OF PORT
        OUT     0x61,AL
        RET                             ; RETURN TO CALLER


VIDEO_RETURN:
  pop dx
  pop cx
  pop bx
  pop ds
  iret



; Want to override:
;   ah = 0  set mode
;     Check if VIDMAXROW > 24, if so use interlacing, otherwise defer to BIOS
;   ah=0x12, bl=0x10: get EGA info
;   r.x.ax = 0x1a00; /* get VGA display combination - VGA install check */  needs to return al=0x1a
;   r.x.ax = 0x1112; /* activate 8x8 default font */
;   r.x.ax = (lines == 16) ? 0x1114 : 0x1111; /* 8x16 and 8x14 font */
;   r.h.ah = 0x12; /* set resolution (with BL 0x30) */


%macro waitForVerticalSync 0
  %%waitForVerticalSync:
    in al,dx
    test al,8
    jz %%waitForVerticalSync
%endmacro

%macro waitForNoVerticalSync 0
  %%waitForNoVerticalSync:
    in al,dx
    test al,8
    jnz %%waitForNoVerticalSync
%endmacro


; ISAV code starts here.

startISAV:
  push ds

;  ; Mode                                                09
;  ;      1 +HRES                                         1
;  ;      2 +GRPH                                         0
;  ;      4 +BW                                           0
;  ;      8 +VIDEO ENABLE                                 8
;  ;   0x10 +1BPP                                         0
;  ;   0x20 +ENABLE BLINK                                 0
;  mov dx,0x3d8
;  mov al,0x09
;  out dx,al
;
;  ; Palette                                             00
;  ;      1 +OVERSCAN B                                   0
;  ;      2 +OVERSCAN G                                   2
;  ;      4 +OVERSCAN R                                   4
;  ;      8 +OVERSCAN I                                   0
;  ;   0x10 +BACKGROUND I                                 0
;  ;   0x20 +COLOR SEL                                    0
;  inc dx
;  mov al,0
;  out dx,al

  mov dx,0x3d4

;  ;   0xff Horizontal Total                             71
;  mov ax,0x7100
;  out dx,ax
;
;  ;   0xff Horizontal Displayed                         50
;  mov ax,0x5001
;  out dx,ax
;
;  ;   0xff Horizontal Sync Position                     5a
;  mov ax,0x5a02
;  out dx,ax
;
;  ;   0x0f Horizontal Sync Width                        0a
;  mov ax,0x0f03 ;0x0a03
;  out dx,ax

  ;   0x7f Vertical Total                               01  vertical total = 2 rows
  mov ax,0x0104
  out dx,ax

  ;   0x1f Vertical Total Adjust                        00  vertical total adjust = 0
  mov ax,0x0005
  out dx,ax

  ;   0x7f Vertical Displayed                           01  vertical displayed = 1
  mov ax,0x0106
  out dx,ax

  ;   0x7f Vertical Sync Position                       1c  vertical sync position = 28 rows
  mov ax,0x1c07
  out dx,ax

  ;   0x03 Interlace Mode                               00   0 = non interlaced, 1 = interlace sync, 3 = interlace sync and video
  mov ax,0x0008
  out dx,ax

  ;   0x1f Max Scan Line Address                        00  scanlines per row = 1
  mov ax,0x0009
  out dx,ax

  ; Cursor Start                                        06
  ;   0x1f Cursor Start                                  6
  ;   0x60 Cursor Mode                                   0
;  mov ax,0x060a
  mov al,0x0a
  mov ah,[0x461]
;  dec ah
;  or ah,1
  and ah,0x1e
  out dx,ax

  ;   0x1f Cursor End                                   08
;  mov ax,0x080b
  mov al,0x0b
  mov ah,[0x460]
;  or ah,1
  and ah,0x1e
  out dx,ax

  ;   0x3f Start Address (H)                            00
  mov ax,0x000c
  out dx,ax

  ;   0xff Start Address (L)                            00
  mov ax,0x000d
  out dx,ax

  ;   0x3f Cursor (H)                                   03
  mov ax,0x030e
  out dx,ax

  ;   0xff Cursor (L)                                   c0
  mov ax,0xc00f
  out dx,ax

  mov dl,0xda
  cli

  mov al,0x34
  out 0x43,al
  mov al,0
  out 0x40,al
  out 0x40,al

  mov al,76*2 + 1
  out 0x40,al
  mov al,0
  out 0x40,al

;  xor ax,ax
;  mov ds,ax
  mov ax,[0x20]
  mov [cs:originalInterrupt8],ax
  mov ax,[0x22]
  mov [cs:originalInterrupt8+2],ax
  mov word[0x20],int8_oe0
  mov [0x22],cs

  in al,0x21
  mov [cs:originalIMR],al
  mov al,0xfe
  out 0x21,al

  sti
setupLoop:
  hlt
  jmp setupLoop


originalInterrupt8:
  dw 0, 0
originalIMR:
  db 0
timerCount:
  dw 0
isavActive:
  db 0


  ; Step 0 - don't do anything (we've just completed wait for CRTC stabilization)
int8_oe0:
  mov word[0x20],int8_oe1

  mov al,0x20
  out 0x20,al
  iret


  ; Step 1, wait until display is disabled, then change interrupts
int8_oe1:
  in al,dx
  test al,1
  jz .noInterruptChange   ; jump if not -DISPEN, finish if -DISPEN

  mov word[0x20],int8_oe2

.noInterruptChange:

  mov al,0x20
  out 0x20,al
  iret


  ; Step 2, wait until display is enabled - then we'll be at the start of the active area
int8_oe2:
  in al,dx
  test al,1
  jnz .noInterruptChange  ; jump if -DISPEN, finish if +DISPEN

  mov word[0x20],int8_oe3
  mov cx,2

.noInterruptChange:

  mov al,0x20
  out 0x20,al
  iret


  ; Step 3 - this interrupt occurs one timer cycle into the active area.
  ; The pattern of scanlines on the screen is +-+-- As the interrupt runs every other scanline, the pattern of scanlines in terms of what is seen from the interrupt is ++---.
int8_oe3:
  mov dl,0xd4
  mov ax,0x0308  ; Set interlace mode to ISAV
  out dx,ax
  mov dl,0xda

  loop .noInterruptChange
  mov word[0x20],int8_oe4
.noInterruptChange:

  mov al,76*2
  out 0x40,al
  mov al,0
  out 0x40,al

  mov al,0x20
  out 0x20,al
  iret


  ; Step 4 - this interrupt occurs two timer cycles into the active area.
int8_oe4:
  in al,dx
  test al,1
  jnz .noInterruptChange  ; jump if -DISPEN, finish if +DISPEN

  mov word[0x20],int8_oe5

.noInterruptChange:

  mov al,0x20
  out 0x20,al
  iret


  ; Step 5
int8_oe5:
  in al,dx
  test al,1
  jz .noInterruptChange   ; jump if not -DISPEN, finish if -DISPEN (i.e. scanline 4)

  mov word[0x20],int8_oe6

  mov al,76*2 - 3
  out 0x40,al
  mov al,0
  out 0x40,al

.noInterruptChange:

  mov al,0x20
  out 0x20,al
  iret


  ; Step 6. This occurs on scanline 1. The next interrupt will be on scanline 3.
int8_oe6:
  mov word[0x20],int8_oe7

  mov al,76*2
  out 0x40,al
  mov al,0
  out 0x40,al

  mov al,0x20
  out 0x20,al
  iret


  ; Step 7. This occurs on scanline 3 (one timer cycle before the active area starts). The next interrupt will be on scanline 0.
int8_oe7:
  mov word[0x20],int8_oe8

  mov al,0x20
  out 0x20,al
  iret


  ; Step 8 - scanline 0, next interrupt on scanline 2
int8_oe8:
  mov al,(20*76) & 0xff
  out 0x40,al
  mov al,(20*76) >> 8
  out 0x40,al

  mov word[0x20],int8_oe9

  mov dl,0xd4

  mov al,0x20
  out 0x20,al
  add sp,6
  sti
  pop ds
  ret


  ; Step 9 - initial short (odd) field
int8_oe9:
  push ax
  push dx
  mov dx,0x3d4
  mov ax,0x0309    ; Scanlines per row = 4  (2 on each field)
  out dx,ax
  mov ax,0x0106    ; Vertical displayed = 1 row (actually 2)
  out dx,ax
  mov ax,0x0304    ; Vertical total = 4 rows
  out dx,ax
  mov ax,0x0305    ; Vertical total adjust = 3
  out dx,ax

  pop dx

  mov al,(223*76 - 20) & 0xff
  out 0x40,al
  mov al,(223*76 - 20) >> 8
  out 0x40,al

  mov al,[cs:originalIMR]
  out 0x21,al

  push ds
  xor ax,ax
  mov ds,ax
  mov word[0x20],int8_oe10
  pop ds

  mov al,0x20
  out 0x20,al
  pop ax
  iret


  ; Step 10 - set up CRTC registers for full screen - scanline 0
int8_oe10:
  push ax
  push dx
  mov dx,0x3d4
  mov ax,0x0709  ; Scanlines per row = 8 (4 on each field)
  out dx,ax
  mov ax,0x1906  ; Vertical displayed = 25 rows (actually 50)
  out dx,ax
  mov ax,0x1f04  ; Vertical total = 32 rows (actually 64)
  out dx,ax
  mov ax,0x0605  ; Vertical total adjust = 6
  out dx,ax

  pop dx

  mov al,(76) & 0xff
  out 0x40,al
  mov al,(76) >> 8
  out 0x40,al

  push ds
  xor ax,ax
  mov ds,ax
  mov word[0x20],int8_isav0
  pop ds

  mov byte[cs:isavActive],1

  mov al,0x20
  out 0x20,al
  pop ax
  iret


  ; Final 0 - scanline 224
int8_isav0:
  push ax
  push dx
  mov dx,0x3d4

  mov al,0xfe
  out 0x21,al

  mov al,(76) & 0xff
  out 0x40,al
  mov al,(76) >> 8
  out 0x40,al

  push ds
  xor ax,ax
  mov ds,ax
  mov word[0x20],int8_isav1

  mov al,0x20
  out 0x20,al
  sti
  hlt


  ; Final 1 - scanline 225
int8_isav1:
isav1_patch:
  mov ax,0x2102  ; Horizontal sync position early
  out dx,ax

  mov word[0x20],int8_isav2

  mov al,0x20
  out 0x20,al
  sti
  hlt


  ; Final 2 - scanline 226
int8_isav2:
isav2_patch:
  mov ax,0x5a02  ; Horizontal sync position normal
  out dx,ax

  mov word[0x20],int8_isav3

  mov al,0x20
  out 0x20,al
  sti
  hlt


  ; Final 3 - scanline 227
int8_isav3:
  mov word[0x20],int8_isav4

  mov al,0x20
  out 0x20,al
  sti
  hlt


  ; Final 4 - scanline 228
int8_isav4:
isav4_patch:
  mov ax,0x2102  ; Horizontal sync position early
  out dx,ax

  mov al,(521*76 - slop) & 0xff
  out 0x40,al
  mov al,(521*76 - slop) >> 8
  out 0x40,al

  mov word[0x20],int8_isav5

  mov al,0x20
  out 0x20,al
  sti
  hlt


  ; Final 5 - scanline 229
int8_isav5:
  add sp,5*6  ; 6 bytes for each of isav1-isav5. isav0 will be undone with iret
isav5_patch:
  mov ax,0x5a02  ; Horizontal sync position normal
  out dx,ax

  mov al,(slop) & 0xff
  out 0x40,al
  mov al,(slop) >> 8
  out 0x40,al

  mov word[0x20],int8_isav0
  pop ds
  pop dx

  mov al,[cs:originalIMR]
  out 0x21,al

  add word[cs:timerCount],76*525
  jnc doneInterrupt8
  pop ax
  jmp far [cs:originalInterrupt8]

doneInterrupt8:
  mov al,0x20
  out 0x20,al
  pop ax
  iret


; Returns the CGA to normal mode
stopISAV:
  cmp byte[cs:isavActive],0
  je .done

  cli
  xor ax,ax
  mov ds,ax
  mov ax,[cs:originalInterrupt8]
  mov [8*4],ax
  mov ax,[cs:originalInterrupt8+2]
  mov [8*4+2],ax
  mov al,0x34
  out 0x43,al
  mov al,0
  out 0x40,al
  out 0x40,al
  sti
  mov byte[cs:isavActive],0

  ; Set the CGA back to a normal mode so we don't risk breaking anything
.done:
  ret


dynamicVideoStateTable:
  dw staticFunctionalityTable
  dw 0  ; Segment of static functionality table - filled in by loader
  db 0  ; Video mode                         - filled in by int 10,1b
  dw 0  ; Number of columns                  - filled in by int 10,1b
  dw 0  ; length of displayed video buffer   - filled in by int 10,1b
  dw 0  ; start address of upper left corner of video buffer - filled in by int 10,1b
  dw 0,0,0,0,0,0,0,0 ; curosr position table - filled in by int 10,1b
  db 0  ; cursor end line                    - filled in by int 10,1b
  db 0  ; cursor start line                  - filled in by int 10,1b
  db 0  ; active video page                  - filled in by int 10,1b
  dw 0x3d4  ; IO port for CRTC address register
  db 0  ; current value for mode register    - filled in by int 10,1b
  db 0  ; current value for palette register - filled in by int 10,1b
  dw 0  ; height of character matrix         - filled in by int 10,1b
  db 8  ; active display combination code (pretend to be VGA)
  db 0  ; inactive display combination code (none)
  dw 16 ; number of displayed colours
  db 8  ; number of supported video pages
  db 2  ; raster scan lines = 400
  db 0  ; text character table used
  db 0  ; text character table used
  db 0xe0  ; state information byte
  db 0,0,0 ; reserved
  db 0  ; video RAM available (actually only 16kB but 64kB is the lowest that this table supports)
  db 0xc0  ; save area status
  dw 0,0 ; reserved
staticFunctionalityTable:
  db 0x7f  ; modes 0-6 supported, mode 7 not supported
  db 0     ; modes 8-0x0f not supported
  db 0     ; modes 0x10-0x13 not supported
  dw 0,0   ; reserved
  db 0xfc  ; 400 lines
  db 1     ; max number of displayable text character sets
  db 1     ; # of text definition tables in char generator RAM
  db 0     ; other capability flags
  db 5     ; other capability flags (light pen supported, blinking/background intensity supported)
  dw 0     ; reserved
  db 0     ; save area capabilities
  db 0     ; reserved


  ; Non-resident portion
loader:
  mov [dynamicVideoStateTable+2],cs


  xor ax,ax
  mov ds,ax
  push ds

%macro setResidentInterrupt 2
  mov word [%1*4], %2
  mov [%1*4 + 2], cs
%endmacro

  cli

  mov ax,[0x10*4]
  mov cx,[0x10*4 + 2]

  mov [cs:oldInterrupt10+1],ax
  mov [cs:oldInterrupt10+3],cx

  setResidentInterrupt 0x10, int10Routine

  sti


  mov ah,0
  mov al,[0x449]       ; Current screen mode
  mov byte[0x485],8    ; Request 50 line mode
  mov byte[0x489],0x11 ; Set flags to say VGA available
  mov byte[0x48a],0x0b  ; DCC for VGA
  int 0x10             ; Start ISAV

  pop ds

  mov dx,(loader + 15) >> 4
  mov ax,0x3100
  int 0x21             ; Go resident

