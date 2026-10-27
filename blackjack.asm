# blackjack: one player vs the dealer

.include "constants.asm"

# 0 = random cards, any other number = same cards every run (for testing)
.eqv BJ_SEED       0

# layout
.eqv BJ_CARD_W     8
.eqv BJ_CARD_H     13
.eqv BJ_CARD_STEP_X 9      # card width + 1 gap
.eqv BJ_CARD_STEP_Y 14     # card height + 1 gap
.eqv BJ_PER_ROW    6       # cards per row before wrapping
.eqv BJ_DEALER_Y   2       # top of the dealer's cards
.eqv BJ_PLAYER_Y   34      # top of the player's cards
.eqv BJ_DIVIDER_Y  31
.eqv BJ_TOTAL_X    56      # where the hand totals are drawn
.eqv BJ_MAX_CARDS  11      # most cards a hand can ever hold

# rules
.eqv BJ_DEALER_STAND 17
.eqv BJ_RESHUFFLE  15      # reshuffle when fewer cards than this remain

# round results
.eqv BJ_LOSE       0
.eqv BJ_WIN        1
.eqv BJ_PUSH       2

.data
bj_deck:          .space 208          # 52 words
bj_remaining:     .word 0             # cards still in the deck
bj_player_hand:   .space 44           # 11 words
bj_player_count:  .word 0
bj_dealer_hand:   .space 44
bj_dealer_count:  .word 0
bj_hidden:        .word 1             # 1 = dealer's second card is face down
bj_divider_color: .word COLOR_GRAY
bj_wins:          .word 0
bj_losses:        .word 0
bj_pushes:        .word 0

msg_intro:       .asciiz "=== BLACKJACK ===\nGet closer to 21 than the dealer without going over.\nJ/Q/K = 10, aces = 11 or 1. Dealer hits until 17.\nType keys in the KEYBOARD box of the MMIO Simulator.\n  h = hit   s = stand   n = next hand   q = quit\n\n"
msg_new_hand:    .asciiz "\n--- New hand ---\n"
msg_reshuffle:   .asciiz "(Reshuffling the deck)\n"
msg_your_total:  .asciiz "Your total: "
msg_hit_stand:   .asciiz "   h = hit, s = stand, q = quit\n"
msg_invalid:     .asciiz "Invalid key. Press h to hit, s to stand, or q to quit.\n"
msg_dealer_turn: .asciiz "You stand. Dealer reveals their card.\n"
msg_dealer_hits: .asciiz "Dealer hits.\n"
msg_you:         .asciiz "You: "
msg_dealer:      .asciiz "   Dealer: "
msg_newline:     .asciiz "\n"
msg_blackjack:   .asciiz "BLACKJACK! You win.\n"
msg_dealer_bj:   .asciiz "Dealer has blackjack. You lose.\n"
msg_both_bj:     .asciiz "You both have blackjack. Push.\n"
msg_bust:        .asciiz "BUST! You went over 21. You lose.\n"
msg_dealer_bust: .asciiz "Dealer busts! You win.\n"
msg_win:         .asciiz "You win!\n"
msg_lose:        .asciiz "Dealer wins.\n"
msg_push:        .asciiz "Push (tie).\n"
msg_record:      .asciiz "Record  W: "
msg_record_l:    .asciiz "  L: "
msg_record_p:    .asciiz "  P: "
msg_next:        .asciiz "Press n for the next hand or q to quit.\n"
msg_next_bad:    .asciiz "Please press n or q.\n"
msg_bye:         .asciiz "Thanks for playing!\n"

.text
main:
    li    $t0, BJ_SEED              # fixed seed only when testing
    beqz  $t0, bj_seed_done
    move  $a0, $t0
    jal   rand_seed
bj_seed_done:
    la    $a0, msg_intro
    jal   print_str
    jal   bj_init_deck

# start a hand
bj_new_round:
    la    $a0, msg_new_hand
    jal   print_str

    lw    $t0, bj_remaining         # running low? fresh deck
    bge   $t0, BJ_RESHUFFLE, bj_deck_ok
    jal   bj_init_deck
    la    $a0, msg_reshuffle
    jal   print_str
