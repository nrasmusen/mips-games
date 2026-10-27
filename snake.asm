# snake: eat the food, avoid the walls and yourself

.include "constants.asm"

# 0 = random food, any other number = same food spots every run (for testing)
.eqv SNAKE_SEED    0

.eqv SNAKE_DELAY   110     # milliseconds between moves (lower = faster)

# field layout
.eqv SNAKE_GRID_W  31      # cells across
.eqv SNAKE_GRID_H  27      # cells down
.eqv SNAKE_MAX_LEN 837     # 31 * 27, the whole field
.eqv SNAKE_FIELD_X 1       # display x of cell column 0
.eqv SNAKE_FIELD_Y 9       # display y of cell row 0
.eqv SNAKE_CELL    2       # each cell is 2 x 2 units
.eqv SNAKE_BORDER_Y 8      # top of the border box (rows 0-7 are the HUD)
.eqv SNAKE_SCORE_X 56      # where the score is drawn (top right)

# how a step can end
.eqv SNAKE_ALIVE   0
.eqv SNAKE_HIT_WALL 1
.eqv SNAKE_HIT_SELF 2
.eqv SNAKE_WON     3

.data
snake_x:        .space 3348         # 837 words
snake_y:        .space 3348
snake_len:      .word 0
snake_dir_x:    .word 1
snake_dir_y:    .word 0
snake_food_x:   .word 0
snake_food_y:   .word 0
snake_score:    .word 0

msg_intro:      .asciiz "=== SNAKE ===\nEat the red food to grow. Don't hit the walls or yourself.\nType keys in the KEYBOARD box of the MMIO Simulator.\n  w = up   a = left   s = down   d = right   q = quit\n\n"
msg_ready:      .asciiz "Get ready... 3, 2, 1 (you can pick a direction during the countdown)\n"
msg_go:         .asciiz "GO!\n"
msg_invalid:    .asciiz "Invalid key. Use w a s d to move, q to quit.\n"
msg_wall:       .asciiz "\nGAME OVER - you hit the wall.\n"
msg_self:       .asciiz "\nGAME OVER - you ran into yourself.\n"
msg_won:        .asciiz "\nYOU WIN - the snake filled the whole field!\n"
msg_score:      .asciiz "Final score: "
msg_newline:    .asciiz "\n"
msg_again:      .asciiz "Press r to play again or q to quit.\n"
msg_again_bad:  .asciiz "Please press r or q.\n"
msg_bye:        .asciiz "Thanks for playing!\n"

.text
main:
    li    $t0, SNAKE_SEED           # fixed seed only when testing
    beqz  $t0, snake_seed_done
    move  $a0, $t0
    jal   rand_seed
snake_seed_done:
    la    $a0, msg_intro
    jal   print_str

snake_new_game:
    jal   snake_reset
    jal   snake_draw_field
    jal   snake_place_food
    jal   snake_countdown

snake_frame:
    jal   poll_key                  # non-blocking: 0 if no key
    beqz  $v0, snake_move
    move  $a0, $v0
    jal   snake_handle_key
    bnez  $v0, snake_quit           # handle_key says q was pressed

snake_move:
    jal   snake_step
    bnez  $v0, snake_game_over      # anything but SNAKE_ALIVE ends it

    li    $a0, SNAKE_DELAY
    jal   sleep
    j     snake_frame

snake_game_over:
    move  $a0, $v0
    jal   snake_show_result

    jal   poll_key                  # throw away a leftover key
    la    $a0, msg_again
    jal   print_str
snake_again_loop:
    jal   get_key
    ori   $v0, $v0, 0x20            # 'R' -> 'r', 'Q' -> 'q'
    beq   $v0, 'r', snake_new_game
    beq   $v0, 'q', snake_quit
    la    $a0, msg_again_bad
    jal   print_str
    j     snake_again_loop

snake_quit:
    la    $a0, msg_bye
    jal   print_str
    li    $v0, 10
    syscall

# 3-long snake in the middle heading right, score 0
snake_reset:
    li    $t0, 3
    sw    $t0, snake_len
    la    $t1, snake_x
    la    $t2, snake_y
    li    $t3, 15
    sw    $t3, 0($t1)
    li    $t3, 14
    sw    $t3, 4($t1)
    li    $t3, 13
    sw    $t3, 8($t1)
    li    $t3, 13
    sw    $t3, 0($t2)
    sw    $t3, 4($t2)
    sw    $t3, 8($t2)

    li    $t0, 1                    # moving right: (1, 0)
    sw    $t0, snake_dir_x
    sw    $zero, snake_dir_y
    sw    $zero, snake_score
    jr    $ra

