  %include "../defaults_bin.asm"

FASTSAMPLING EQU 0     ; Set to one to sample at 14.318MHz. Default is 4.77MHz.
LENGTH       EQU 2048  ; Number of samples to capture.
REFRESH      EQU 0;19   ; Refresh period in cycles, or 0 to disable

  cli
  mov ax,cs
  mov ss,ax
  mov sp,0xfffe

%macro outputByte 0
%rep 8
  rcr dx,1
  sbb bx,bx
  mov bl,[cs:lut+1+bx]
  mov bh,0
  mov ax,[bx]
  times 10 nop
%endrep
%endmacro

;%macro outputbit 2
;  test %1, %2
;  jnz %%notZero
;  mov ax,[8]
;  jmp %%done
;%%notZero:
;  mov ax,[0x88]
;  jmp %%done
;%%done:
;  times 10 nop
;%endmacro

  mov cx,-1
flushLoop:
  loop flushLoop

  outputCharacter 6

waitAckLoop:
  mov al,0x0a  ; OCW3 - no bit 5 action, no poll command issued, act on bit 0,
  out 0x20,al  ;  read Interrupt Request Register
waitKeyboardLoop:
  ; Loop until the IRR bit 1 (IRQ 1) is high
  in al,0x20
  and al,2
  jz waitKeyboardLoop
  ; Read the keyboard byte and store it
  in al,0x60
  mov bl,al
  ; Acknowledge the previous byte
  in al,0x61
  or al,0x80
  out 0x61,al
  and al,0x7f
  out 0x61,al
  cmp bl,'K'
  jne waitAckLoop


%if FASTSAMPLING != 0
  mov cx,48
%else
  mov cx,16
%endif
loopTop:
  mov [cs:savedCX],cx
;  lockstep

;  sti
;  outputCharacter 'A'

  safeRefreshOff
  writePIT16 0, 2, 2
  writePIT16 0, 2, 100
  mov word[8*4],irq0
  mov [8*4+2],cs
  sti
  hlt
  hlt
  writePIT16 0, 2, 0

;  mov ax,0xb800
;  mov ds,ax
;  mov ax,[0]
;   lockstep 1

  mov ax,0x8000
  mov ds,ax
  mov ax,[0]      ; Trigger: Start of command load sequence
  times 10 nop
%if FASTSAMPLING != 0
  mov dl,48
%else
  mov dl,16
%endif
  mov cx,[cs:savedCX]
  sub dl,cl

  outputByte
  mov dx,LENGTH
  dec dx
  outputByte
  outputByte
  mov dx,18996; + 492*3   ;65534 ;
  outputByte
  outputByte

  mov al,0
  out 0x0c,al  ; Clear first/last flip-flop
  out 0x00,al  ; Output DMA offset low
  out 0x00,al  ; Output DMA offset high

  cli
  cld
  xor ax,ax
  mov ds,ax
  mov si,0x5555

  ; Delay for enough time to refresh 512 columns
  mov cx,256

  ; Increase refresh frequency to ensure all DRAM is refreshed before turning
  ; off refresh.
  mov al,TIMER1 | LSB | MODE2 | BINARY
  out 0x43,al
  mov al,2
  out 0x41,al  ; Timer 1 rate

  rep lodsw
 ; refreshOn
  mov al,TIMER1 | LSB | MODE2 | BINARY
  out 0x43,al
  mov al,REFRESH
  out 0x41,al  ; Timer 1 rate

  call testRoutine

  ; Delay for enough time to refresh 512 columns
  mov cx,256

  ; Increase refresh frequency to ensure all DRAM is refreshed before turning
  ; off refresh.
  mov al,TIMER1 | LSB | MODE2 | BINARY
  out 0x43,al
  mov al,2
  out 0x41,al  ; Timer 1 rate

  rep lodsw
  refreshOn

;  mov cx,3
;flushLoop3:
;  push cx
  mov cx,25*LENGTH
flushLoop2:
  loop flushLoop2
;  pop cx
;  loop flushLoop3

  mov cx,[cs:savedCX]
  loop loopTop2

  sti
  outputCharacter 7

  complete
loopTop2:
  jmp loopTop

irq0:
  push ax
  mov al,0x20
  out 0x20,al
  pop ax
  iret

savedCX: dw 0
lut: db 0x88,8



testRoutine:
;  mov cx,2246
;  mov cx,4492
;  mov cx,8984
;  mov cx,17968
;  mov cx,35936


  mov al,TIMER1 | BOTH | MODE2 | BINARY
  out 0x43,al
  mov al,0
  out 0x41,al
  mov al,18
  out 0x41,al

  out 0x0c,al  ; clear byte pointer flip/flop
  mov al,0xff
  out 0x01,al  ;
  mov al,0
  out 0x01,al  ; Set count to 256

