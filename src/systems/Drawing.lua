local tiny = require("lib.tiny")

local drawingSystem = tiny.processingSystem()
drawingSystem.filter = tiny.filter("position&(animation|sprite)")
drawingSystem.drawingSystem = true

function drawingSystem:process(e)
    if e.animation then
        love.graphics.draw(e.animation[1], e.position.x, e.position.y)
    else
        love.graphics.draw(e.sprite, e.position.x, e.position.y)
    end
    if e.hitbox and DrawHitboxes then
        love.graphics.rectangle("line",e.position.x,e.position.y,e.hitbox.w,e.hitbox.h)
    end
end

return drawingSystem
