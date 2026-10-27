# two-player tic-tac-toe

.include "constants.asm"

# board layout
.eqv TTT_BOARD_X   3      # left edge of box 1
.eqv TTT_BOARD_Y   3      # top edge of box 1
.eqv TTT_BOX_SIZE  18     # each box is 18 x 18
.eqv TTT_BOX_STEP  20     # 18 box + 2 gap

# cell values
.eqv TTT_EMPTY     0
.eqv TTT_X         1
.eqv TTT_O         2

# keys
.eqv KEY_ENTER     10

.data
ttt_board:      .word 0, 0, 0, 0, 0, 0, 0, 0, 0
ttt_turn:       .word TTT_X
ttt_selected:   .word -1

# the 8 winning lines: 3 rows, 3 columns, 2 diagonals
ttt_win_lines:
    .word 0, 1, 2
    .word 3, 4, 5
    .word 6, 7, 8
    .word 0, 3, 6
    .word 1, 4, 7
    .word 2, 5, 8
    .word 0, 4, 8
    .word 2, 4, 6

msg_intro:      .asciiz "=== TIC-TAC-TOE ===\nTwo players take turns. X goes first.\nType keys in the KEYBOARD box of the MMIO Simulator.\n  1-9    select a box (it turns yellow)\n  Enter  place your mark\n  q      quit\n\n"
msg_turn_x:     .asciiz "Player X: choose a box (1-9), then press Enter.\n"
msg_turn_o:     .asciiz "Player O: choose a box (1-9), then press Enter.\n"
msg_invalid:    .asciiz "Invalid key. Use 1-9 to select, Enter to place, q to quit.\n"
msg_taken:      .asciiz "That box is already taken. Pick another.\n"
msg_no_select:  .asciiz "Select a box with 1-9 before pressing Enter.\n"
msg_win_x:      .asciiz "\n*** Player X wins! ***\n"
msg_win_o:      .asciiz "\n*** Player O wins! ***\n"
msg_draw:       .asciiz "\n*** It's a draw! ***\n"
msg_again:      .asciiz "Press r to play again or q to quit.\n"
msg_again_bad:  .asciiz "Please press r or q.\n"
msg_bye:        .asciiz "Thanks for playing!\n"

.text
main:
    la    $a0, msg_intro
    jal   print_str

ttt_new_game:
    jal   ttt_reset
    jal   ttt_draw_board

ttt_turn_loop:
    jal   ttt_print_turn

ttt_input_loop:
    jal   get_key
    move  $s0, $v0

    beq   $s0, 'q', ttt_quit
    beq   $s0, KEY_ENTER, ttt_confirm

    # turn '1'-'9' into index 0-8, reject anything else
    addi  $s1, $s0, -49             # '1' is ASCII 49
    bltz  $s1, ttt_bad_key
    bgt   $s1, 8, ttt_bad_key

    # is the box free?
    sll   $t0, $s1, 2
    lw    $t1, ttt_board($t0)
    bnez  $t1, ttt_box_taken

    # select it: un-highlight the old box, highlight the new one
    lw    $s2, ttt_selected
    sw    $s1, ttt_selected
    bltz  $s2, ttt_highlight_new    # nothing was selected before
    move  $a0, $s2
    li    $a1, COLOR_WHITE
    jal   ttt_draw_box
ttt_highlight_new:
    move  $a0, $s1
    li    $a1, COLOR_YELLOW
    jal   ttt_draw_box
    j     ttt_input_loop

ttt_bad_key:
    la    $a0, msg_invalid
    jal   print_str
    j     ttt_input_loop

ttt_box_taken:
    la    $a0, msg_taken
    jal   print_str
    j     ttt_input_loop

# Enter pressed: place the mark
ttt_confirm:
    lw    $s1, ttt_selected
    bltz  $s1, ttt_nothing_selected

    lw    $t0, ttt_turn
    sll   $t1, $s1, 2
    sw    $t0, ttt_board($t1)       # board[selected] = current player
    li    $t0, -1
    sw    $t0, ttt_selected         # clear the selection

    move  $a0, $s1                  # redraw the box with its new mark
    li    $a1, COLOR_WHITE
    jal   ttt_draw_box

    jal   ttt_check_win
    bnez  $v0, ttt_game_won         # $v0 = winner, $v1 = winning line

    jal   ttt_check_draw
    bnez  $v0, ttt_game_draw

    # switch turns: 1 -> 2, 2 -> 1  (3 - turn)
    lw    $t0, ttt_turn
    li    $t1, 3
    sub   $t0, $t1, $t0
    sw    $t0, ttt_turn
    j     ttt_turn_loop

ttt_nothing_selected:
    la    $a0, msg_no_select
    jal   print_str
    j     ttt_input_loop

# game over
ttt_game_won:
    move  $s0, $v0                  # winner
    move  $a0, $v1                  # winning line index
    jal   ttt_highlight_line
    la    $a0, msg_win_x
    beq   $s0, TTT_X, ttt_print_result
    la    $a0, msg_win_o
    j     ttt_print_result

ttt_game_draw:
    la    $a0, msg_draw

ttt_print_result:
    jal   print_str

ttt_play_again:
    la    $a0, msg_again
    jal   print_str
ttt_again_loop:
    jal   get_key
    beq   $v0, 'r', ttt_new_game
    beq   $v0, 'q', ttt_quit
    la    $a0, msg_again_bad
    jal   print_str
    j     ttt_again_loop

ttt_quit:
    la    $a0, msg_bye
    jal   print_str
    li    $v0, 10
    syscall

# clear the board, X goes first, nothing selected
ttt_reset:
    la    $t0, ttt_board
    li    $t1, 9
tr_loop:
    sw    $zero, 0($t0)
    addi  $t0, $t0, 4
    addi  $t1, $t1, -1
    bgtz  $t1, tr_loop

    li    $t2, TTT_X
    sw    $t2, ttt_turn
    li    $t2, -1
    sw    $t2, ttt_selected
    jr    $ra

# print whose turn it is
ttt_print_turn:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    lw    $t0, ttt_turn
    la    $a0, msg_turn_x
    beq   $t0, TTT_X, tpt_print
    la    $a0, msg_turn_o
tpt_print:
    jal   print_str

    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# ttt_box_pos($a0 = box 0-8) -> $v0 = x, $v1 = y of its top-left corner
# row = index / 3, col = index % 3
ttt_box_pos:
    li    $t0, 3
    div   $a0, $t0
    mflo  $t1                       # t1 = row
    mfhi  $t2                       # t2 = column

    li    $t0, TTT_BOX_STEP
    mul   $v0, $t2, $t0             # column * 20
    addi  $v0, $v0, TTT_BOARD_X
    mul   $v1, $t1, $t0             # row * 20
    addi  $v1, $v1, TTT_BOARD_Y
    jr    $ra

# ttt_draw_box($a0 = box, $a1 = border color): box + its mark, or its number if empty
ttt_draw_box:
    addi  $sp, $sp, -20
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)

    move  $s0, $a0                  # s0 = index
    move  $s3, $a1                  # s3 = border color
    jal   ttt_box_pos
    move  $s1, $v0                  # s1 = x
    move  $s2, $v1                  # s2 = y

    # black inside
    li    $a0, COLOR_BLACK
    jal   set_color
    move  $a0, $s1
    move  $a1, $s2
    li    $a2, TTT_BOX_SIZE
    li    $a3, TTT_BOX_SIZE
    jal   draw_rect

    # border
    move  $a0, $s3
    jal   set_color
    move  $a0, $s1
    move  $a1, $s2
    li    $a2, TTT_BOX_SIZE
    li    $a3, TTT_BOX_SIZE
    jal   draw_border

    # taken box -> draw its mark; empty box -> draw its number
    sll   $t0, $s0, 2
    lw    $t1, ttt_board($t0)
    move  $a0, $s1
    move  $a1, $s2
    beq   $t1, TTT_X, tdbx_x
    beq   $t1, TTT_O, tdbx_o

    # empty: box number in the corner (2 units in from the edge)
    li    $a0, COLOR_GRAY
    jal   set_color
    addi  $a0, $s0, 1               # index 0 shows as "1"
    addi  $a1, $s1, 2
    addi  $a2, $s2, 2
    jal   draw_glyph
    j     tdbx_done
tdbx_x:
    jal   ttt_draw_x
    j     tdbx_done
tdbx_o:
    jal   ttt_draw_o

tdbx_done:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    addi  $sp, $sp, 20
    jr    $ra

# ttt_draw_x($a0 = box x, $a1 = box y): red X, two diagonals 2 units thick
ttt_draw_x:
    addi  $sp, $sp, -16
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)

    move  $s0, $a0                  # s0 = box x
    move  $s1, $a1                  # s1 = box y
    li    $a0, COLOR_RED
    jal   set_color

    li    $s2, 0                    # s2 = i, steps down the diagonals
tdx_loop:
    bge   $s2, 10, tdx_done

    # "\" line: (x+4+i, y+4+i) and the pixel to its right
    addu  $a0, $s0, $s2
    addi  $a0, $a0, 4
    addu  $a1, $s1, $s2
    addi  $a1, $a1, 4
    jal   draw_pixel
    addu  $a0, $s0, $s2
    addi  $a0, $a0, 5
    addu  $a1, $s1, $s2
    addi  $a1, $a1, 4
    jal   draw_pixel

    # "/" line: (x+13-i, y+4+i) and the pixel to its left
    subu  $a0, $s0, $s2
    addi  $a0, $a0, 13
    addu  $a1, $s1, $s2
    addi  $a1, $a1, 4
    jal   draw_pixel
    subu  $a0, $s0, $s2
    addi  $a0, $a0, 12
    addu  $a1, $s1, $s2
    addi  $a1, $a1, 4
    jal   draw_pixel

    addi  $s2, $s2, 1
    j     tdx_loop

