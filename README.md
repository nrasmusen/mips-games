# MIPS Games

Three playable games written in MIPS assembly for the MARS simulator. They draw on MARS's Bitmap Display and read live keyboard input through memory-mapped I/O.

| Game | Description |
|---|---|
| **Tic-Tac-Toe** | Two players. Pick a box with 1–9, confirm with Enter. The winning line lights up green. |
| **Blackjack** | You vs. the dealer. Hit or stand, aces count as 1 or 11, dealer hits until 17. Tracks wins, losses and pushes. |
| **Snake** | Steer with WASD, eat the food to grow, and don't hit the walls or yourself. Starts with a 3-2-1 countdown. |

All three games are built on one shared toolkit (`toolkit.asm`) for drawing pixels, rectangles, a custom 3×5 pixel font, keyboard input, random numbers and timing. Each game file holds only its own game logic.

## Requirements

- **Java** 8 or newer (MARS is a Java program)
- **MARS 4.5** (`Mars4_5.jar`), available from [Missouri State University](https://computerscience.missouristate.edu/mars-mips-simulator.htm)

## Download

Clone the repo:

```
git clone https://github.com/<your-username>/mips-games.git
```

Or click **Code → Download ZIP** on GitHub and unzip it.

**Keep all five `.asm` files in the same folder.** Each game pulls in `constants.asm` and `toolkit.asm` with `.include`, so the game won't assemble if those files are missing.

```
mips-games/
├── constants.asm   shared settings, colors, key addresses
├── toolkit.asm     shared procedures (drawing, font, input, random, sleep)
├── tictactoe.asm
├── blackjack.asm
└── snake.asm
```

## Running a game

1. **Start MARS.** Double-click `Mars4_5.jar`, or run `java -jar Mars4_5.jar`.

2. **Open a game file** with **File → Open**: `tictactoe.asm`, `blackjack.asm` or `snake.asm`. Don't open `toolkit.asm` or `constants.asm` to run them; they aren't programs on their own.

3. **Open the Bitmap Display** with **Tools → Bitmap Display**. Set it to exactly these values, then click **Connect to MIPS**:

   | Setting | Value |
   |---|---|
   | Unit Width in Pixels | 8 |
   | Unit Height in Pixels | 8 |
   | Display Width in Pixels | 512 |
   | Display Height in Pixels | 512 |
   | Base address for display | 0x10008000 ($gp) |

4. **Open the keyboard** with **Tools → Keyboard and Display MMIO Simulator**, then click **Connect to MIPS**.

5. **Assemble** with **Run → Assemble** (F3), then **run** with **Run → Go** (F5).

6. **Play.** Click inside the lower **KEYBOARD** box of the MMIO Simulator window and type your keys there. Keys typed anywhere else are ignored. Instructions and results print in the **Run I/O** tab at the bottom of MARS.

Both tools stay open between runs. If you close one, reopen it and click **Connect to MIPS** again before running.

## Controls

**Tic-Tac-Toe**

| Key | Action |
|---|---|
| 1–9 | Select a box (it turns yellow). Press another number to change your pick. |
| Enter | Place your mark |
| r | Play again (after a game ends) |
| q | Quit |

Boxes are numbered like a phone keypad: 1 2 3 on top, 7 8 9 on the bottom.

**Blackjack**

| Key | Action |
|---|---|
| h | Hit |
| s | Stand |
| n | Next hand |
| q | Quit |

**Snake**

| Key | Action |
|---|---|
| w / a / s / d | Up / left / down / right. Pressing the direction you came from is ignored. |
| r | Play again (after game over) |
| q | Quit |

You can press a direction during the 3-2-1 countdown to choose which way the snake starts.

## Settings you can change

These are `.eqv` lines near the top of each game file:

- **`SNAKE_DELAY`** in `snake.asm`: milliseconds between moves (default 110). MARS runs slower with both tools connected, so lower it if the snake feels sluggish and raise it if it's too fast.
- **`BJ_SEED`** / **`SNAKE_SEED`**: `0` gives random cards or food. Any other number gives the same cards or food positions every run, which is useful for testing specific situations.

## Troubleshooting

- **Nothing appears on the display.** Check that the base address is `0x10008000 ($gp)` (not the default static data address) and that you clicked **Connect to MIPS**.
- **Keys do nothing.** Make sure the MMIO Simulator is connected and you're typing in its **KEYBOARD** box.
- **"Symbol not found" or include errors.** All five `.asm` files must be in the same folder. If MARS still can't find them, change the `.include` lines to full file paths.
- **Duplicate label errors.** Turn off **Settings → Assemble all files in directory** so MARS assembles only the game you opened.

## How it works (short version)

- **Display:** the screen is a 64×64 grid of "units". Each unit is one word of memory starting at `0x10008000`, and storing a color there colors that square.
- **Keyboard:** MARS maps the keyboard to two addresses. `0xffff0000` says whether a key is waiting and `0xffff0004` holds its ASCII code. Tic-tac-toe and blackjack wait for keys; snake checks once per frame so it keeps moving.
- **Font:** each character is a 3×5 picture stored as 15 bits in a single word, drawn bit by bit.
- **Blackjack deck:** cards are drawn by picking a random slot in the remaining deck, then moving the last card into that slot. A drawn card can't come up again, and no shuffle is needed.
- **Procedures:** everything follows standard MIPS conventions. Arguments go in `$a0–$a3`, results in `$v0/$v1`, and any procedure that calls another saves `$ra` and the `$s` registers it uses on the stack.