;
  mov al,0x00  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active high, DACK sense active low
  out 0x08,al  ; DMA command write
  mov al,0x98  ; channel 0, read, autoinit, increment, block
  out 0x0b,al  ; DMA mode write


  ; The following code will crash the machine unless refresh worked
  mov cx,65535
.loop:
  xchg ax,cx
  mov cx,1;8
.loop2:
  loop .loop2
  xchg ax,cx
  loop .loop


  mov al,0x00  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active high, DACK sense active low
  out 0x08,al  ; DMA command write
  mov al,0x58  ; channel 0, read, autoinit, increment, single
  out 0x0b,al  ; DMA mode write
  mov al,TIMER1 | BOTH | MODE2 | BINARY
  out 0x43,al
  mov al,18
  out 0x41,al
  mov al,0
  out 0x41,al
  out 0x0c,al  ; clear byte pointer flip/flop
  mov al,0xff
  out 0x01,al  ;
  out 0x01,al  ; Set count to 65536



; 304 cycles, 15 + 50 - 4 = 61 cycles for refresh
%if 0
  mov dx,0x3d9
  mov al,TIMER1 | LSB | MODE2 | BINARY
  out 0x43,al
  mov al,76
  out 0x41,al
  out 0x0c,al  ; clear byte pointer flip/flop
  mov al,3
  out 0x01,al  ;
  mov al,0
  out 0x01,al  ; Set count to 4

  mov al,0x00  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active high, DACK sense active low
  out 0x08,al  ; DMA command write
  mov al,0x98  ; channel 0, read, autoinit, increment, block
  out 0x0b,al  ; DMA mode write

  %assign i 0
  %rep 7
    %rep 16
      nop
      out dx,al
    %endrep
    mov al,i
    out 0x00,al
    mov al,(i >> 8)
    out 0x00,al
    %assign i i+4
    nop
  %endrep

  mov al,0x00  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active high, DACK sense active low
  out 0x08,al  ; DMA command write
  mov al,0x58  ; channel 0, read, autoinit, increment, single mode
  out 0x0b,al  ; DMA mode write
%endif


; ~312 cycles, 72 for refresh
%if 0
  mov dx,0x3d9
  mov al,TIMER1 | LSB | MODE2 | BINARY
  out 0x43,al
  mov al,3
  out 0x41,al
;  mov al,64
;  out 0x41,al
  mov al,1
  out 0x0a,al

  %rep 7
    %rep 16
      nop
      out dx,al
    %endrep
;    mov al,3
;    out 0x41,al
;    times 3 nop
;    mov al,64
;    out 0x41,al
    mov al,0
    out 0x0a,al
    nop
    mov al,4
    out 0x0a,al
  %endrep

  mov al,0
  out 0x0a,al
%endif

;  mov al,TIMER1 | LSB | MODE0 | BINARY
;  out 0x43,al
;  mov al,72
;  out 0x41,al
;  mov al,0x40  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active low, DACK sense active low
;  out 0x08,al  ; DMA command write
;  mov al,0x58  ; channel 0, read, autoinit, increment, single ;demand mode
;  out 0x0b,al  ; DMA mode write
;
;  %rep 7
;    %rep 20
;      nop
;      out dx,al     ; Pixel is 15 cycles == 45 hdots,
;    %endrep
;    mov al,8
;    out 0x41,al
;  %endrep
;
;  mov al,0x00  ; Memory-to-memory disable, Channel 0 address hold disable, controller enable, normal timing, fixed priority, late write selection, DREQ sense active high, DACK sense active low
;  out 0x08,al  ; DMA command write
;  mov al,0x58  ; channel 0, read, autoinit, increment, single mode
;  out 0x0b,al  ; DMA mode write

  ret


  rep
  repne
  jmp $+2
;  db 0,0
  ret


;  mov ax,98
;  mov bl,204
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2
;
;  mov ax,99
;  mov bl,204
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2
;
;  mov ax,9453
;  mov bl,155
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2
;
;  mov ax,9454
;  mov bl,155
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2
;
;  mov ax,5726
;  mov bl,153
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2
;
;  mov ax,5727
;  mov bl,153
;  mov cl,16
;  shr cl,cl
;  div bl
;  jmp $+2

  mov ax,9468
  mov bl,155
  mov cl,16
  shr cl,cl
  div bl
  jmp $+2

  mov ax,9469
  mov bl,155
  mov cl,16
  shr cl,cl
  div bl
  jmp $+2

  mov ax,9455
  mov bl,155
  mov cl,16
  shr cl,cl
  div bl
  jmp $+2

  mov ax,9456
  mov bl,155
  mov cl,16
  shr cl,cl
  div bl
  jmp $+2

  ret


  xor bx,bx
  mov ds,bx
  mov word[bx],div0
  mov [bx+2],cs

  mov ax,0
  mov dl,0

  mov cl,16
  shr cl,cl

  idiv dl
