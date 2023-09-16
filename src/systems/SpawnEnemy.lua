local tiny = require("lib.tiny")
local assets = require("src.Assets")

local spawnEnemy = tiny.processingSystem()
spawnEnemy.filter = tiny.requireAll("controllable")
spawnEnemy.updateSystem = true

function spawnEnemy:process(e)
    for i,v in ipairs(Events) do
        if v() == "addEnemy" then
            print("enemy added")
            tiny.addEntity(World, setmetatable({
                position = {x=v.x, y=v.y}
            },{__index = require("src.entities.Enemy")}))
            table.remove(Events,i)
        end
    end
end

return spawnEnemy
