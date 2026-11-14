package main

import "core:math"

CAMERA_DEAD_X :: f32(VIEW_W)*0.25
CAMERA_RISE_LINE :: f32(VIEW_H)*0.50
CAMERA_FALL_LINE :: f32(VIEW_H)*0.85
CAMERA_ANCHOR_Y :: f32(152)
CAMERA_SPRING_X :: f32(50)
CAMERA_DAMPING_X :: f32(12)
CAMERA_SPRING_Y :: f32(24)
CAMERA_DAMPING_Y :: f32(10)
CAMERA_MAX_SPEED_X :: f32(150)
CAMERA_MAX_SPEED_Y :: f32(100)
ROOM_TRANSITION_TIME :: f32(0.45)

CameraState :: struct {
    x, y, vx, vy: f32,
    transitioning: bool,
    elapsed, from_x, from_y, to_x, to_y: f32,
}

clamp_camera :: proc(value, max_value: f32) -> f32 {
    if value < 0 { return 0 }
    if value > max_value { return max_value }
    return value
}

// Call this only at a real room doorway. The current level is continuous.
start_room_transition :: proc(camera: ^CameraState, x, y: f32) {
    camera.transitioning = true
    camera.elapsed = 0
    camera.from_x, camera.from_y = camera.x, camera.y
    camera.to_x = clamp_camera(x, f32(WORLD_W-VIEW_W))
    camera.to_y = clamp_camera(y, f32(WORLD_H-VIEW_H))
    camera.vx, camera.vy = 0, 0
}

spring_axis :: proc(position, velocity, target, stiffness, damping, max_speed, dt: f32) -> (f32, f32) {
    next_velocity := velocity+(target-position)*stiffness*dt
    next_velocity *= math.exp(-damping*dt)
    if next_velocity > max_speed { next_velocity = max_speed }
    if next_velocity < -max_speed { next_velocity = -max_speed }
    next_position := position+next_velocity*dt
    return next_position, next_velocity
}

update_camera :: proc(camera: ^CameraState, player_x, player_y, dt: f32, grounded: bool) {
    if camera.transitioning {
        camera.elapsed += dt
        t := camera.elapsed/ROOM_TRANSITION_TIME
        if t >= 1 { t = 1; camera.transitioning = false }
        eased := t*t*(3-2*t)
        camera.x = camera.from_x+(camera.to_x-camera.from_x)*eased
        camera.y = camera.from_y+(camera.to_y-camera.from_y)*eased
        return
    }

    target_x := camera.x
    screen_x := player_x-camera.x
    left := (f32(VIEW_W)-CAMERA_DEAD_X)*0.5
    right := (f32(VIEW_W)+CAMERA_DEAD_X)*0.5
    if screen_x < left { target_x = player_x-left }
    if screen_x > right { target_x = player_x-right }
    target_x = clamp_camera(target_x, f32(WORLD_W-VIEW_W))
    camera.x, camera.vx = spring_axis(camera.x, camera.vx, target_x, CAMERA_SPRING_X, CAMERA_DAMPING_X, CAMERA_MAX_SPEED_X, dt)

    target_y := camera.y
    screen_y := player_y-camera.y
    if screen_y < CAMERA_RISE_LINE { target_y = player_y-CAMERA_RISE_LINE }
    if screen_y > CAMERA_FALL_LINE { target_y = player_y-CAMERA_FALL_LINE }
    if grounded { target_y = player_y-CAMERA_ANCHOR_Y }
    target_y = clamp_camera(target_y, f32(WORLD_H-VIEW_H))
    camera.y, camera.vy = spring_axis(camera.y, camera.vy, target_y, CAMERA_SPRING_Y, CAMERA_DAMPING_Y, CAMERA_MAX_SPEED_Y, dt)

    max_x := f32(WORLD_W-VIEW_W)
    max_y := f32(WORLD_H-VIEW_H)
    if camera.x < 0 { camera.x = 0; camera.vx = 0 }
    if camera.x > max_x { camera.x = max_x; camera.vx = 0 }
    if camera.y < 0 { camera.y = 0; camera.vy = 0 }
    if camera.y > max_y { camera.y = max_y; camera.vy = 0 }
}