bj_deck_ok:
    sw    $zero, bj_player_count
    sw    $zero, bj_dealer_count
    li    $t0, 1
    sw    $t0, bj_hidden
    li    $t0, COLOR_GRAY
    sw    $t0, bj_divider_color

    # deal two cards each: player, dealer, player, dealer
    jal   bj_deal_player
    jal   bj_deal_dealer
    jal   bj_deal_player
    jal   bj_deal_dealer
    jal   bj_draw_table

    # check for blackjack (21 with the first two cards)
    jal   bj_player_value
    move  $s0, $v0
    jal   bj_dealer_value
    move  $s1, $v0
    beq   $s0, 21, bj_player_natural
    beq   $s1, 21, bj_dealer_natural
    j     bj_player_turn

bj_player_natural:
    beq   $s1, 21, bj_both_natural
    li    $a0, BJ_WIN
    la    $a1, msg_blackjack
    j     bj_end_round
bj_dealer_natural:
    li    $a0, BJ_LOSE
    la    $a1, msg_dealer_bj
    j     bj_end_round
bj_both_natural:
    li    $a0, BJ_PUSH
    la    $a1, msg_both_bj
    j     bj_end_round

# player's turn
bj_player_turn:
    jal   bj_player_value
    move  $s0, $v0
    bgt   $s0, 21, bj_player_bust
    beq   $s0, 21, bj_dealer_turn   # 21 -> stand automatically

    la    $a0, msg_your_total
    jal   print_str
    move  $a0, $s0
    jal   print_int
    la    $a0, msg_hit_stand
    jal   print_str

bj_player_key:
    jal   get_key
    beq   $v0, 'h', bj_hit
    beq   $v0, 's', bj_stand
    beq   $v0, 'q', bj_quit
    la    $a0, msg_invalid
    jal   print_str
    j     bj_player_key

bj_hit:
    jal   bj_deal_player
    jal   bj_draw_table
    j     bj_player_turn

bj_stand:
    la    $a0, msg_dealer_turn
    jal   print_str
    j     bj_dealer_turn

bj_player_bust:
    li    $a0, BJ_LOSE
    la    $a1, msg_bust
    j     bj_end_round

# dealer's turn
bj_dealer_turn:
    sw    $zero, bj_hidden          # flip the face-down card
    jal   bj_draw_table

bj_dealer_loop:
    jal   bj_dealer_value
    move  $s1, $v0
    bge   $s1, BJ_DEALER_STAND, bj_compare

    li    $a0, 700                  # short pause so you can watch
    jal   sleep
    la    $a0, msg_dealer_hits
    jal   print_str
    jal   bj_deal_dealer
    jal   bj_draw_table
    j     bj_dealer_loop

bj_compare:
    jal   bj_player_value
    move  $s0, $v0
    bgt   $s1, 21, bj_dealer_busted
    bgt   $s0, $s1, bj_player_wins
    blt   $s0, $s1, bj_dealer_wins
    li    $a0, BJ_PUSH
    la    $a1, msg_push
    j     bj_end_round
bj_dealer_busted:
    li    $a0, BJ_WIN
    la    $a1, msg_dealer_bust
    j     bj_end_round
bj_player_wins:
    li    $a0, BJ_WIN
    la    $a1, msg_win
    j     bj_end_round
bj_dealer_wins:
    li    $a0, BJ_LOSE
    la    $a1, msg_lose

# end of hand ($a0 = result, $a1 = message)
bj_end_round:
    jal   bj_finish

    la    $a0, msg_next
    jal   print_str
bj_next_key:
    jal   get_key
    beq   $v0, 'n', bj_new_round
    beq   $v0, 'q', bj_quit
    la    $a0, msg_next_bad
    jal   print_str
    j     bj_next_key

bj_quit:
    la    $a0, msg_bye
    jal   print_str
    li    $v0, 10
    syscall

# deck

# fresh deck: deck[i] = i for 0-51
bj_init_deck:
    la    $t0, bj_deck
    li    $t1, 0