# snake_draw_cell($a0 = cell x, $a1 = cell y, $a2 = color): fill one 2x2 cell
snake_draw_cell:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    sll   $s0, $a0, 1               # cell x * 2
    addi  $s0, $s0, SNAKE_FIELD_X
    sll   $s1, $a1, 1               # cell y * 2
    addi  $s1, $s1, SNAKE_FIELD_Y

    move  $a0, $a2
    jal   set_color
    move  $a0, $s0
    move  $a1, $s1
    li    $a2, SNAKE_CELL
    li    $a3, SNAKE_CELL
    jal   draw_rect

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

# black screen, gray border, whole snake, score
snake_draw_field:
    addi  $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)

    li    $a0, COLOR_BLACK
    jal   set_color
    jal   clear_screen

    li    $a0, COLOR_GRAY
    jal   snake_draw_border

    li    $s0, 0                    # s0 = segment index
sdf_loop:
    lw    $t0, snake_len
    bge   $s0, $t0, sdf_done
    sll   $t1, $s0, 2
    lw    $a0, snake_x($t1)
    lw    $a1, snake_y($t1)
    li    $a2, COLOR_GREEN
    jal   snake_draw_cell
    addi  $s0, $s0, 1
    j     sdf_loop
sdf_done:
    jal   snake_draw_score

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    addi  $sp, $sp, 8
    jr    $ra

# snake_draw_border($a0 = color)
snake_draw_border:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    jal   set_color
    li    $a0, 0
    li    $a1, SNAKE_BORDER_Y
    li    $a2, BMP_WIDTH
    li    $a3, 56                   # rows 8-63
    jal   draw_border

    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# redraw the score in the top right (caps at 99 on screen)
snake_draw_score:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    li    $a0, COLOR_BLACK          # erase the old number
    jal   set_color
    li    $a0, SNAKE_SCORE_X
    li    $a1, 1
    li    $a2, 7
    li    $a3, 5
    jal   draw_rect

    li    $a0, COLOR_WHITE
    jal   set_color
    lw    $a0, snake_score
    ble   $a0, 99, sds_draw
    li    $a0, 99
sds_draw:
    li    $a1, SNAKE_SCORE_X
    li    $a2, 1
    jal   draw_number

    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# 3, 2, 1 in the top-left, 1 sec each. a key pressed now sets the starting direction
snake_countdown:
    addi  $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)

    la    $a0, msg_ready
    jal   print_str

    li    $s0, 3                    # s0 = number showing
scd_loop:
    blez  $s0, scd_done
    li    $a0, COLOR_YELLOW
    jal   set_color
    move  $a0, $s0                  # digit = its own glyph number
    li    $a1, 1
    li    $a2, 1
    jal   draw_glyph

    li    $a0, 1000
    jal   sleep

    li    $a0, COLOR_BLACK          # erase it
    jal   set_color
    li    $a0, 1
    li    $a1, 1
    li    $a2, GLYPH_WIDTH
    li    $a3, GLYPH_HEIGHT
    jal   draw_rect

    addi  $s0, $s0, -1
    j     scd_loop
scd_done:
    la    $a0, msg_go
    jal   print_str

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    addi  $sp, $sp, 8
    jr    $ra

# snake_handle_key($a0 = key) -> $v0 = 1 if q
# wasd turns, but turning straight back into yourself is ignored
snake_handle_key:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    ori   $a0, $a0, 0x20            # uppercase -> lowercase
    beq   $a0, 'q', shk_quit
    beq   $a0, 'w', shk_up
    beq   $a0, 's', shk_down
    beq   $a0, 'a', shk_left
    beq   $a0, 'd', shk_right

    la    $a0, msg_invalid          # anything else
    jal   print_str
    j     shk_done

shk_up:
    li    $t0, 0
    li    $t1, -1
    j     shk_try
shk_down:
    li    $t0, 0
    li    $t1, 1
    j     shk_try
shk_left:
    li    $t0, -1
    li    $t1, 0
    j     shk_try
shk_right:
    li    $t0, 1
    li    $t1, 0

shk_try:
    # reversing means new + current = (0, 0) in both directions
    lw    $t2, snake_dir_x
    lw    $t3, snake_dir_y
    add   $t2, $t2, $t0
    add   $t3, $t3, $t1
    or    $t2, $t2, $t3
    beqz  $t2, shk_done             # would reverse -> ignore
    sw    $t0, snake_dir_x
    sw    $t1, snake_dir_y

shk_done:
    li    $v0, 0
    j     shk_return
shk_quit:
    li    $v0, 1
shk_return:
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# snake_on_body($a0 = x, $a1 = y, $a2 = how many segments to check) -> $v0 = 1 if hit
snake_on_body:
    li    $t0, 0                    # index
sob_loop:
    bge   $t0, $a2, sob_no
    sll   $t1, $t0, 2
    lw    $t2, snake_x($t1)
    lw    $t3, snake_y($t1)
    bne   $t2, $a0, sob_next
    beq   $t3, $a1, sob_yes
sob_next:
    addi  $t0, $t0, 1
    j     sob_loop
sob_yes:
    li    $v0, 1
    jr    $ra
sob_no:
    li    $v0, 0
    jr    $ra

