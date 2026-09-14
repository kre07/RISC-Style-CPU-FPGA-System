volatile char *VGA_MEM = (volatile char *)0x80000000; 
volatile int  *GPIO_IN = (volatile int  *)0x80003000; 

#define SCREEN_W 80
#define SCREEN_H 60

int main() {
    int player_x = 35;
    int fruit_x = 20, fruit_y = 0;
    int score = 0;

    while(1) {
        // Read Button (KEY1 is mapped to the 0th bit of our GPIO)
        int button_pressed = *GPIO_IN & 0x1; 
        
        // Move right if pressed, otherwise slowly drift left
        if (button_pressed && player_x < (SCREEN_W - 5)) player_x++;
        else if (player_x > 0) player_x--;

        // Update Fruit
        fruit_y++;
        if (fruit_y >= SCREEN_H) {
            // Check collision with the 5-block wide basket
            if (fruit_x >= player_x && fruit_x <= player_x + 5) score++;
            
            // Reset fruit to top with simple addition/subtraction (No * or % operators)
            fruit_y = 0;
            fruit_x = fruit_x + 17; 
            if (fruit_x >= 75) fruit_x = fruit_x - 70; // Keeps it safely within screen bounds
        }

        // Render Graphics
        for(int i = 0; i < 4800; i++) VGA_MEM[i] = 0; // Clear screen
        
        VGA_MEM[fruit_y * SCREEN_W + fruit_x] = 1; // Draw fruit
        for(int i = 0; i < 5; i++) {
            VGA_MEM[(SCREEN_H - 1) * SCREEN_W + (player_x + i)] = 1; // Draw basket
        }

        // Delay to make the game playable
        for(volatile int d = 0; d < 50000; d++); 
    }
    return 0;
}