bid_loop:
    sw    $t1, 0($t0)               # deck[i] = i
    addi  $t0, $t0, 4
    addi  $t1, $t1, 1
    blt   $t1, 52, bid_loop
    li    $t2, 52
    sw    $t2, bj_remaining
    jr    $ra

# bj_draw_card -> $v0 = card
# pick a random slot, take that card, move the last card into the hole, remaining--
# so a drawn card can never come up again (no shuffle needed)
bj_draw_card:
    addi  $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)

    lw    $t0, bj_remaining
    bgtz  $t0, bdc_have_cards       # edge case: empty deck -> refill
    jal   bj_init_deck
bdc_have_cards:
    lw    $a0, bj_remaining
    jal   rand_range                # $v0 = random slot
    sll   $t0, $v0, 2
    la    $t1, bj_deck
    addu  $t0, $t1, $t0             # t0 = address of the chosen slot
    lw    $s0, 0($t0)               # s0 = the card we drew

    lw    $t2, bj_remaining
    addi  $t2, $t2, -1
    sw    $t2, bj_remaining
    sll   $t3, $t2, 2
    addu  $t3, $t1, $t3             # t3 = address of the last card
    lw    $t4, 0($t3)
    sw    $t4, 0($t0)               # last card fills the hole

    move  $v0, $s0
    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    addi  $sp, $sp, 8
    jr    $ra

# bj_add_card($a0 = hand, $a1 = &count): draw a card onto the hand (full hand = ignored)
bj_add_card:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    move  $s0, $a0                  # s0 = hand
    move  $s1, $a1                  # s1 = &count
    lw    $t0, 0($s1)
    bge   $t0, BJ_MAX_CARDS, bac_done

    jal   bj_draw_card
    lw    $t0, 0($s1)               # count
    sll   $t1, $t0, 2
    addu  $t1, $s0, $t1
    sw    $v0, 0($t1)               # hand[count] = card
    addi  $t0, $t0, 1
    sw    $t0, 0($s1)               # count++
bac_done:
    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

# one card to the player / one card to the dealer
bj_deal_player:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)
    la    $a0, bj_player_hand
    la    $a1, bj_player_count
    jal   bj_add_card
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

bj_deal_dealer:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)
    la    $a0, bj_dealer_hand
    la    $a1, bj_dealer_count
    jal   bj_add_card
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# scoring

# bj_hand_value($a0 = hand, $a1 = count) -> $v0 = best total
# aces start as 11, then drop to 1 one at a time while over 21
bj_hand_value:
    li    $v0, 0                    # total
    li    $t0, 0                    # aces counted as 11
bhv_loop:
    blez  $a1, bhv_fix_aces
    lw    $t1, 0($a0)               # card
    li    $t2, 13
    div   $t1, $t2
    mfhi  $t1                       # t1 = rank (0-12)

    beqz  $t1, bhv_ace
    bge   $t1, 10, bhv_face         # J, Q, K
    addi  $t1, $t1, 1               # rank 1 -> 2 ... rank 9 -> 10
    add   $v0, $v0, $t1
    j     bhv_next
bhv_ace:
    addi  $v0, $v0, 11
    addi  $t0, $t0, 1
    j     bhv_next
bhv_face:
    addi  $v0, $v0, 10
bhv_next:
    addi  $a0, $a0, 4
    addi  $a1, $a1, -1
    j     bhv_loop

bhv_fix_aces:
    ble   $v0, 21, bhv_done
    blez  $t0, bhv_done
    addi  $v0, $v0, -10             # count one ace as 1 instead of 11
    addi  $t0, $t0, -1
    j     bhv_fix_aces
bhv_done:
    jr    $ra

# $v0 = player total / dealer total
bj_player_value:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)
    la    $a0, bj_player_hand
    lw    $a1, bj_player_count
    jal   bj_hand_value
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