# random empty cell for the food, drawn red
snake_place_food:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

spf_try:
    li    $a0, SNAKE_GRID_W
    jal   rand_range
    move  $s0, $v0                  # s0 = x (0-30)
    li    $a0, SNAKE_GRID_H
    jal   rand_range
    move  $s1, $v0                  # s1 = y (0-26)

    move  $a0, $s0
    move  $a1, $s1
    lw    $a2, snake_len
    jal   snake_on_body
    bnez  $v0, spf_try              # on the snake -> try again

    sw    $s0, snake_food_x
    sw    $s1, snake_food_y
    move  $a0, $s0
    move  $a1, $s1
    li    $a2, COLOR_RED
    jal   snake_draw_cell

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

# move one cell. only redraws what changed: new head green, old tail black
# returns SNAKE_ALIVE / HIT_WALL / HIT_SELF / WON in $v0
snake_step:
    addi  $sp, $sp, -20
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)

    # new head = old head + direction
    lw    $s0, snake_x              # snake_x[0]
    lw    $t0, snake_dir_x
    add   $s0, $s0, $t0             # s0 = new x
    lw    $s1, snake_y
    lw    $t0, snake_dir_y
    add   $s1, $s1, $t0             # s1 = new y

    # wall?
    li    $v0, SNAKE_HIT_WALL
    bltz  $s0, ss_return
    bltz  $s1, ss_return
    bge   $s0, SNAKE_GRID_W, ss_return
    bge   $s1, SNAKE_GRID_H, ss_return

    # own body? Skip the last segment: the tail moves out of the
    # way this step, so moving into where it is now is allowed.
    move  $a0, $s0
    move  $a1, $s1
    lw    $a2, snake_len
    addi  $a2, $a2, -1
    jal   snake_on_body
    li    $t0, SNAKE_HIT_SELF
    move  $t1, $v0
    move  $v0, $t0
    bnez  $t1, ss_return

    # food?
    lw    $t0, snake_food_x
    lw    $t1, snake_food_y
    li    $s2, 0                    # s2 = ate?
    bne   $s0, $t0, ss_no_food
    bne   $s1, $t1, ss_no_food
    li    $s2, 1
ss_no_food:

    lw    $s3, snake_len            # s3 = length
    bnez  $s2, ss_grow

    # didn't eat: erase the tail
    addi  $t0, $s3, -1
    sll   $t0, $t0, 2
    lw    $a0, snake_x($t0)
    lw    $a1, snake_y($t0)
    li    $a2, COLOR_BLACK
    jal   snake_draw_cell
    j     ss_shift

ss_grow:
    addi  $s3, $s3, 1               # ate: one segment longer
    sw    $s3, snake_len

ss_shift:
    # every segment moves into the spot of the one ahead of it:
    # for (i = len-1; i > 0; i--) body[i] = body[i-1]
    addi  $t0, $s3, -1
    sll   $t0, $t0, 2               # t0 = byte offset of i
ss_shift_loop:
    blez  $t0, ss_shift_done
    addi  $t1, $t0, -4              # offset of i-1
    lw    $t2, snake_x($t1)
    sw    $t2, snake_x($t0)
    lw    $t2, snake_y($t1)
    sw    $t2, snake_y($t0)
    addi  $t0, $t0, -4
    j     ss_shift_loop
ss_shift_done:
    sw    $s0, snake_x              # new head into slot 0
    sw    $s1, snake_y

    move  $a0, $s0                  # draw the new head
    move  $a1, $s1
    li    $a2, COLOR_GREEN
    jal   snake_draw_cell

    li    $v0, SNAKE_ALIVE
    beqz  $s2, ss_return

    # ate: score, then new food (or a win if the field is full)
    lw    $t0, snake_score
    addi  $t0, $t0, 1
    sw    $t0, snake_score
    jal   snake_draw_score

    li    $v0, SNAKE_WON
    bge   $s3, SNAKE_MAX_LEN, ss_return
    jal   snake_place_food
    li    $v0, SNAKE_ALIVE

ss_return:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    addi  $sp, $sp, 20
    jr    $ra

# snake_show_result($a0 = how it ended): border color + result text
snake_show_result:
    addi  $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)

    move  $s0, $a0
    li    $a0, COLOR_RED
    bne   $s0, SNAKE_WON, ssr_border
    li    $a0, COLOR_GREEN
ssr_border:
    jal   snake_draw_border

    la    $a0, msg_wall
    beq   $s0, SNAKE_HIT_WALL, ssr_print
    la    $a0, msg_self
    beq   $s0, SNAKE_HIT_SELF, ssr_print
    la    $a0, msg_won
ssr_print:
    jal   print_str

    la    $a0, msg_score
    jal   print_str
    lw    $a0, snake_score
    jal   print_int
    la    $a0, msg_newline
    jal   print_str

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    addi  $sp, $sp, 8
    jr    $ra

.include "toolkit.asm"
