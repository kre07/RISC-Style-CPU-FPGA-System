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


// PART 1: Memory-mapped I/O - lets the CPU access hardware using addresses
// volatile ensures hardware reads/writes aren't optimized away
typedef unsigned int u32;



#define GPIO_BUTTONS   (*(volatile u32 *)0x80003000u)

// Game-state registers used by soc_top.v
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


// PART 2: Game constants
// 0x1 = binary 01 (right), 0x2 = binary 10 (left)
// Each button uses a different bit so we can check them separately
#define BUTTON_RIGHT       0x1u
#define BUTTON_LEFT        0x2u

// Game states: 0 = intro screen, 1 = playing

// Basket moves 2 position units per update
#define BASKET_SPEED       2    

// Furthest left the basket can move
#define BASKET_MIN_X       0   

// Furthest right the basket can move
#define BASKET_MAX_X       68   

// Width of the basket's catching area
#define BASKET_CATCH_W     12   

// Y position where the fruit reaches the ground
#define FRUIT_GROUND_Y     56   

 // Y position where the fruit respawns
#define FRUIT_RESPAWN_Y    8   

// Score resets when it reaches 100
#define MAX_SCORE          100  

// Three consecutive misses end the game
#define MAX_LIVES          3    

// Larger delay = slower fruit movement
#define GAME_DELAY_COUNT   0x20000u


// Stores the X and Y position of each fruit
typedef struct {
    int x;
    int y;
} Fruit;


// Creates a delay between game updates
static inline void delay_game(void)
{
    volatile u32 count = GAME_DELAY_COUNT;

    while (count != 0u) {
        count--;
    }
}


// Sends updated game values to the FPGA hardware
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


// Calculates a new X position when a fruit respawns
static inline int next_fruit_x(int x)
{
    x += 17;

    if (x >= 69) {
        x -= 60;
    }

    return x;
}


// Checks whether a fruit was caught or missed
// Uses pointers to update the original fruit, score and lives variables
// Returns 1 for game over, 0 to continue
static inline int process_landed_fruit(
    Fruit *fruit,
    int basket_x,
    int *score,
    int *lives
)
{
    int caught;

    // Check if the fruit overlaps the basket
    // -> accesses a struct member through a pointer
    caught =
        ((fruit->x + 1) >= basket_x) &&
        (fruit->x < (basket_x + BASKET_CATCH_W));

    if (caught) {
        // Caught: increase score and reset consecutive misses
        *lives = MAX_LIVES;
        *score = *score + 1;

        if (*score >= MAX_SCORE) {
            *score = 0;
        }
    }
    else {
        // Missed: decrease remaining lives
        *lives = *lives - 1;

        if (*lives == 0) {
            return 1;
        }
    }

    // Respawn the fruit at a new position
    fruit->x = next_fruit_x(fruit->x);
    fruit->y = FRUIT_RESPAWN_Y;

    return 0;
}


// Main game loop
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

        // Intro screen - reset values and wait for start
        score = 0;
        lives = MAX_LIVES;

        REG_STATE = GAME_INTRO;
        REG_SCORE = 0;
        REG_LIVES = MAX_LIVES;

        // Wait until either button is pressed
        // & 0x3u keeps only the lowest two button bits
        do {
            buttons = GPIO_BUTTONS & 0x3u;
        } while (buttons == 0u);

        // Wait for button release before starting
        do {
            buttons = GPIO_BUTTONS & 0x3u;
        } while (buttons != 0u);


        // New game - set starting positions
        basket_x = 35;

        fruit1.x = 10;
        fruit1.y = 8;

        fruit2.x = 36;
        fruit2.y = 23;

        fruit3.x = 62;
        fruit3.y = 38;

        score = 0;
        lives = MAX_LIVES;

        REG_STATE = GAME_PLAYING;


        // Game runs continuously until game over
        for (;;) {

            // Read the button states
            buttons = GPIO_BUTTONS & 0x3u;

            // Move right only if right is pressed
            if ((buttons & BUTTON_RIGHT) &&
                !(buttons & BUTTON_LEFT)) {

                basket_x += BASKET_SPEED;

                // Keep basket within the right boundary
                if (basket_x > BASKET_MAX_X) {
                    basket_x = BASKET_MAX_X;
                }
            }
            // Move left only if left is pressed
            else if ((buttons & BUTTON_LEFT) &&
                     !(buttons & BUTTON_RIGHT)) {

                basket_x -= BASKET_SPEED;

                // Keep basket within the left boundary
                if (basket_x < BASKET_MIN_X) {
                    basket_x = BASKET_MIN_X;
                }
            }


            // Move all three fruits downward
            fruit1.y++;
            fruit2.y++;
            fruit3.y++;


            // Check if fruit 1 reached the bottom
            if (fruit1.y >= FRUIT_GROUND_Y) {

                // & passes the address so the original variables can change
                if (process_landed_fruit(
                        &fruit1,
                        basket_x,
                        &score,
                        &lives)) {

                    break;  // Exit game loop if game over
                }
            }


            // Check fruit 2
            if (fruit2.y >= FRUIT_GROUND_Y) {

                if (process_landed_fruit(
                        &fruit2,
                        basket_x,
                        &score,
                        &lives)) {

                    break;
                }
            }


            // Check fruit 3
            if (fruit3.y >= FRUIT_GROUND_Y) {

                if (process_landed_fruit(
                        &fruit3,
                        basket_x,
                        &score,
                        &lives)) {

                    break;
                }
            }


            // Update the hardware registers used by the VGA graphics
            publish_state(
                score,
                lives,
                basket_x,
                fruit1,
                fruit2,
                fruit3
            );

            // Slow down the game before the next update
            delay_game();
        }


        // Game over - reset score and return to intro screen
        score = 0;
        lives = MAX_LIVES;

        REG_SCORE = 0;
        REG_LIVES = MAX_LIVES;
        REG_STATE = GAME_INTRO;
    }

    return 0;
}