bj_dealer_value:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)
    la    $a0, bj_dealer_hand
    lw    $a1, bj_dealer_count
    jal   bj_hand_value
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# bj_finish($a0 = result, $a1 = message): reveal, color the divider, print totals + record
bj_finish:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    move  $s0, $a0                  # s0 = result
    move  $s1, $a1                  # s1 = message

    # divider color + tally
    beq   $s0, BJ_WIN, bf_win
    beq   $s0, BJ_LOSE, bf_lose
    li    $t0, COLOR_YELLOW         # push
    lw    $t1, bj_pushes
    addi  $t1, $t1, 1
    sw    $t1, bj_pushes
    j     bf_draw
bf_win:
    li    $t0, COLOR_GREEN
    lw    $t1, bj_wins
    addi  $t1, $t1, 1
    sw    $t1, bj_wins
    j     bf_draw
bf_lose:
    li    $t0, COLOR_RED
    lw    $t1, bj_losses
    addi  $t1, $t1, 1
    sw    $t1, bj_losses
bf_draw:
    sw    $t0, bj_divider_color
    sw    $zero, bj_hidden
    jal   bj_draw_table

    # "You: 20   Dealer: 18"
    la    $a0, msg_you
    jal   print_str
    jal   bj_player_value
    move  $a0, $v0
    jal   print_int
    la    $a0, msg_dealer
    jal   print_str
    jal   bj_dealer_value
    move  $a0, $v0
    jal   print_int
    la    $a0, msg_newline
    jal   print_str

    move  $a0, $s1                  # the result message
    jal   print_str

    # "Record  W: 1  L: 0  P: 0"
    la    $a0, msg_record
    jal   print_str
    lw    $a0, bj_wins
    jal   print_int
    la    $a0, msg_record_l
    jal   print_str
    lw    $a0, bj_losses
    jal   print_int
    la    $a0, msg_record_p
    jal   print_str
    lw    $a0, bj_pushes
    jal   print_int
    la    $a0, msg_newline
    jal   print_str

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

# drawing

# redraw everything (dealer total stays hidden until their card flips)
bj_draw_table:
    addi  $sp, $sp, -4
    sw    $ra, 0($sp)

    li    $a0, COLOR_DKGRAY
    jal   set_color
    jal   clear_screen

    # divider line
    lw    $a0, bj_divider_color
    jal   set_color
    li    $a0, 0
    li    $a1, BJ_DIVIDER_Y
    li    $a2, BMP_WIDTH
    li    $a3, 1
    jal   draw_rect

    # dealer's hand (second card face down if hidden)
    la    $a0, bj_dealer_hand
    lw    $a1, bj_dealer_count
    li    $a2, BJ_DEALER_Y
    lw    $a3, bj_hidden
    jal   bj_draw_hand

    # player's hand (all face up)
    la    $a0, bj_player_hand
    lw    $a1, bj_player_count
    li    $a2, BJ_PLAYER_Y
    li    $a3, 0
    jal   bj_draw_hand

    # player's total
    li    $a0, COLOR_YELLOW
    jal   set_color
    jal   bj_player_value
    move  $a0, $v0
    li    $a1, BJ_TOTAL_X
    li    $a2, BJ_PLAYER_Y
    jal   draw_number

    # dealer's total, only once revealed
    lw    $t0, bj_hidden
    bnez  $t0, bdt_done
    li    $a0, COLOR_WHITE
    jal   set_color
    jal   bj_dealer_value
    move  $a0, $v0
    li    $a1, BJ_TOTAL_X
    li    $a2, BJ_DEALER_Y
    jal   draw_number
bdt_done:
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

# bj_draw_hand($a0 = hand, $a1 = count, $a2 = top y, $a3 = 1 to hide card 2)
# 6 cards per row, then wraps
bj_draw_hand:
    addi  $sp, $sp, -24
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)
    sw    $s4, 20($sp)

    move  $s0, $a0                  # s0 = pointer to current card
    move  $s1, $a1                  # s1 = card count
    move  $s2, $a2                  # s2 = top y
    move  $s3, $a3                  # s3 = hide second card?
    li    $s4, 0                    # s4 = card index
