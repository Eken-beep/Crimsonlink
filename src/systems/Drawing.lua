local tiny = require("lib.tiny")

local drawingSystem = tiny.processingSystem()
drawingSystem.filter = tiny.filter("position&(animation|sprite)")
function drawingSystem:process(e)
    if e.animation then
        love.graphics.draw(e.animation[1], e.position.x, e.position.y)
    else
        love.graphics.draw(e.sprite, e.position.x, e.position.y)
    end
end

return drawingSystem
