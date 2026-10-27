# shared drawing / input / utility procedures (include at the bottom of each game)

.data
pen_color:  .word COLOR_WHITE

.text

# set_color($a0 = color): every draw call after this uses that color
set_color:
    sw    $a0, pen_color
    jr    $ra

# draw_pixel($a0 = x, $a1 = y): off-screen coords are just skipped
draw_pixel:
    bltz  $a0, dp_done              # x < 0
    bltz  $a1, dp_done              # y < 0
    bge   $a0, BMP_WIDTH, dp_done   # x >= 64
    bge   $a1, BMP_HEIGHT, dp_done  # y >= 64

    sll   $t0, $a1, 6               # y * 64  (shift works because width = 64)
    addu  $t0, $t0, $a0             # + x
    sll   $t0, $t0, 2               # * 4 bytes per pixel
    li    $t1, BMP_BASE
    addu  $t0, $t0, $t1             # final address
    lw    $t2, pen_color
    sw    $t2, 0($t0)
dp_done:
    jr    $ra

# draw_rect($a0 = x, $a1 = y, $a2 = w, $a3 = h): filled rectangle
draw_rect:
    addi  $sp, $sp, -24
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)
    sw    $s4, 20($sp)

    move  $s0, $a0                  # s0 = starting x
    move  $s1, $a1                  # s1 = current y
    addu  $s2, $a0, $a2             # s2 = x end (exclusive)
    addu  $s3, $a1, $a3             # s3 = y end (exclusive)

dr_row:
    bge   $s1, $s3, dr_done         # finished all rows
    move  $s4, $s0                  # s4 = current x
dr_col:
    bge   $s4, $s2, dr_next_row
    move  $a0, $s4
    move  $a1, $s1
    jal   draw_pixel
    addi  $s4, $s4, 1
    j     dr_col
dr_next_row:
    addi  $s1, $s1, 1
    j     dr_row

dr_done:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    lw    $s4, 20($sp)
    addi  $sp, $sp, 24
    jr    $ra

# draw_border(x, y, w, h): 1-unit outline made from 4 thin rects
draw_border:
    addi  $sp, $sp, -20
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)

    move  $s0, $a0                  # x
    move  $s1, $a1                  # y
    move  $s2, $a2                  # w
    move  $s3, $a3                  # h

    # top edge: (x, y, w, 1)
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    li    $a3, 1
    jal   draw_rect

    # bottom edge: (x, y+h-1, w, 1)
    move  $a0, $s0
    addu  $a1, $s1, $s3
    addi  $a1, $a1, -1
    move  $a2, $s2
    li    $a3, 1
    jal   draw_rect

    # left edge: (x, y, 1, h)
    move  $a0, $s0
    move  $a1, $s1
    li    $a2, 1
    move  $a3, $s3
    jal   draw_rect

    # right edge: (x+w-1, y, 1, h)
    addu  $a0, $s0, $s2
    addi  $a0, $a0, -1
    move  $a1, $s1
    li    $a2, 1
    move  $a3, $s3
    jal   draw_rect

    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    addi  $sp, $sp, 20
    jr    $ra

# clear_screen: fill the whole display with the pen color
clear_screen:
    lw    $t2, pen_color
    li    $t0, BMP_BASE
    li    $t1, BMP_PIXELS
cs_loop:
    sw    $t2, 0($t0)
    addi  $t0, $t0, 4
    addi  $t1, $t1, -1
    bgtz  $t1, cs_loop
    jr    $ra

# get_key: wait for a key, return its ASCII in $v0
get_key:
    li    $t0, MMIO_CTRL
gk_wait:
    lw    $t1, 0($t0)               # read control word
    andi  $t1, $t1, 1               # keep only bit 0
    beqz  $t1, gk_wait              # no key yet -> check again
    lw    $v0, 4($t0)               # read the key (MMIO_DATA = CTRL + 4)
    jr    $ra

# poll_key: return a key if one is waiting, otherwise 0 (doesn't wait)
poll_key:
    li    $t0, MMIO_CTRL
    lw    $t1, 0($t0)
    andi  $t1, $t1, 1
    beqz  $t1, pk_none
    lw    $v0, 4($t0)
    jr    $ra
pk_none:
    li    $v0, 0
    jr    $ra