bdh_loop:
    bge   $s4, $s1, bdh_done

    # column = index % 6, row = index / 6
    li    $t0, BJ_PER_ROW
    div   $s4, $t0
    mflo  $t1                       # row
    mfhi  $t2                       # column
    li    $t0, BJ_CARD_STEP_X
    mul   $a1, $t2, $t0
    addi  $a1, $a1, 1               # x = 1 + column * 9
    li    $t0, BJ_CARD_STEP_Y
    mul   $a2, $t1, $t0
    addu  $a2, $a2, $s2             # y = top + row * 14

    beqz  $s3, bdh_face_up
    bne   $s4, 1, bdh_face_up
    move  $a0, $a1                  # face-down card
    move  $a1, $a2
    jal   bj_draw_card_back
    j     bdh_next
bdh_face_up:
    lw    $a0, 0($s0)
    jal   bj_draw_card_face
bdh_next:
    addi  $s0, $s0, 4
    addi  $s4, $s4, 1
    j     bdh_loop

bdh_done:
    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    lw    $s4, 20($sp)
    addi  $sp, $sp, 24
    jr    $ra

# bj_draw_card_face($a0 = card, $a1 = x, $a2 = y): rank on top, suit below
bj_draw_card_face:
    addi  $sp, $sp, -20
    sw    $ra,  0($sp)
    sw    $s0,  4($sp)
    sw    $s1,  8($sp)
    sw    $s2, 12($sp)
    sw    $s3, 16($sp)

    move  $s1, $a1                  # s1 = x
    move  $s2, $a2                  # s2 = y
    li    $t0, 13
    div   $a0, $t0
    mflo  $s3                       # s3 = suit (0-3)
    mfhi  $s0                       # s0 = rank (0-12)

    # white card
    li    $a0, COLOR_WHITE
    jal   set_color
    move  $a0, $s1
    move  $a1, $s2
    li    $a2, BJ_CARD_W
    li    $a3, BJ_CARD_H
    jal   draw_rect

    # ink color: suits 2-3 (D, H) red, 0-1 (S, C) black
    li    $a0, COLOR_BLACK
    blt   $s3, 2, bdcf_color
    li    $a0, COLOR_RED
bdcf_color:
    jal   set_color

    # rank
    addi  $a1, $s1, 1
    addi  $a2, $s2, 1
    beq   $s0, 9, bdcf_ten          # "10" needs two digits
    li    $a0, GLYPH_A
    beqz  $s0, bdcf_glyph           # rank 0 = ace
    addi  $a0, $s0, 1               # 2-9 -> digits, J/Q/K -> glyphs 11-13
bdcf_glyph:
    jal   draw_glyph
    j     bdcf_suit
bdcf_ten:
    li    $a0, 10
    jal   draw_number

bdcf_suit:
    addi  $a0, $s3, GLYPH_S         # S, C, D, H are glyphs 14-17
    addi  $a1, $s1, 1
    addi  $a2, $s2, 7
    jal   draw_glyph

    lw    $ra,  0($sp)
    lw    $s0,  4($sp)
    lw    $s1,  8($sp)
    lw    $s2, 12($sp)
    lw    $s3, 16($sp)
    addi  $sp, $sp, 20
    jr    $ra

# bj_draw_card_back($a0 = x, $a1 = y): face-down card
bj_draw_card_back:
    addi  $sp, $sp, -12
    sw    $ra, 0($sp)
    sw    $s0, 4($sp)
    sw    $s1, 8($sp)

    move  $s0, $a0
    move  $s1, $a1
    li    $a0, COLOR_BLUE
    jal   set_color
    move  $a0, $s0
    move  $a1, $s1
    li    $a2, BJ_CARD_W
    li    $a3, BJ_CARD_H
    jal   draw_rect
    li    $a0, COLOR_WHITE
    jal   set_color
    move  $a0, $s0
    move  $a1, $s1
    li    $a2, BJ_CARD_W
    li    $a3, BJ_CARD_H
    jal   draw_border

    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    addi  $sp, $sp, 12
    jr    $ra

.include "toolkit.asm"
