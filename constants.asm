# shared constants: bitmap display is 8x8 units on 512x512 at $gp -> 64x64 grid

.eqv BMP_BASE      0x10008000
.eqv BMP_WIDTH     64
.eqv BMP_HEIGHT    64
.eqv BMP_PIXELS    4096          # 64 * 64

# colors are 0x00RRGGBB
.eqv COLOR_BLACK   0x00000000
.eqv COLOR_WHITE   0x00FFFFFF
.eqv COLOR_RED     0x00FF0000
.eqv COLOR_GREEN   0x0000FF00
.eqv COLOR_BLUE    0x000000FF
.eqv COLOR_YELLOW  0x00FFFF00
.eqv COLOR_GRAY    0x00808080
.eqv COLOR_DKGRAY  0x00202020

# keyboard MMIO
.eqv MMIO_CTRL     0xffff0000    # bit 0 = 1 when a key is ready
.eqv MMIO_DATA     0xffff0004    # ASCII code of the key

# glyph numbers = position in the font table (digits 0-9 are just themselves)
.eqv GLYPH_A       10
.eqv GLYPH_J       11
.eqv GLYPH_Q       12
.eqv GLYPH_K       13
.eqv GLYPH_S       14            # spades
.eqv GLYPH_C       15            # clubs
.eqv GLYPH_D       16            # diamonds
.eqv GLYPH_H       17            # hearts
.eqv GLYPH_COUNT   18            # total glyphs (used for bounds check)
.eqv GLYPH_WIDTH   3
.eqv GLYPH_HEIGHT  5
.eqv GLYPH_SPACING 4             # 3 wide + 1 blank column
