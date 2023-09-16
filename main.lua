local tiny = require("lib.tiny")
local assets = require("src.Assets")

function love.load()
    Scale = 2
    Events = {}
    World = tiny.world(
        require("src.entities.Player"),
        require("src.systems.Drawing"),
        require("src.systems.Movement"),
        require("src.systems.Input"),
        require("src.systems.SpawnEnemy"),
        require("src.systems.SpawnBullet")
    )
end

local function addEvent(name,args)
    args.name = name
    table.insert(Events,setmetatable(args,{
        __call = function(t)
            return t.name
        end
    }))
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
        addEvent("addEnemy", {x=50, y=50})
        print("tried to add enemy")
    end
end

function love.keyreleased(k)
    Input.states.keyboard[k] = false
end
function love.mousepressed(x,y,b)
    if b == 1 then
        addEvent("addBullet",{x=x,y=y})
    end
end

Input = {
    states = {
        keyboard = {}
    },
    bindings = require("src.Keybindings")
}
