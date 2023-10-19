local assets = require("src.Assets")
local player = {
    position = {x=0,y=0},
    velocity = {x=0,y=0},
    health = {hp = 100, maxHp = 100},
    hitbox = {w=32,h=51,center={x=16,y=25}},
    inventory = {},
    animation = assets.playerAnimation,
    movementspeed = 100,

    collidable = true,
    alive = true,
    controllable = true
}

return player
