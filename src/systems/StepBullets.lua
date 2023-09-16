local tiny = require("lib.tiny")

local stepBullets = tiny.system()
stepBullets.updateSystem = true
stepBullets.filter = tiny.requireAll("bullet", "time")

function stepBullets.update(e,dt)
    if e.time then
        e.time = e.time + dt
        if e.time > 3 then
            tiny.removeEntity(World,e)
        end
    end
end

return stepBullets
