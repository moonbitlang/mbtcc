#include "test.h"

// 测试复杂的状态机实现
enum GameState {
    MENU,
    PLAYING,
    PAUSED,
    GAME_OVER
};

struct GameContext {
    enum GameState state;
    int score;
    int lives;
    int level;
    int is_running;
};

void initialize_game(struct GameContext* game) {
    game->state = MENU;
    game->score = 0;
    game->lives = 3;
    game->level = 1;
    game->is_running = 1;
}

void process_menu(struct GameContext* game) {
    printf("=== Game Menu ===\n");
    printf("Score: %d, Lives: %d, Level: %d\n", 
           game->score, game->lives, game->level);
    game->state = PLAYING;
}

void process_playing(struct GameContext* game) {
    printf("Playing game...\n");
    game->score += 10;
    
    if (game->score >= 50) {
        game->level++;
        game->score = 0;
        if (game->level > 3) {
            game->state = GAME_OVER;
            return;
        }
    }
    
    if (game->score % 30 == 0) {
        game->lives--;
        if (game->lives <= 0) {
            game->state = GAME_OVER;
            return;
        }
        game->state = PAUSED;
    }
}

void process_paused(struct GameContext* game) {
    printf("Game paused\n");
    printf("Current status - Score: %d, Lives: %d, Level: %d\n",
           game->score, game->lives, game->level);
    game->state = PLAYING;
}

void process_game_over(struct GameContext* game) {
    printf("Game Over!\n");
    printf("Final score: %d\n", game->score);
    printf("Reached level: %d\n", game->level);
    game->is_running = 0;
}

void run_game_loop(struct GameContext* game) {
    while (game->is_running) {
        switch (game->state) {
            case MENU:
                process_menu(game);
                break;
                
            case PLAYING:
                process_playing(game);
                break;
                
            case PAUSED:
                process_paused(game);
                break;
                
            case GAME_OVER:
                process_game_over(game);
                break;
                
            default:
                printf("Invalid game state!\n");
                game->is_running = 0;
        }
    }
}

int main() {
    struct GameContext game;
    initialize_game(&game);
    run_game_loop(&game);
    
    return 0;
}
