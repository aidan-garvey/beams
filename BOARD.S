
; *****************************************************************
; BOARD.S
; Contains subroutines for manipulating on the game board.
;
; Copyright (C) 2022 Aidan Garvey - see MAIN.S for license details.
; *****************************************************************

; Format of each cell in the board:
; -NS- -CCC IIII IIII
; N: Junk & !N = gray junk, Junk & N = coloured junk,
;    !Junk & !N = empty cell, !Junk & N = block
; S: block is shattering junk, does not interact
; C: 3 bits for colour
; I: 0: not junk
;    1..255: 8-bit junk piece ID
;    

; ===============================================
; GENERATE_ROWS
; -----------------------------------------------
; Generate rows of blocks starting at the bottom
; of the board. The number of rows to generate is
; stored in memory at NEW_ROWS_1 / NEW_ROWS_2.
; After generation, the content of NEW_ROWS_X is
; set to 0.
; -----------------------------------------------
; Parameters:
;   a1 - points to board (P1 or P2)
;   a2 - points to NEW_ROWS (P1 or P2)
;   a4 - points to screen buffer
; Thrashed:
;   d0-d4
; ===============================================
GENERATE_ROWS:
    PUSH    a3

    MOVE.W  (a2), d2    ; d2 counts number of rows to generate
    MOVE.W  #0, (a2)    ; since we're generating the rows, clear NEW_ROWS
    MOVE.L  a2, a3      ; a3 points to the end of the board
    MOVE.W  #BOARD_HEIGHT, d4 ; d4 tracks y pos for PLACE_BLOCK subroutine
    BRA.B   @GEN_ROW_STEP
; generate a row of random blocks
@GEN_ROW_LOOP:
    MOVE.W  #BOARD_WIDTH-1, d3
@GEN_BLOCK_LOOP:
    ; use RNG to generate each block's colour
    JSR     RAND
    ; if current block is not empty, skip
    TST.W   -(a3)
    BNE.B   @GEN_BLOCK_STEP
; @GEN_BLOCK_PLACE:

    ; d0-d1 contain the random state
    ; use d0 for the block data
    BSET    #14, d0     ; set N
    ANDI.W  #$4700, d0  ; clear all except N and color
    MOVE.W  d0, (a3)

    JSR     PLACE_BLOCK
@GEN_BLOCK_STEP:
    DBRA    d3, @GEN_BLOCK_LOOP
@GEN_ROW_STEP:
    SUBQ    #1, d4
    DBRA    d2, @GEN_ROW_LOOP

    POP     a3
    RTS

; =========================================
; PLAYER_ACTIONS
; -----------------------------------------
; Handle the effects of the player's inputs
; -----------------------------------------
; Parameters:
;   a1 - start of the board
;   a2 - start of player game state
;   a3 - joypad inputs
;   a4 - start of screen buffer
; Thrashed:
;   a0, d0-d4
; =========================================
PLAYER_ACTIONS:
    PUSH    a5-a6

    MOVE.W  (a3), d0    ; current joypad inputs
    MOVE.W  4(a3), d1   ; previous frame's inputs
    ; to get buttons pressed this frame but not held:
    ; XOR new inputs into old inputs, then AND result with new inputs
    EOR.W   d0, d1
    AND.W   d0, d1  ; d1 indicates buttons pressed for the first frame

    ; horizontal movement
    BTST    #3, d1  ; right pressed
    BNE.B   @MOVE_RIGHT ; if pressed for the first frame, move
    BTST    #3, d0  ; right held
    BEQ.B   @SKIP_MOVE_RIGHT ; if not held either, skip moving
    SUB.W   #1, (JOY_H_TIMER_OFF, a2) ; JOY_H_TIMER countdown
    BNE.B   @SKIP_MOVE_RIGHT ; if hold timer not at 0, don't move
@MOVE_RIGHT:
    MOVE.W  #HOLD_LENGTH, (JOY_H_TIMER_OFF, a2) ; reset hold timer
    CMPI.W  #BOARD_WIDTH-1, (CURSOR_X_OFF, a2) ; CURSOR_X
    BEQ.B   @SKIP_MOVE_RIGHT ; skip if moving right would go out of bounds
    ADDI.W  #1, (CURSOR_X_OFF, a2)
@SKIP_MOVE_RIGHT:


    BTST    #2, d1  ; left
    BNE.B   @MOVE_LEFT ; if pressed for first frame, move
    BTST    #2, d0  ; left held
    BEQ.B   @SKIP_MOVE_LEFT ; if not held either, skip moving
    SUB.W   #1, (JOY_H_TIMER_OFF, a2) ; JOY_H_TIMER countdown
    BNE.B   @SKIP_MOVE_LEFT ; if hold timer not at 0, don't move
@MOVE_LEFT:
    MOVE.W  #HOLD_LENGTH, (JOY_H_TIMER_OFF, a2)
    TST.W   (CURSOR_X_OFF, a2)   ; CURSOR_X
    BEQ.B   @SKIP_MOVE_LEFT ; skip if moving left would go out of bounds
    SUBI.W  #1, (CURSOR_X_OFF, a2)
@SKIP_MOVE_LEFT:

    ; vertical movement
    BTST    #1, d1  ; down
    BNE.B   @MOVE_DOWN
    BTST    #1, d0  ; down held
    BEQ.B   @SKIP_MOVE_DOWN
    SUB.W   #1, (JOY_V_TIMER_OFF, a2) ; JOY_V_TIMER countdown
    BNE.B   @SKIP_MOVE_DOWN ; if hold timer not at 0, don't move
@MOVE_DOWN:
    MOVE.W  #HOLD_LENGTH, (JOY_V_TIMER_OFF, a2)
    CMPI.W  #BOARD_HEIGHT-1, (CURSOR_Y_OFF, a2) ; CURSOR_Y
    BEQ.B   @SKIP_MOVE_DOWN
    ADDI.W  #1, (CURSOR_Y_OFF, a2)
@SKIP_MOVE_DOWN:


    BTST    #0, d1  ; up
    BNE.B   @MOVE_UP
    BTST    #0, d0  ; up held
    BEQ.B   @SKIP_MOVE_UP
    SUB.W   #1, (JOY_V_TIMER_OFF, a2) ; JOY_V_TIMER countdown
    BNE.B   @SKIP_MOVE_UP ; if hold timer not at 0, don't move
@MOVE_UP:
    MOVE.W  #HOLD_LENGTH, (JOY_V_TIMER_OFF, a2)
    TST.W   (CURSOR_Y_OFF, a2)   ; CURSOR_Y
    BEQ.B   @SKIP_MOVE_UP
    SUBI.W  #1, (CURSOR_Y_OFF, a2)
@SKIP_MOVE_UP:

    ; d0 not needed for inputs from here on - only D-pad can be held

    ; if A pressed, swap horizontally
    BTST    #6, d1
    BEQ     @SKIP_A_PRESS

    ; get cursor pos, convert to RAM offset
    MOVE.W  (CURSOR_X_OFF, a2), d0 ; horizontal position
    ; if cursor is all the way to the right, the
    ; horizontal component is shifted to the left
    CMPI.W  #BOARD_WIDTH-1, d0
    BNE     @A_PRESS_NO_SUB
    SUBQ    #1, d0
@A_PRESS_NO_SUB:
    ; save x pos
    MOVE.W  d0, d3

    ; get vertical pos
    MOVE.W  (CURSOR_Y_OFF, a2), d2
    MOVE.W  d2, d4
    ; multiply it by row width
    MULU.W  #BOARD_WIDTH, d2
    ; calculate RAM offset
    ADD.W   d2, d0
    ASL.W   #1, d0
    MOVE.L  a1, a5
    ADDA.W  d0, a5
    ; a0 will check if the space below a block is empty
    MOVE.L  a5, a0
    ADDA.W  #BOARD_WIDTH*2, a0

    ; if a block is falling, and it is not empty, it is immovable

    ; don't do check for bottom row
    CMP.W   #BOARD_HEIGHT-1, d4
    BEQ     @H_FALL_CHECK_2

    TST.W   (a0)+
    BNE.B   @H_FALL_CHECK_1 ; if block below is occupied, check passes
    TST.W   (a5)
    BNE.B   @SKIP_A_PRESS ; if block below is empty and block above isn't, check fails
@H_FALL_CHECK_1:
    TST.W   (a0)+
    BNE.B   @H_FALL_CHECK_2
    TST.W   2(a5)
    BNE.B   @SKIP_A_PRESS
@H_FALL_CHECK_2:
    ; do not allow swap if either block is junk
    TST.B   1(a5)
    BNE.B   @SKIP_A_PRESS
    TST.B   3(a5)
    BNE.B   @SKIP_A_PRESS

    ; swap the blocks, unless they are both empty
    MOVE.L  (a5), d2
    BEQ.B   @SKIP_A_PRESS
    SWAP    d2
    MOVE.L  d2, (a5)
    JSR     SWAP_BLOCKS_H
    ; since player made a move, reset combo counter
    MOVE.W  #0, (COMBO_OFF, a2)

    ; check for matches at swapped blocks
    TST.W   (a5)
    BEQ     @SKIP_CHECK_A_1
    MOVE.L  a5, a0
    JSR     CHECK_MATCH
@SKIP_CHECK_A_1:
    MOVE.L  a5, a0
    ADDA.W  #2, a0
    TST.W   (a0)
    BEQ     @SKIP_CHECK_A_2
    ADDQ    #1, d3
    JSR     CHECK_MATCH
@SKIP_CHECK_A_2:
@SKIP_A_PRESS:

    ; if B pressed, swap veritcally
    BTST    #4, d1
    BEQ     @SKIP_B_PRESS

    ; get cursor pos, convert to RAM offset
    MOVE.W  (CURSOR_X_OFF, a2), d0 ; horizontal position
    MOVE.W  d0, d3
    ; get vertical pos
    MOVE.W  (CURSOR_Y_OFF, a2), d2
    ; if cursor is at top, move it down by 1
    BNE     @B_PRESS_NO_ADD
    ADDQ    #1, d2
@B_PRESS_NO_ADD:
    ; save vertical pos
    MOVE.W  d2, d4
    
    ; multiply by row width
    MULU.W  #BOARD_WIDTH, d2
    ; calculate RAM offset for top and bottom blocks
    ADD.W   d2, d0
    ASL.W   #1, d0
    MOVE.L  a1, a5
    ADDA.W  d0, a5
    MOVE.L  a5, a6
    SUBA.W  #BOARD_WIDTH*2, a6

    ; don't allow a vertical swap b/w a block and a space
    TST.W   (a5)
    BEQ.B   @SKIP_B_PRESS
    TST.W   (a6)
    BEQ.B   @SKIP_B_PRESS

    ; don't allow swapping junk
    TST.B   1(a5)
    BNE.B   @SKIP_B_PRESS
    TST.B   1(a6)
    BNE.B   @SKIP_B_PRESS

    ; swap the blocks
    MOVE.W  (a5), d2
    MOVE.W  (a6), (a5)
    MOVE.W  d2, (a6)
    JSR     SWAP_BLOCKS_V
    ; since player made a move, reset combo counter
    MOVE.W  #0, (COMBO_OFF, a2)

    ; check for matches at swapped blocks
    TST.W   (a5)
    BEQ.B   @SKIP_CHECK_B_1
    MOVE.L  a5, a0
    JSR     CHECK_MATCH
@SKIP_CHECK_B_1:
    TST.W   (a6)
    BEQ.B   @SKIP_CHECK_B_2
    MOVE.L  a6, a0
    SUBQ.W  #1, d4
    JSR     CHECK_MATCH
@SKIP_CHECK_B_2:
@SKIP_B_PRESS:

    POP     a5-a6
    RTS

; =====================================
; UPDATE_PHYSICS
; -------------------------------------
; For each block with empty space below
; it, make it fall due to gravity.
; -------------------------------------
; Paramaters:
;   a1 - points to game board
;   a2 - points to end of board
;   a4 - points to screen buffer
; Thrashed:
;   a0, d0-d1/d3-d4
; =====================================
UPDATE_PHYSICS:
    PUSH    a1

    ; a1 will point 1 row above a0
    MOVE.L  a2, a0
    MOVE.L  a2, a1
    SUBA.W  #BOARD_WIDTH*2, a1
    MOVEQ   #BOARD_WIDTH-1, d3
    MOVEQ   #BOARD_HEIGHT-1, d4

    ; we will iterate every row except the top
    ; MOVE.W  #BOARD_WIDTH*(BOARD_HEIGHT-1)-1, d0
@UPDATE_BLOCK_LOOP:
    SUBA.W  #2, a1
    SUBA.W  #2, a0

    ; if (a1) is junk, call subroutine to move it
    TST.B   1(a1)
    BEQ.B   @UPDATE_NOT_JUNK
    BTST.B  #SHATTER_FLAG_B, (a1)
    BNE.B   @UPDATE_BLOCK_STEP
    BSR     UPDATE_JUNK
    BRA.B   @UPDATE_BLOCK_STEP
@UPDATE_NOT_JUNK:
    TST.W   (a0)
    ; if (a0) not empty, (a1) can't move down
    BNE.B   @UPDATE_BLOCK_STEP

    ; move (a1) downwards
    MOVE.W  (a1), (a0)
    CLR.W   (a1)
    JSR     SWAP_BLOCKS_V

@UPDATE_BLOCK_STEP:
    SUBQ    #1, d3
    BGE.B   @UPDATE_BLOCK_LOOP
    MOVEQ   #BOARD_WIDTH-1, d3
    SUBQ    #1, d4
    BGT.B   @UPDATE_BLOCK_LOOP

    POP     a1
    RTS

; =======================================
; UPDATE_JUNK
; ---------------------------------------
; Update a row of junk blocks' physics
; ---------------------------------------
; Parameters:
;   a0 - the tile below a1
;   a1 - rightmost junk block in the row
;   d3 - x position of block (a0)
;   d4 - y position of block (a0)
; After execution:
;   a0 - the tile below a1
;   a1 - leftmost junk block in the row
;   d3 - x position of block (a0)
;   d4 - y position of block (a0)
; Thrashed:
;   none
; =======================================
UPDATE_JUNK:
    PUSH    d0-d2/d5

    MOVEQ   #0, d1      ; d1 will track the number of junk blocks
    MOVE.W  (a1), d2    ; d2 holds the first junk block
    TST.W   (a0)
    SEQ     d0          ; d0 will track if we can move the row down

@UPDATE_JUNK_LOOP:
    ; get next junk block
    SUBQ    #1, d3
    SUBA.W  #2, a0
    MOVE.W  -(a1), d5
    CMP.B   d5, d2
    ; if the IDs are not equal, break the loop
    BNE.B   @UPDATE_JUNK_BREAK

    ; check for empty tile below junk
    TST.W   (a0)
    BEQ.B   @UPDATE_STILL_VALID
    MOVEQ   #0, d0
@UPDATE_STILL_VALID:
    ADDQ    #1, d1
    BRA.B   @UPDATE_JUNK_LOOP

@UPDATE_JUNK_BREAK:
    ; our registers need to point to the last junk block,
    ; not the block to the left of it
    ADDA.W  #2, a0
    ADDA.W  #2, a1
    ADDQ    #1, d3

    ; if d0 is 0, we can't move the row down
    TST.W   d0
    BEQ.B   @UPDATE_JUNK_RET

    ; move the row down
    PUSH    a0-a1/d3

@JUNK_FALL_LOOP:
    MOVE.W  (a0), d0
    MOVE.W  (a1), (a0)+
    MOVE.W  d0, (a1)+
    JSR     SWAP_BLOCKS_V
    ADDQ    #1, d3
    ; d1 counted the number of junk blocks minus 1
    DBRA    d1, @JUNK_FALL_LOOP

    POP     a0-a1/d3

@UPDATE_JUNK_RET:
    POP     d0-d2/d5
    RTS

; ==================================
; CHECK_ALL_MATCHES
; ----------------------------------
; Check the entire board for matches
; ----------------------------------
; Parameters:
;   a1 - points to game board
;   a2 - player game state
; Thrashed:
;   a0, d0-d7
; ==================================
CHECK_ALL_MATCHES:
    MOVE.L  a2, a0
    MOVE.W  #BOARD_HEIGHT-1, d4 ; y pos
@CHECK_ROW_LOOP:
    MOVE.W  #BOARD_WIDTH-1, d3 ; x pos
@CHECK_CELL_LOOP:
    TST.W   -(a0)
    BEQ.B   @SKIP_CHECK_MATCH
    JSR     CHECK_MATCH
@SKIP_CHECK_MATCH:
    DBRA    d3, @CHECK_CELL_LOOP
    DBRA    d4, @CHECK_ROW_LOOP
    RTS

; =======================================
; PLACE_NEW_JUNK
; ---------------------------------------
; Place the piece of junk being displayed
; as the next piece in the UI. Then,
; generate the next piece that will drop.
; ---------------------------------------
; Parameters:
;   a1 - points to game board
;   a2 - points to game state
;   a4 - points to screen buffer
; Thrashed:
;   a0, d0-d7
; =======================================
PLACE_NEW_JUNK:
    PUSH    a3/a5
    
    TST.B   (NEXT_JUNKID_OFF, a2)
    BEQ     @SKIP_JUNK_SPAWN
    ; place junk at NEXT_JUNK_X
    MOVE.L  a1, a0
    MOVE.W  (NEXT_JUNK_X_OFF, a2), d0
    LSL.W   #1, d0
    ADDA.W  d0, a0 ; a0 points to top left of junk destination

    MOVE.W  (JUNK_PAT_OFF, a2), d0  ; d0 := index of junk piece data
    LSL.W   #4, d0  ; each piece is 16 bytes
    LEA.L   JUNK_PIECES, a3
    ADDA.W  d0, a3  ; a3 points to next junk piece
    MOVE.B  (a3)+, d6   ; d6 := width of piece
    MOVE.B  (a3)+, d7   ; d7 := height of piece
    EXT.W   d6
    EXT.W   d7
    SUBQ    #1, d6 ; width and height will
    SUBQ    #1, d7 ; be used as loop counters

    MOVEQ   #0, d4 ; d4 := y position of junk's top

    ; generate junk data for the board
    JSR     RAND
    ANDI.W  #$4700, d0
    MOVE.B  (NEXT_JUNKID_OFF, a2), d0 ; d0 := block data for board

@PLACE_JUNK_LOOP:
    MOVE.W  d6, d2 ; d2 := width-1
    MOVE.W  (NEXT_JUNK_X_OFF, a2), d3 ; d3 := x position of junk's left 
@PLACE_ROW_LOOP:
    MOVE.B  (a3)+, d1   ; d1 := junk block data
    BGE.B   @JUNK_NOT_EMPTY ; -1 == empty block
    ADDA.W  #2, a0
    BRA.B   @PLACE_ROW_STEP
@JUNK_NOT_EMPTY:
    ; convert pattern ID into RAM offset
    LEA.L   JUNK_GRAY, a5
    ANDI.W  #$FF, d1
    LSL.W   #1, d1
    ADDA.W  d1, a5 ; a5 := JUNK pattern
    ; check if block should be colored
    BTST    #14, d0
    BEQ.B   @BLOCK_COLOR_DONE
    ; check if block uses second palette
    BTST    #10, d0
    BNE.B   @BLOCK_PAL_2
    ; for palette 1, patterns are after the gray patterns
    ADDA.W  #26, a5 ; 13 patterns or 26 bytes
    MOVE.W  (a5), (SCRATCH)
    LEA.L   SCRATCH, a5
    ; we need to add the color * 5 to the pattern data
    MOVE.W  d0, d5
    ANDI.W  #$0300, d5
    LSR.W   #6, d5  ; d5 := color * 4
    ADD.W   d5, (a5)
    LSR.W   #2, d5  ; d5 := color
    ADD.W   d5, (a5)
    BRA.B   @BLOCK_COLOR_DONE
@BLOCK_PAL_2:
    ; for palette 2, patterns are after the palette 1 patterns
    ADDA.W  #52, a5 ; 26 patterns or 52 bytes
    MOVE.W  (a5), (SCRATCH)
    LEA.L   SCRATCH, a5
    ; we need to change the palette
    ANDI.W  #$DFFF, (a5)
    ORI.W   #$4000, (a5)
    ; we need to add the color * 5 to the pattern data
    MOVE.W  d0, d5
    ANDI.W  #$0300, d5
    LSR.W   #6, d5  ; d5 := color * 4
    ADD.W   d5, (a5)
    LSR.W   #2, d5  ; d5 := color
    ADD.W   d5, (a5)

@BLOCK_COLOR_DONE:
    ; place pattern in screen buffer
    JSR     PLACE_JUNK_BLOCK
    ; place block data in board
    MOVE.W  d0, (a0)+

@PLACE_ROW_STEP:
    ADDQ    #1, d3
    DBRA    d2, @PLACE_ROW_LOOP
@PLACE_JUNK_STEP:
    ; jump to next row for a0
    SUBA.W  d6, a0 ; go back to left side of block
    SUBA.W  d6, a0 ; keep in mind d6 = width-1
    ADDA.W  #(BOARD_WIDTH*2)-2, a0 ; go down 1 row
    ; move y down by 1
    ADDQ    #1, d4
    DBRA    d7, @PLACE_JUNK_LOOP

@SKIP_JUNK_SPAWN:
    ; cycle through IDs until we find an unused one
    MOVE.L  a2, a0
    ADDA.W  #JUNK_IDS_OFF, a0 ; a0 points to bitfield
    MOVE.B  (NEXT_JUNKID_OFF, a2), d0 ; d0 is current index in bitfield
    ; decrement d0, if result is zero roll over to 255
    SUBQ.B  #1, d0
    BNE     @SKIP_ROLLOVER
    SUBQ.B  #1, d0
@SKIP_ROLLOVER:

    ANDI.W  #$00FF, d0
    MOVE.W  d0, d1      ; d1 := bit index (when modulo 8)
    LSR.W   #3, d0      ; d0 := byte index
    ; ANDI.W  #$7, d1
    ADDA.W  d0, a0
    BSET.B  d1, (a0)
    ; if bit was 0, the id is free
    BEQ.B   @ID_CYCLE_DONE
    
    ; if bit was 1, we have to try the next bit
    MOVE.B  d1, (NEXT_JUNKID_OFF, a2)
    BRA.B   @SKIP_JUNK_SPAWN

@ID_CYCLE_DONE:
    MOVE.B  d1, (NEXT_JUNKID_OFF, a2)

    ; randomly choose pattern of next block
    JSR     RAND
    ANDI.W  #3, d0
    MOVE.W  d0, (JUNK_PAT_OFF, a2)

    ; randomly choose next x coordinate
    JSR     RAND
    ANDI.W  #$000F, d0  ; limit d0 to 15
    ; while d0 > (BOARD_WIDTH - PIECE_WIDTH),
    ; d0 -= (BOARD_WIDTH - PIECE_WIDTH)
    MOVE.W  (JUNK_PAT_OFF, a2), d2  ; d2 := pattern number
    LSL.W   #4, d2                  ; d2 := pattern offset
    LEA.L   JUNK_PIECES, a0
    ADDA.W  d2, a0                  ; a0 -> pattern
    MOVE.B  (a0), d2
    ANDI.W  #$00FF, d2              ; d2 := pattern width
    MOVEQ   #BOARD_WIDTH, d1
    SUB.W   d2, d1                  ; d1 := BOARD_WIDTH - PIECE_WIDTH
@CHECK_RAND_X: 
    CMP     d1, d0
    BLE     @RAND_X_IN_RANGE
    SUB.W   d1, d0
    BRA.B   @CHECK_RAND_X
@RAND_X_IN_RANGE:
    MOVE.W  d0, (NEXT_JUNK_X_OFF, a2)

    POP     a3/a5
    RTS

; =============================================
; CHECK_MATCH
; ---------------------------------------------
; Check for a match that includes a given block
; ---------------------------------------------
; Parameters:
;   a0 - pointer to block
;   a2 - player game state
;   d3 - x position of block
;   d4 - y position of block
; Thrashed:
;   none
; Locals:
;   a1 - pointer up/left
;   a3 - pointer down/right
;   a4 - pointer to TO_CLEAR
;   d0 - block data
;   d1 - loop counter
;   d2 - misc
;   d5 - misc
;   d6 - tracks if match is a repeat or not
; =============================================
CHECK_MATCH:
    PUSH    a1/a3-a4/d0-d6

    MOVE.L  a0, a1
    MOVE.L  a0, a3
    MOVE.W  (a3)+, d0   ; d0 := (a0), a3 points one block to the right
    ; if piece is junk, it can't be matched, so return
    TST.B   d0
    BNE     @CHECK_MATCH_RET
    
    ; move a1 to the left until (a1) != d0, but don't go further left than the board
    MOVE.W  d3, d1
    MOVEQ   #0, d2      ; so we don't break the loop instantly
    BRA     @CHECK_LEFT_STEP
@CHECK_LEFT_LOOP:
    CMP.W   -(a1), d0
@CHECK_LEFT_STEP:
    DBNE    d1, @CHECK_LEFT_LOOP
    ; if we exitted the loop due to the count, (a1) matches d0.
    ; if we exitted due to the NE condition, (a1 + 2) matches d0, but (a1) doesn't.
    BEQ     @CHECK_LEFT_DONE
    ADDA.W  #2, a1
@CHECK_LEFT_DONE:
    
    ; move a3 to the right until (a3) != d0, don't go further right than the board
    MOVE.W  #BOARD_WIDTH, d1
    SUB.W   d3, d1
    SUBQ    #1, d1  ; d1 := BOARD_WIDTH - CURSOR_X - 1
    MOVEQ   #0, d2  ; so we don't break the loop instantly
    BRA     @CHECK_RIGHT_STEP
@CHECK_RIGHT_LOOP:
    CMP.W   (a3)+, d0
@CHECK_RIGHT_STEP:
    DBNE    d1, @CHECK_RIGHT_LOOP
    ; if we exitted the loop due to the count, (a3 - 2) matches d0.
    ; if we exitted due to the NE condition, (a3 - 4) matches d0, but (a3 - 2) doesn't.
    BEQ     @CHECK_RIGHT_DONE
    SUBA.W  #2, a3
@CHECK_RIGHT_DONE:
    SUBA.W  #2, a3

    ; if a3 - a1 >= 4, we have a match
    MOVE.W  a3, d1
    SUB.W   a1, d1
    CMPI.W  #4, d1
    BLT     @NO_H_MATCH
    
    ; clear the blocks
    ; >= 4 words is >= 2 blocks of space, is >= 2+1 blocks to clear
    LSR.W   #1, d1
    
    ; d2 will be x coordinate of leftmost block in the match
    MOVE.W  a1, d2
    SUB.W   a0, d2  ; d2 := address of left block - address of cursor
    ASR.W   #1, d2  ; d2 := pos of left block - pos of cursor
    ADD.W   d3, d2  ; d2 := pos of left block
    MOVE.L  a2, a4
    ADD.W   #TO_CLEAR_OFF, a4
    ADDA.W  d4, a4
    ADDA.W  d4, a4  ; a4 := pointer to word in TO_CLEAR for current row
    MOVE.W  (a4), d5; d5 := contents of TO_CLEAR for current row

    ; d6 will be set to TRUE if any previously
    ; unmatched block is included in the match
    MOVEQ   #0, d6

@H_CLEAR_LOOP:
    BSET    d2, d5
    ; if bit was previously unset, set d6 to TRUE
    BNE.B   @NOT_NEW_H_BLOCK
    MOVEQ   #-1, d6
@NOT_NEW_H_BLOCK:
    ADDQ    #1, d2
    DBRA    d1, @H_CLEAR_LOOP

    ; store updated TO_CLEAR flags
    MOVE.W  d5, (a4)
    ; if match contained any previously-unmatched
    ; blocks, increase player's combo and award points
    TST.W   d6
    BEQ.B   @NO_H_MATCH
    ADDQ.W  #1, (COMBO_OFF, a2)
    ; award points
    JSR     ADD_MATCH_SCORE
    ; spawn projectile
    JSR     SPAWN_H_PROJ

@NO_H_MATCH:

    ; same as above, but vertical
    MOVE.L  a0, a1
    MOVE.L  a0, a3
    ; d0 still contains the block

    ; move a1 up until (a1) != d0, but don't go above the top of the board
    MOVE.W  d4, d1
    MOVE.W  #0, d2
    BRA     @CHECK_UP_STEP
@CHECK_UP_LOOP:
    SUBA.W  #BOARD_WIDTH*2, a1
    CMP.W   (a1), d0
@CHECK_UP_STEP:
    DBNE    d1, @CHECK_UP_LOOP
    ; if we exitted due to NE, go back down a row
    BEQ     @CHECK_UP_DONE
    ADDA.W  #BOARD_WIDTH*2, a1
@CHECK_UP_DONE:
    ; save Y position of top block to d5
    MOVE.W  d1, d5
    ; if we exitted due to NE, top block is 1 down
    ; if we exitted due to d1 = -1, we want d5 to be 0
    ADDQ    #1, d5

    ; move a3 down until (a3) != d0, but don't go below the board
    MOVE.W  #BOARD_HEIGHT, d1
    SUB.W   d4, d1
    SUBQ    #1, d1
    MOVE.W  #0, d2
    BRA     @CHECK_DOWN_STEP
@CHECK_DOWN_LOOP:
    ADDA.W  #BOARD_WIDTH*2, a3
    CMP.W   (a3), d0
@CHECK_DOWN_STEP:
    DBNE    d1, @CHECK_DOWN_LOOP
    ; if we exitted due to NE, go up a row
    BEQ     @CHECK_DOWN_DONE
    SUBA.W  #BOARD_WIDTH*2, a3
@CHECK_DOWN_DONE:

    ; if a3 - a1 >= BOARD_WIDTH*4, we have a match
    MOVE.W  a3, d1
    SUB.W   a1, d1
    CMPI.W  #BOARD_WIDTH*4, d1
    BLT     @NO_V_MATCH

    ; clear the blocks
    MOVE.L  a2, a4
    ADD.W   #TO_CLEAR_OFF, a4
    ADDA.W  d5, a4  ; d5 is the pos of the top block, saved in CHECK_UP_LOOP
    ADDA.W  d5, a4  ; a4 := pointer to word in TO_CLEAR for current row
    LSR.W   #1, d1  ; d1 := BOARD_WIDTH * (MATCH_HEIGHT-1)
    ADD.W   #BOARD_WIDTH, d1 ;= BOARD_WIDTH * MATCH_HEIGHT

    ; d6 will be set to TRUE if any previously
    ; unmatched block is included in the match
    MOVEQ   #0, d6

@V_CLEAR_LOOP:
    MOVE.W  (a4), d5    ; d5 := current row in TO_CLEAR
    BSET    d3, d5      ; set bit representing x position of match
    ; if bit was previously unset, set d6 to TRUE
    BNE.B   @NOT_NEW_V_BLOCK
    MOVEQ   #-1, d6
@NOT_NEW_V_BLOCK:
    MOVE.W  d5, (a4)+   ; store updated flags
    SUB.W   #BOARD_WIDTH, d1
    BGT.B   @V_CLEAR_LOOP

    ; if match contained any previously-unmatched
    ; blocks, increase player's combo and award points
    TST.W   d6
    BEQ.B   @NO_V_MATCH
    ADDQ.W  #1, (COMBO_OFF, a2)
    ; award points
    JSR     ADD_MATCH_SCORE
    ; spawn projectile
    JSR     SPAWN_V_PROJ

@NO_V_MATCH:
@CHECK_MATCH_RET:
    POP     a1/a3-a4/d0-d6
    RTS


; ==================================
; CLEAR_BLOCKS
; ----------------------------------
; Clears all blocks that are flagged
; to be cleared in TO_CLEAR
; ----------------------------------
; Parameters:
;   a1 - game board
;   a2 - game state
;   a4 - points to screen buffer
; Thrashed:
;   none
; ==================================
CLEAR_BLOCKS:
    PUSH    a0-a1/d0-d5
    MOVE.L  a2, a0
    ADD.W   #TO_CLEAR_OFF, a0
    MOVEQ   #BOARD_HEIGHT-1, d5
    MOVEQ   #0, d3
    MOVEQ   #0, d4
@CLEAR_ROWS_LOOP:
    ; get 2 rows
    MOVE.W  (a0), d1
    CLR.W   (a0)+
    ; start at x = 0
    MOVEQ   #0, d2
@CLEAR_BLOCK_LOOP:
    BTST    d2, d1
    BEQ     @CLEAR_BLOCK_STEP
    MOVE.W  (a1), d0
    MOVE.W  #0, (a1)
    JSR     ERASE_BLOCK
    JSR     SPAWN_DEBRIS
@CLEAR_BLOCK_STEP:
    ADDA.W  #2, a1
    ADDQ    #1, d2
    ADDQ    #1, d3
    CMPI.W  #BOARD_WIDTH, d2
    BLT     @CLEAR_BLOCK_LOOP
    ADDQ    #1, d4
    MOVEQ   #0, d3
    DBRA    d5, @CLEAR_ROWS_LOOP

    POP     a0-a1/d0-d5
    RTS

