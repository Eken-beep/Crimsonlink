return {
    bullet = true,
    position = {x=0,y=0},
    velocity = {x=0,y=0},
    hitbox   = {w=10,h=10},
    sprite = love.graphics.newImage("assets/crosshair.png"),
    damage = 10,
    parentIsPlayer = nil,

    time = 0,
    lifetime = 3
}
