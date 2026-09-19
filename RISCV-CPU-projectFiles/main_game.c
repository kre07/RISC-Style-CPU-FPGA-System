/*
 * Fruit Catcher - bare-metal game logic for the custom RV32I CPU
 * running on the DE10-Lite FPGA.
 *
 * This is the human-readable C equivalent of the current game program
 * stored in game_words.hex.
 *
 * Architecture:
 *   - The custom CPU executes the game logic.
 *   - soc_top.v renders the title screen, fruits, basket, score and lives.
 *   - The CPU communicates with soc_top.v through memory-mapped registers.
 *
 * Controls:
 *   KEY[1] = move basket RIGHT
 *   KEY[0] = move basket LEFT
 *   No button / both buttons = stop
 *   On the intro screen, either button starts the game.
 *
 * Rules:
 *   - Three fruits fall at the same time from different heights.
 *   - Catching a fruit adds 1 point and resets the miss streak.
 *   - Three consecutive misses = game over.
 *   - On game over, score resets to 0 and the title screen returns.
 */

typedef unsigned int u32;

/* ---------------------------------------------------------
 * Memory-mapped I/O
 * --------------------------------------------------------- */

/* Buttons:
 * bit 0 = RIGHT button
 * bit 1 = LEFT button
 */
#define GPIO_BUTTONS   (*(volatile u32 *)0x80003000u)

/* Game-state registers consumed by soc_top.v */
#define REG_SCORE      (*(volatile u32 *)0x80004000u)
#define REG_LIVES      (*(volatile u32 *)0x80004004u)
#define REG_STATE      (*(volatile u32 *)0x80004008u)
#define REG_BASKET_X   (*(volatile u32 *)0x8000400Cu)

#define REG_FRUIT1_X   (*(volatile u32 *)0x80004010u)
#define REG_FRUIT1_Y   (*(volatile u32 *)0x80004014u)

#define REG_FRUIT2_X   (*(volatile u32 *)0x80004018u)
#define REG_FRUIT2_Y   (*(volatile u32 *)0x8000401Cu)

#define REG_FRUIT3_X   (*(volatile u32 *)0x80004020u)
#define REG_FRUIT3_Y   (*(volatile u32 *)0x80004024u)


/* ---------------------------------------------------------
 * Game constants
 * --------------------------------------------------------- */

#define BUTTON_RIGHT       0x1u
#define BUTTON_LEFT        0x2u

#define GAME_INTRO         0u
#define GAME_PLAYING       1u

#define BASKET_SPEED       2
#define BASKET_MIN_X       0
#define BASKET_MAX_X       68
#define BASKET_CATCH_W     12

#define FRUIT_GROUND_Y     56
#define FRUIT_RESPAWN_Y    8

#define MAX_SCORE          100
#define MAX_LIVES          3

/* Larger value = slower fruit movement. */
#define GAME_DELAY_COUNT   0x20000u


/* ---------------------------------------------------------
 * Game data
 * --------------------------------------------------------- */

typedef struct {
    int x;
    int y;
} Fruit;


/* ---------------------------------------------------------
 * Hardware/game helpers
 * --------------------------------------------------------- */

static inline void delay_game(void)
{
    volatile u32 count = GAME_DELAY_COUNT;

    while (count != 0u) {
        count--;
    }
}


static inline void publish_state(
    int score,
    int lives,
    int basket_x,
    Fruit fruit1,
    Fruit fruit2,
    Fruit fruit3
)
{
    REG_SCORE    = (u32)score;
    REG_LIVES    = (u32)lives;
    REG_STATE    = GAME_PLAYING;
    REG_BASKET_X = (u32)basket_x;

    REG_FRUIT1_X = (u32)fruit1.x;
    REG_FRUIT1_Y = (u32)fruit1.y;

    REG_FRUIT2_X = (u32)fruit2.x;
    REG_FRUIT2_Y = (u32)fruit2.y;

    REG_FRUIT3_X = (u32)fruit3.x;
    REG_FRUIT3_Y = (u32)fruit3.y;
}


/*
 * Move a fruit to a new horizontal position after it reaches
 * the bottom. This matches the position sequence used by the
 * current game_words.hex:
 *
 *      x = x + 17
 *      if x >= 69, x = x - 60
 */
static inline int next_fruit_x(int x)
{
    x += 17;

    if (x >= 69) {
        x -= 60;
    }

    return x;
}


/*
 * Returns 1 if the game ended, otherwise 0.
 *
 * A catch:
 *   - score + 1
 *   - reset lives/miss streak back to 3
 *
 * A miss:
 *   - lives - 1
 *   - third consecutive miss = game over
 */
