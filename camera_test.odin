package main

import "core:testing"

@test
camera_dead_zone_and_bounds :: proc(t: ^testing.T) {
    camera := CameraState{y = 80}
    update_camera(&camera, 180, 232, PHYSICS_DT, true)
    testing.expect(t, camera.x == 0 && camera.y == 80)
    for _ in 0..<120 { update_camera(&camera, 700, 290, PHYSICS_DT, false) }
    testing.expect(t, camera.x <= f32(WORLD_W-VIEW_W))
    testing.expect(t, camera.y <= f32(WORLD_H-VIEW_H))
}

@test
camera_room_transition :: proc(t: ^testing.T) {
    camera := CameraState{y = 80}
    start_room_transition(&camera, 150, 80)
    update_camera(&camera, 310, 232, PHYSICS_DT, true)
    testing.expect(t, camera.transitioning && camera.x > 0 && camera.x < 150)
    for _ in 0..<30 { update_camera(&camera, 310, 232, PHYSICS_DT, true) }
    testing.expect(t, !camera.transitioning)
    testing.expect(t, camera.x > 140 && camera.x <= 150)
    update_camera(&camera, 290, 232, PHYSICS_DT, true)
    testing.expect(t, !camera.transitioning)
}

@test
camera_waits_for_high_jump :: proc(t: ^testing.T) {
    camera := CameraState{y = 80}
    for _ in 0..<30 { update_camera(&camera, 180, 190, PHYSICS_DT, false) }
    testing.expect(t, camera.y == 80)
    update_camera(&camera, 180, 160, PHYSICS_DT, false)
    testing.expect(t, camera.y < 80)
    for _ in 0..<90 { update_camera(&camera, 180, 232, PHYSICS_DT, true) }
    testing.expect(t, camera.y > 79 && camera.y <= 80)
}

@test
camera_continuous_level_has_no_auto_transition :: proc(t: ^testing.T) {
    camera := CameraState{y = 80}
    update_camera(&camera, 299, 232, PHYSICS_DT, true)
    before := camera.x
    update_camera(&camera, 301, 232, PHYSICS_DT, true)
    testing.expect(t, !camera.transitioning)
    testing.expect(t, camera.x-before <= CAMERA_MAX_SPEED_X*PHYSICS_DT)
}
