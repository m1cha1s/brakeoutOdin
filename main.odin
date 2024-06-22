package main

import "core:fmt"
import "core:strings"
import "core:log"
import rl "vendor:raylib"
import "core:math/rand"

v2 :: rl.Vector2

WIDTH  :: 800
HEIGHT :: 600

SCORE_SIZE :: 20

MAX_BRICK_COUNT :: 256

BRICK_COLS :: 8
BRICK_ROWS :: 4
BRICK_GAP  :: 5
BRICK_SIZE :: v2{(WIDTH)/BRICK_COLS-BRICK_GAP, HEIGHT/BRICK_ROWS/2-BRICK_GAP}
BRICK_COLOR_MAP :: [BRICK_ROWS]rl.Color{rl.GREEN, rl.YELLOW, rl.ORANGE, rl.RED}

BALL_SIZE  :: 20 
BALL_SPEED :: 150

PADDLE_HEIGHT :: HEIGHT - 40 
PADDLE_SIZE   :: v2{100, 20}
PADDLE_SPEED  :: 300

brick :: struct {
    pos : v2,
    val : i32,
    destroyed : bool,
}

screen :: enum i32 {
    Title,
    GameLoop,
    GameOver,
}

world :: struct {
    score : i32,

    bricks : [MAX_BRICK_COUNT]brick,
    brick_count : i32,

    ball_pos : v2,
    ball_vel : v2,
    ball_col_delay : i32,
    
    paddle_pos : f32,

    s : screen,
}

main :: proc() {
    fmt.println("Balls")

    rl.InitWindow(800, 600, "Brakeout")
    defer rl.CloseWindow()

    rl.SetTargetFPS(75)

    context.user_ptr = init_world()

    for !rl.WindowShouldClose() {
        w := cast(^world)context.user_ptr

        if w.s == screen.GameLoop {
            update_game()
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)

        switch w.s {
        case .Title:
            render_title()
        case .GameLoop:
            render_game()
        case .GameOver:
            render_gameover()
        }

        free_all(context.temp_allocator)
    }
}

update_game :: proc() {
    w : ^world = cast(^world)context.user_ptr

    if w.ball_col_delay > 0 { w.ball_col_delay -= 1 }

    new_paddle_pos := w.paddle_pos
    if rl.IsKeyDown(rl.KeyboardKey.LEFT) && new_paddle_pos > 0{
        new_paddle_pos -= PADDLE_SPEED * rl.GetFrameTime()
    }
    if rl.IsKeyDown(rl.KeyboardKey.RIGHT) && new_paddle_pos+PADDLE_SIZE.x < WIDTH {
        new_paddle_pos += PADDLE_SPEED * rl.GetFrameTime()
    }

    new_ball_pos := w.ball_pos + w.ball_vel * rl.GetFrameTime()
    
    ball_rect := rl.Rectangle{
        x      = w.ball_pos.x-BALL_SIZE,
        y      = w.ball_pos.y-BALL_SIZE,
        width  = 2*BALL_SIZE,
        height = 2*BALL_SIZE
    }
    
    paddle_rect := rl.Rectangle{
        x      = w.paddle_pos,
        y      = PADDLE_HEIGHT,
        width  = PADDLE_SIZE.x,
        height = PADDLE_SIZE.y
    }
    
    if w.ball_col_delay == 0 {
        for &b in w.bricks {
            if b.destroyed { continue }
            
            block_rect := rl.Rectangle{
                x      = b.pos.x,
                y      = b.pos.y,
                width  = BRICK_SIZE.x,
                height = BRICK_SIZE.y
            }
            
            if rl.CheckCollisionRecs(ball_rect, block_rect) {
                re := rl.GetCollisionRec(ball_rect, block_rect)

                b.destroyed = true
                new_ball_pos = w.ball_pos // Reset ball position
                if rand.float32() >= 0.5 { 
                    w.ball_vel.x *= -1 
                } else {
                    w.ball_vel.y *= -1 
                }
                w.ball_col_delay = 3
                w.score += b.val
                break // Only one brick per frame
            }
        }
        
        if rl.CheckCollisionRecs(ball_rect, paddle_rect) {
            new_ball_pos = w.ball_pos // Reset ball position
            w.ball_vel.y *= -1 
            w.ball_col_delay = 3
        }

        // Check wall collisions
        if new_ball_pos.x + BALL_SIZE > WIDTH || new_ball_pos.x - BALL_SIZE < 0 {
            w.ball_vel.x *= -1
        }
        if new_ball_pos.y - BALL_SIZE < 0 {
            w.ball_vel.y *= -1
        }

        // Loss condition
        if new_ball_pos.y + BALL_SIZE > HEIGHT {
            w.s = .GameOver
        }

    }
    
    
    w.ball_pos = new_ball_pos
    w.paddle_pos = new_paddle_pos
}