static inline int process_landed_fruit(
    Fruit *fruit,
    int basket_x,
    int *score,
    int *lives
)
{
    int caught;

    /*
     * The rendered fruit is roughly two logical cells wide.
     * The basket catch region is 12 logical cells wide.
     */
    caught =
        ((fruit->x + 1) >= basket_x) &&
        (fruit->x < (basket_x + BASKET_CATCH_W));

    if (caught) {
        /* Any catch completely resets the consecutive-miss streak. */
        *lives = MAX_LIVES;

        *score = *score + 1;

        if (*score >= MAX_SCORE) {
            *score = 0;
        }
    }
    else {
        *lives = *lives - 1;

        if (*lives == 0) {
            return 1;
        }
    }

    fruit->x = next_fruit_x(fruit->x);
    fruit->y = FRUIT_RESPAWN_Y;

    return 0;
}


/* ---------------------------------------------------------
 * Main game
 * --------------------------------------------------------- */

int main(void)
{
    int score;
    int lives;
    int basket_x;

    Fruit fruit1;
    Fruit fruit2;
    Fruit fruit3;

    u32 buttons;

    for (;;) {

        /* -----------------------------------------------
         * INTRO / TITLE SCREEN
         * ----------------------------------------------- */

        score = 0;
        lives = MAX_LIVES;

        REG_STATE = GAME_INTRO;
        REG_SCORE = 0;
        REG_LIVES = MAX_LIVES;

        /*
         * Wait until either button is pressed.
         * soc_top.v displays "FRUIT CATCHER" and "PRESS START".
         */
        do {
            buttons = GPIO_BUTTONS & 0x3u;
        } while (buttons == 0u);

        /*
         * Wait for the player to release the button before
         * beginning. This prevents the start press from also
         * moving the basket immediately.
         */
        do {
            buttons = GPIO_BUTTONS & 0x3u;
        } while (buttons != 0u);


        /* -----------------------------------------------
         * NEW GAME
         * ----------------------------------------------- */

        basket_x = 35;

        /* Three fruits begin at different X/Y positions. */
        fruit1.x = 10;
        fruit1.y = 8;

        fruit2.x = 36;
        fruit2.y = 23;

        fruit3.x = 62;
        fruit3.y = 38;

        score = 0;
        lives = MAX_LIVES;

        REG_STATE = GAME_PLAYING;


        /* -----------------------------------------------
         * GAME LOOP
         * ----------------------------------------------- */

        for (;;) {

            /* -------------------------------------------
             * BASKET MOVEMENT
             *
             * RIGHT only -> move right
             * LEFT only  -> move left
             * neither/both -> stop
             * ------------------------------------------- */

            buttons = GPIO_BUTTONS & 0x3u;

            if ((buttons & BUTTON_RIGHT) &&
                !(buttons & BUTTON_LEFT)) {

                basket_x += BASKET_SPEED;

                if (basket_x > BASKET_MAX_X) {
                    basket_x = BASKET_MAX_X;
                }
            }
            else if ((buttons & BUTTON_LEFT) &&
                     !(buttons & BUTTON_RIGHT)) {

                basket_x -= BASKET_SPEED;

                if (basket_x < BASKET_MIN_X) {
                    basket_x = BASKET_MIN_X;
                }
            }


            /* -------------------------------------------
             * MOVE ALL THREE FRUITS DOWN
             * ------------------------------------------- */

            fruit1.y++;
            fruit2.y++;
            fruit3.y++;


            /* -------------------------------------------
             * FRUIT 1
             * ------------------------------------------- */

            if (fruit1.y >= FRUIT_GROUND_Y) {

                if (process_landed_fruit(
                        &fruit1,
                        basket_x,
                        &score,
                        &lives)) {

                    break;
                }
            }


            /* -------------------------------------------
             * FRUIT 2
             * ------------------------------------------- */

            if (fruit2.y >= FRUIT_GROUND_Y) {

                if (process_landed_fruit(
                        &fruit2,
                        basket_x,
                        &score,
                        &lives)) {

                    break;
                }
            }


            /* -------------------------------------------
             * FRUIT 3
             * ------------------------------------------- */

            if (fruit3.y >= FRUIT_GROUND_Y) {

                if (process_landed_fruit(
                        &fruit3,
                        basket_x,
                        &score,
                        &lives)) {

                    break;
                }
            }


            /*
             * Send the latest CPU-controlled game state to
             * soc_top.v so the VGA renderer can draw it.
             */
            publish_state(
                score,
                lives,
                basket_x,
                fruit1,
                fruit2,
                fruit3
            );


            /* Controls how quickly the fruits fall. */
            delay_game();
        }


        /* -----------------------------------------------
         * GAME OVER
         *
         * Three consecutive misses.
         * Reset score and return to the intro screen.
         * ----------------------------------------------- */

        score = 0;
        lives = MAX_LIVES;

        REG_SCORE = 0;
        REG_LIVES = MAX_LIVES;
        REG_STATE = GAME_INTRO;
    }

    /* Bare-metal program should never reach this point. */
    return 0;
}