tdx_done:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    addi  $sp, $sp, 16
    jr    $ra

# ttt_draw_o($a0 = box x, $a1 = box y): blue square, hollowed out, corners trimmed
ttt_draw_o:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    move  $s0, $a0                  # s0 = box x
    move  $s1, $a1                  # s1 = box y

    # outer blue square
    li    $a0, COLOR_BLUE
    jal   set_color
    addi  $a0, $s0, 4
    addi  $a1, $s1, 4
    li    $a2, 10
    li    $a3, 10
    jal   draw_rect

    # hollow out the middle and round the corners in black
    li    $a0, COLOR_BLACK
    jal   set_color
    addi  $a0, $s0, 6
    addi  $a1, $s1, 6
    li    $a2, 6
    li    $a3, 6
    jal   draw_rect

    addi  $a0, $s0, 4               # top-left corner
    addi  $a1, $s1, 4
    jal   draw_pixel
    addi  $a0, $s0, 13              # top-right corner
    addi  $a1, $s1, 4
    jal   draw_pixel
    addi  $a0, $s0, 4               # bottom-left corner
    addi  $a1, $s1, 13
    jal   draw_pixel
    addi  $a0, $s0, 13              # bottom-right corner
    addi  $a1, $s1, 13
    jal   draw_pixel

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

# clear the screen and draw all 9 boxes
ttt_draw_board:
    addi  $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)

    li    $a0, COLOR_DKGRAY
    jal   set_color
    jal   clear_screen

    li    $s0, 0                    # s0 = box index
tdb_loop:
    bge   $s0, 9, tdb_done
    move  $a0, $s0
    li    $a1, COLOR_WHITE
    jal   ttt_draw_box
    addi  $s0, $s0, 1
    j     tdb_loop
tdb_done:
    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    addi  $sp, $sp, 8
    jr    $ra

# check all 8 lines -> $v0 = winner (0 = none), $v1 = which line
ttt_check_win:
    la    $t0, ttt_win_lines        # t0 = pointer to current line
    la    $t1, ttt_board            # t1 = board base address
    li    $t2, 0                    # t2 = line number
tcw_loop:
    bge   $t2, 8, tcw_none

    lw    $t3, 0($t0)               # first box of the line
    sll   $t3, $t3, 2
    addu  $t3, $t3, $t1
    lw    $t3, 0($t3)               # t3 = value in that box
    beqz  $t3, tcw_next             # empty box can't win

    lw    $t4, 4($t0)               # second box
    sll   $t4, $t4, 2
    addu  $t4, $t4, $t1
    lw    $t4, 0($t4)
    bne   $t3, $t4, tcw_next

    lw    $t5, 8($t0)               # third box
    sll   $t5, $t5, 2
    addu  $t5, $t5, $t1
    lw    $t5, 0($t5)
    bne   $t3, $t5, tcw_next

    move  $v0, $t3                  # all three match
    move  $v1, $t2
    jr    $ra

tcw_next:
    addi  $t0, $t0, 12              # next line (3 words = 12 bytes)
    addi  $t2, $t2, 1
    j     tcw_loop

tcw_none:
    li    $v0, 0
    li    $v1, -1
    jr    $ra

# $v0 = 1 if the board is full (check for a win first)
ttt_check_draw:
    la    $t0, ttt_board
    li    $t1, 9
tcd_loop:
    lw    $t2, 0($t0)
    beqz  $t2, tcd_not_full         # found an empty box
    addi  $t0, $t0, 4
    addi  $t1, $t1, -1
    bgtz  $t1, tcd_loop
    li    $v0, 1
    jr    $ra
tcd_not_full:
    li    $v0, 0
    jr    $ra

# ttt_highlight_line($a0 = line 0-7): give the winning boxes green borders
ttt_highlight_line:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    li    $t0, 12
    mul   $t0, $a0, $t0             # line * 12 bytes
    la    $s0, ttt_win_lines
    addu  $s0, $s0, $t0             # s0 = address of this line
    li    $s1, 3                    # s1 = boxes left to draw
thl_loop:
    lw    $a0, 0($s0)
    li    $a1, COLOR_GREEN
    jal   ttt_draw_box
    addi  $s0, $s0, 4
    addi  $s1, $s1, -1
    bgtz  $s1, thl_loop

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

.include "toolkit.asm"