;div0:
  jmp $+2

;  mov word[bx],div0a

  mov ax,0
  mov dl,1

  mov cl,16
  shr cl,cl

  idiv dl
;div0a:
  jmp $+2

;  mov word[bx],div0b

  mov ax,128
  mov dl,1

  mov cl,16
  shr cl,cl

  idiv dl
;div0b:
  jmp $+2


;  add sp,12
  ret

div0:
  iret



    mov al,0x80
    out 0x43,al
    in al,0x42
    mov bl,al
    in al,0x42
    mov bh,al

    mov al,0x80
    out 0x43,al
    in al,0x42
    mov cl,al
    in al,0x42
    mov ch,al

    mov al,0x80
    out 0x43,al
    in al,0x42
    mov bl,al
    in al,0x42
    mov dh,al

    mov al,0x80
    out 0x43,al
    in al,0x42
    mov ah,al
    in al,0x42
    xchg ah,al

  ret



  mov [cs:savedSP],sp

  mov ax,0xaa
  mov cl,0; 0xff
  db 0xd3, 0xf0
  push ax
  pop ax
  ret



;  mov al,TIMER1 | LSB | MODE2 | BINARY
;  out 0x43,al
;  mov al,REFRESH
;  out 0x41,al  ; Timer 1 rate
;
;  xor ax,ax
;  mov ds,ax
;  mov word[0x20],irq0setup
;  writePIT16 0, 2, 2         ; Ensure we have a pending IRQ0
;  writePIT16 0, 2, 40
;  sti
;  hlt     ; Should never be hit
;irq0setup:
;  mov al,0x20
;  out 0x20,al
;  mov word[0x20],irq0test
;  sti
;  hlt
;
;irq0test:
  mov ax,0xb800
  mov ds,ax
  mov ax,cs
  mov ss,ax
  mov sp,1234
  mov dx,0x3d4
  mov bx,0x5001
  mov di,0x1900
  mov ax,0x5702
  mov si,12345
  mov bp,123
  mov es,ax

  ; Scanlines 0-199

%macro scanline 1
  mov al,0x00
  out dx,ax        ; e  Horizontal Total         left  0x5700  88
  mov ax,0x0202
  out dx,ax        ; f  Horizontal Sync Position right 0x0202   2

  pop cx
  mov al,0x0c
  mov ah,ch
  out dx,ax
  inc ax
  mov ah,cl
  out dx,ax

  lodsb
;  out 0xe0,al

  %if %1 == -1
    mov ax,0x0104
    out dx,ax      ;    Vertical Total
    times 3 nop
  %elif %1 == 198
    mov ax,0x3f04
    out dx,ax      ;    Vertical Total                 0x3f04  64  (1 for scanlines -1 and 198, 62 for scanlines 199-260)
    times 3 nop
  %else
    mov al,[bp+si]
    mov dl,0xd9
    out dx,al
    mov dl,0xd4
  %endif

  mov ax,0x0101
  out dx,ax        ; b  Horizontal Displayed     right 0x0101   1
  xchg ax,di
  out dx,ax        ; a  Horizontal Total         right 0x1900  26
  xchg ax,di
  xchg ax,bp
  out dx,ax        ; d  Horizontal Displayed     left  0x5001  80
  xchg ax,bp
  mov ax,es
  out dx,ax        ; c  Horizontal Sync Position left  0x5702  88
%endmacro
%assign i 0
;%rep 200
;  scanline i
;  %assign i i+1
;%endrep
  scanline -1
  scanline 0
  scanline 1
  scanline 2
  scanline 3
  scanline 198

  ; Scanline 199

  mov ax,0x7100
  out dx,ax        ; e  Horizontal Total         left  0x7100 114
  mov ax,0x5a02
  out dx,ax        ; f  Horizontal Sync Position right 0x5a02  90

  lodsb
  out 0xe0,al


  mov sp,[cs:savedSP]

;  xor ax,ax
;  mov ds,ax
;  mov word[0x20],irq0
;  writePIT16 0, 2, 0
;
;  mov al,0x20
;  out 0x20,al
;

  ret
savedSP:







  aaa
  aaa
  aaa
  aaa
  aaa
  aaa
  aaa
  aaa
  aaa
  aaa
  ret


  mov dx,0x3d9
%rep 10
  in al,dx
  test al,8
  jz $+2
%endrep
%rep 10
  in al,dx
  test al,8
  jnz $+2
%endrep



  mov di,data
  mov ax,cs
  mov es,ax
  mov dx,0x3da
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb
  in al,dx
  stosb

;  readPIT16 0
;  stosw
;  readPIT16 0
;  stosw
;  readPIT16 0
;  stosw
;  readPIT16 0
;  stosw
;  readPIT16 0
;  stosw
;  ret




data:
