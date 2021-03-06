
; ********************************************************************
; CONST_GAME.S
; Constant values that don't fit into other CONST files or CHAR_INDEX.
;
; Copyright (C) 2022 Aidan Garvey - see MAIN.S for license details.
; ********************************************************************

MATCH_POINTS = $5 ; base points awarded for matching blocks - BCD
SHATTER_POINTS = $5 ; base points awarded for destroying junk - BCD
                    ; (this is awarded for each block in the piece)
BOARD_HEIGHT = 24 ; in cells
BOARD_WIDTH = 10 ; in cells
BOARD_SIZE = 480 ; size of board in bytes

SCORE_BUFF_SIZE = $E0

HOLD_LENGTH = 6 ; held buttons are handled every HOLD_LENGTH frames
SCROLL_DIV = 2  ; divisor for background scroll amount per frame

T_HOFF_1 = $88
T_HOFF_2 = $180

T_NEXT_VPOS = $94
T_NEXT_HPOS_1 = T_HOFF_1+12
T_NEXT_HPOS_2 = T_HOFF_2+12

P_NEXT_POS_1 = BUFF_PLANE+64*8+4
P_NEXT_POS_2 = P_NEXT_POS_1+62

T_SCORE_VPOS = T_NEXT_VPOS+$30
T_SCORE_HPOS_1 = T_HOFF_1+12
T_SCORE_HPOS_2 = T_HOFF_2+12

SCORE_DGTS_VPOS = T_SCORE_VPOS+12
SCORE_DGTS_HPOS_1 = T_HOFF_1
SCORE_DGTS_HPOS_2 = T_HOFF_2
SCORE_DGTS_HLOW_1 = SCORE_DGTS_HPOS_1+24
SCORE_DGTS_HLOW_2 = SCORE_DGTS_HPOS_2+24

T_LLINES_VPOS = SCORE_DGTS_VPOS+$10
T_LLINES_HPOS_1 = T_HOFF_1+4
T_LLINES_HPOS_2 = T_HOFF_2+4

BOUNDS_LEFT = $70
BOUNDS_RIGHT = $1D0
BOUNDS_TOP = $80
BOUNDS_BOTTOM = $160

P1_BOARD_COL_OFFSET = 9
P2_BOARD_COL_OFFSET = 21
BOARD_ROW_OFFSET = 2
P1_LEFT_BOUND = $C0
P1_RIGHT_BOUND = $118
P2_LEFT_BOUND = $120
P2_RIGHT_BOUND = $178

; velocity & acceleration for projectile particles
; 16ths of a pixel per frame
PROJ_Y_VEL = $20
PROJ_X_VEL = $20
PROJ_Y_ACCEL = 6
PROJ_X_ACCEL = 4

; debris random velocity is limited to 31 in each direction
DEBRIS_VEL_MASK = $001F001F
GRAVITY = 2 ; vertical acceleration

; bit indexes
NOT_GRAY_FLAG = 14
SHATTER_FLAG_B = 5
SHATTER_FLAG_W = 13
PART_PROJ_FLAG_B = 7
PART_PROJ_FLAG_W = 15
PROJ_DIR_FLAG_B = 6
PROJ_DIR_FLAG_W = 14
PART_PLAYER_FLAG_B = 5
PART_PLAYER_FLAG_W = 13
PART_PLAYER_MASK_W = $2000

; for each block of a junk piece, the number of
; frames before it shatters is calculated as:
; SHATTER_BASE + (distance from bottom-left) * SHATTER_INC
SHATTER_BASE = 10
SHATTER_INC = 5