render_title :: proc() {
    w := cast(^world)context.user_ptr

    rl.DrawText("Press UP", WIDTH/2, HEIGHT/2, 40, rl.WHITE)

    if rl.IsKeyDown(rl.KeyboardKey.UP) {
        w.s = .GameLoop
    }
}

render_gameover :: proc() {
    w := cast(^world)context.user_ptr

    rl.DrawText("Press UP to try again", WIDTH/2-200, HEIGHT/2, 40, rl.WHITE)

    score_str := fmt.tprint("Score:", w.score)
    rl.DrawText(strings.clone_to_cstring(score_str, context.temp_allocator), WIDTH/2, HEIGHT/2-40, 40, rl.WHITE)

    if rl.IsKeyDown(rl.KeyboardKey.UP) {
        init_world(.GameLoop, cast(^world)context.user_ptr)
    }
}

render_game :: proc() {
    w := cast(^world)context.user_ptr

    // Render all the bricks
    for b in w.bricks {
        if b.destroyed { continue }
        render_brick(b)
    }
    
    // Draw the paddle
    r := rl.Rectangle{
        x      = w.paddle_pos,
        y      = PADDLE_HEIGHT,
        width  = PADDLE_SIZE.x,
        height = PADDLE_SIZE.y
    }

    rl.DrawRectangleRounded(r, 0.3, 5, rl.WHITE)

    // Render the ball
    rl.DrawCircleV(w.ball_pos, BALL_SIZE, rl.WHITE)

    render_score()
}

render_score :: proc() {
    w := cast(^world)context.user_ptr

    score_str := fmt.tprint("Score:", w.score)
    rl.DrawText(strings.clone_to_cstring(score_str, context.temp_allocator), 10, HEIGHT-SCORE_SIZE, SCORE_SIZE, rl.WHITE)
}

render_brick :: proc(b: brick) {   
    r := rl.Rectangle{
        x      = b.pos.x,
        y      = b.pos.y,
        width  = BRICK_SIZE.x,
        height = BRICK_SIZE.y
    }

    cm := BRICK_COLOR_MAP

    rl.DrawRectangleRounded(r, 0.5, 5, cm[b.val-1])
}

init_world :: proc(scr: screen = screen.Title, w: ^world = nil) -> ^world {
    w := w
    if w == nil {
        w = new(world, context.allocator)
    }

    i := 0

    w.s = scr
    w.score = 0

    for &b in w.bricks {
        b.destroyed = true
    }

    for x in 0..<BRICK_COLS {
        for y in 0..<BRICK_ROWS {
            w.bricks[i] = brick{
                pos = (BRICK_SIZE + v2{BRICK_GAP, BRICK_GAP}) * v2{cast(f32)x, cast(f32)y},
                val = cast(i32)(BRICK_ROWS-y),
                destroyed = false
            }
            i += 1
        }
    }

    w.ball_pos = v2{WIDTH/2, PADDLE_HEIGHT-BALL_SIZE-5}
    w.ball_vel = v2{BALL_SPEED, -BALL_SPEED}

    w.paddle_pos = WIDTH/2-PADDLE_SIZE.x/2

    return w
}
