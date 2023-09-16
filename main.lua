local tiny = require("lib.tiny")
local assets = require("src.Assets")

function love.load()
    Scale = 2
    World = tiny.world(
        require("src.entities.Player"),
        require("src.systems.Drawing"),
        require("src.systems.Movement"),
        require("src.systems.Input")
    )
end

function love.update(dt)
    World:update(dt, tiny.requireAll("updateSystem"))
end

function love.draw()
    World:update(0, tiny.requireAll("drawingSystem"))
end

function love.keypressed(k)
    Input.states.keyboard[k] = true
    if k == "e" then
        love.event.push("keypressed","addEnemy",50,50)
    end
end
function love.keyreleased(k)
    Input.states.keyboard[k] = false
end
function love.mousepressed(x,y,b)
    if b == 1 then
        require("src.systems.SpawnBullet").newBullet(x,y)
        love.event.push("mousepressed","addBullet",x,y)
    end
end

Input = {
    states = {
        keyboard = {}
    },
    bindings = require("src.Keybindings")
}
