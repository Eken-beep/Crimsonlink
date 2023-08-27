local tiny = require("lib.tiny")
local assets = require("src.Assets")

function love.load()
    Scale = 2
    World = tiny.world(
        require("src.entities.Player"),
        require("src.systems.Drawing"),
        require("src.systems.Movement")
    )
end

function love.update(dt)
    World:update(dt)
end

function love.draw()
    World:update(0)
end
