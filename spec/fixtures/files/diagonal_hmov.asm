;
; diagonal.asm
;
; A test program that does a continous HMOV which results in a
; diagonal (for ruby2600 tests)
; This is free source code (see below). Build it with DASM
; (http://dasm-dillon.sourceforge.net/), by running:
;
;   dasm diagonal.asm -diagonal.bin -f3
;

    PROCESSOR 6502
    INCLUDE "vcs.h"

    ORG $F000

Initialize:             ; Cleanup from macro.h (by Andrew Davie/DASM)
    sei
    cld
    ldx #0
    txa
    tay
CleanStack:
    dex
    txs
    pha
    bne CleanStack

InitialValues:
    lda #$02
    sta ENABL
    lda #$F0
    sta HMBL
    lda #$FF
    sta COLUPF
    lda #$30
    sta CTRLPF

StartFrame:
    lda #%00000010
    sta VSYNC
    REPEAT 3
        sta WSYNC
    REPEND
    lda #0
    sta VSYNC

VBlank:
    sta WSYNC
    REPEAT 35
        nop
    REPEND
    sta RESBL
    sta WSYNC      ; First line positioned the ball
    REPEAT 36
        sta WSYNC
    REPEND
    ldx #0         ; scanline counter
    stx VBLANK

Scanline:
    sta HMOVE
    sta WSYNC
    inx
    cpx #191
    bne Scanline

Overscan:
    lda #%01000010
    sta VBLANK      ;
    REPEAT 30
        sta WSYNC
    REPEND
    jmp StartFrame


    ORG $FFFA

    .WORD Initialize
    .WORD Initialize
    .WORD Initialize

    END

;
; Copyright 2011-2013 Carlos Duarte do Nascimento (Chester). All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are
; permitted provided that the following conditions are met:
;
;    1. Redistributions of source code must retain the above copyright notice, this list of
;       conditions and the following disclaimer.
;
;    2. Redistributions in binary form must reproduce the above copyright notice, this list
;       of conditions and the following disclaimer in the documentation and/or other materials
;       provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY CHESTER ''AS IS'' AND ANY EXPRESS OR IMPLIED
; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
; FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES;  LOSS OF USE, DATA, OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
; ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; The views and conclusions contained in the software and documentation are those of the
; authors and should not be interpreted as representing official policies, either expressed
; or implied, of Chester.
;

