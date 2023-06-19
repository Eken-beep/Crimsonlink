function MapDrawer()
    for i,v in ipairs(Currentmap.layers) do
        if v.type == "tilelayer" then
            Currentmap:drawLayer(v)
        end
    end
end

function InstantiateMap(map)
    Currentmap = map
    World = Bump.newWorld(32*Scale)
    map:bump_init(World)
    -- Create pairs of points where edge shapes should be drawn between
    --local px = map.layers[#map.layers].objects[1].x
    --local py = map.layers[#map.layers].objects[1].y
    World:add(Player, Scale*(MapXOffset+60*32)/2, Scale*(MapYOffset+33*32)/2, Player.character:getWidth(), Player.character:getHeight())
end