; ===========================================
; SHATTER_ANIM
; -------------------------------------------
; For each junk block going through a shatter
; animation, advance its frame counter. If it
; is finished, replace it with a new block.
; -------------------------------------------
; Parameters:
;   a1 - game board
;   a2 - game state
;   a4 - screen buffer
; Thrashed:
;   d0-d4
; ===========================================
SHATTER_ANIM:
    PUSH    a3
    ; game state is right after board, we'll use a2 to access the board
    MOVE.L  a2, a3
    MOVEQ   #BOARD_WIDTH-1, d3
    MOVEQ   #BOARD_HEIGHT-1, d4

@SHATTER_LOOP:
    MOVE.W  -(a3), d0
    ; if block is not junk, skip it
    TST.B   d0
    BEQ.B   @SHATTER_STEP
    ; if block is not shattering, skip it
    BTST    #SHATTER_FLAG_W, d0
    BEQ.B   @SHATTER_STEP
    ; if block is shattering, count down
    SUBQ.B  #1, d0
    ; if timer reaches zero, replace with block
    BEQ.B   @SHATTER_REPLACE
    ; otherwise, store it and move on
    MOVE.W  d0, (a3)
    BRA.B   @SHATTER_STEP

@SHATTER_REPLACE:
    ; replace the junk block with a new block
    JSR     RAND
    BSET    #14, d0     ; set N
    ANDI.W  #$4700, d0  ; clear all except N and color
    MOVE.W  d0, (a3)    ; store in board data
    JSR     PLACE_BLOCK ; place block in screen buffer
    ; when a junk block is replaced, add points for the player
    JSR     ADD_SHATTER_SCORE

@SHATTER_STEP:
    DBRA    d3, @SHATTER_LOOP
    MOVEQ   #BOARD_WIDTH-1, d3
    DBRA    d4, @SHATTER_LOOP

    POP     a3
    RTS

; ============================================
; SHATTER_JUNK
; --------------------------------------------
; Given a pointer to any block in a junk piece
; within the board data, begin the shattering
; animation for all blocks in the piece
; --------------------------------------------
; Parameters:
;   a0 - pointer to junk
;   a1 - pointer to game board
;   a2 - pointer to game state
; Thrashed:
;   none
; ============================================
SHATTER_JUNK:
    PUSH    a0/a3/d0-d2

    ; when a new block is shattered,
    ; increase the player's combo
    ADDQ.W  #1, (COMBO_OFF, a2)

    ; save data for junk piece
    MOVE.W  (a0), d0

    ; d1 will hold the value for each block's shatter timer,
    ; so different blocks shatter at different times
    MOVE.W  #SHATTER_BASE, d1

    ; move a0 to the bottom-left block in the junk piece
@LOOP_DOWN:
    ADDA.W  #BOARD_WIDTH*2, a0
    ; don't go beyond game board
    CMP.L   a2, a0
    BGE.B   @BREAK_DOWN
    ; loop loop until we leave the junk piece
    CMP.W   (a0), d0
    BEQ.B   @LOOP_DOWN
@BREAK_DOWN:
    SUBA.W  #BOARD_WIDTH*2, a0

@LOOP_LEFT:
    ; don't go beyond start of game board
    CMP.L   a1, a0
    BLE.B   @BREAK_LEFT
    CMP.W   -(a0), d0
    BEQ.B   @LOOP_LEFT
    ; addition only necessary if loop ended due to unequal block
    ADDA.W  #2, a0  ; a0 -> leftmost junk block
@BREAK_LEFT:

    ; for each column, iterate to the top, setting shatter bit and timer
@SHATTER_COLUMN_LOOP:
    MOVEA.L a0, a3
    MOVE.W  d1, d2
@LOOP_UP:
    BSET.B  #SHATTER_FLAG_B, (a3)
    MOVE.B  d2, 1(a3)
    ADDQ.B  #SHATTER_INC, d2
    SUBA.W  #BOARD_WIDTH*2, a3
    ; don't go beyond top of board
    CMP.L   a1, a3
    BLT.B   @SHATTER_COLUMN_STEP
    CMP.W   (a3), d0
    BEQ.B   @LOOP_UP

; advance to next column, break if we go beyond board or junk piece
@SHATTER_COLUMN_STEP:
    ADDQ.B  #SHATTER_INC, d1
    ADDA.W  #2, a0
    CMP.L   a2, a0
    BGE.B   @SHATTER_COLUMN_BREAK
    CMP.W   (a0), d0
    BEQ.B   @SHATTER_COLUMN_LOOP

@SHATTER_COLUMN_BREAK:
    POP     a0/a3/d0-d2
    RTS
    