# font: each glyph is a 3x5 picture packed into 15 bits of one word,
# read left to right, top to bottom (1 = pixel on)
.data
font:
    .word 0x7B6F    #  0   ### #.# #.# #.# ###
    .word 0x2C97    #  1   .#. ##. .#. .#. ###
    .word 0x73E7    #  2   ### ..# ### #.. ###
    .word 0x73CF    #  3   ### ..# ### ..# ###
    .word 0x5BC9    #  4   #.# #.# ### ..# ..#
    .word 0x79CF    #  5   ### #.. ### ..# ###
    .word 0x79EF    #  6   ### #.. ### #.# ###
    .word 0x7249    #  7   ### ..# ..# ..# ..#
    .word 0x7BEF    #  8   ### #.# ### #.# ###
    .word 0x7BCF    #  9   ### #.# ### ..# ###
    .word 0x2BED    # 10 A .#. #.# ### #.# #.#
    .word 0x726A    # 11 J ### ..# ..# #.# .#.
    .word 0x7B73    # 12 Q ### #.# #.# ##. .##
    .word 0x5BAD    # 13 K #.# #.# ##. #.# #.#
    .word 0x388E    # 14 S .## #.. .#. ..# ##.
    .word 0x7927    # 15 C ### #.. #.. #.. ###
    .word 0x6B6E    # 16 D ##. #.# #.# #.# ##.
    .word 0x5BED    # 17 H #.# #.# ### #.# #.#

.text

# draw_glyph($a0 = glyph 0-17, $a1 = x, $a2 = y): bad glyph numbers draw nothing
draw_glyph:
    bltz  $a0, dg_invalid           # glyph < 0
    bge   $a0, GLYPH_COUNT, dg_invalid  # glyph >= 18

    addi  $sp, $sp, -28
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)
    sw    $s4, 20($sp)
    sw    $s5, 24($sp)

    sll   $t0, $a0, 2               # glyph number * 4 = byte offset
    la    $t1, font
    addu  $t1, $t1, $t0
    lw    $s0, 0($t1)               # s0 = the glyph's 15-bit pattern
    move  $s1, $a1                  # s1 = left x
    move  $s2, $a2                  # s2 = top y
    li    $s5, 0x4000               # s5 = mask, starts at bit 14 (top-left)
    li    $s3, 0                    # s3 = row

dg_row:
    bge   $s3, GLYPH_HEIGHT, dg_done
    li    $s4, 0                    # s4 = column
dg_col:
    bge   $s4, GLYPH_WIDTH, dg_next_row
    and   $t0, $s0, $s5             # is this bit on?
    beqz  $t0, dg_skip              # 0 -> leave blank
    addu  $a0, $s1, $s4             # x = left + column
    addu  $a1, $s2, $s3             # y = top + row
    jal   draw_pixel
dg_skip:
    srl   $s5, $s5, 1               # move mask to the next bit
    addi  $s4, $s4, 1
    j     dg_col
dg_next_row:
    addi  $s3, $s3, 1
    j     dg_row

dg_done:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    lw    $s4, 20($sp)
    lw    $s5, 24($sp)
    addi  $sp, $sp, 28
dg_invalid:
    jr    $ra

# draw_number($a0 = 0-99, $a1 = x, $a2 = y): no leading zero, out of range draws nothing
draw_number:
    bltz  $a0, dn_invalid
    bgt   $a0, 99, dn_invalid

    addi  $sp, $sp, -20
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)

    move  $s1, $a1                  # s1 = x
    move  $s2, $a2                  # s2 = y
    li    $t0, 10
    div   $a0, $t0                  # LO = n / 10, HI = n % 10
    mflo  $s0                       # s0 = tens digit
    mfhi  $s3                       # s3 = ones digit

    beqz  $s0, dn_ones              # skip a leading zero
    move  $a0, $s0
    move  $a1, $s1
    move  $a2, $s2
    jal   draw_glyph
    addi  $s1, $s1, GLYPH_SPACING   # move right for the next digit
dn_ones:
    move  $a0, $s3
    move  $a1, $s1
    move  $a2, $s2
    jal   draw_glyph

    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    addi  $sp, $sp, 20
dn_invalid:
    jr    $ra

# print_str($a0 = string address)
print_str:
    li    $v0, 4
    syscall
    jr    $ra

# print_int($a0 = number)
print_int:
    li    $v0, 1
    syscall
    jr    $ra

# rand_seed($a0 = seed): same seed = same random sequence, handy for testing
rand_seed:
    move  $a1, $a0                  # syscall 40: $a0 = generator id, $a1 = seed
    li    $a0, 0
    li    $v0, 40
    syscall
    jr    $ra

# rand_range($a0 = n): returns 0..n-1 in $v0
rand_range:
    move  $a1, $a0                  # syscall 42: $a0 = generator id, $a1 = upper bound
    li    $a0, 0
    li    $v0, 42
    syscall                         # result comes back in $a0
    move  $v0, $a0
    jr    $ra

# sleep($a0 = milliseconds)
sleep:
    li    $v0, 32
    syscall
    jr    $ra
