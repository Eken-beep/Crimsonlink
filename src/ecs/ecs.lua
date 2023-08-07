-- World is just an array of entities, numbered, and each entity has named components
World = {}
-- Should be strings mapped to default values
World.components = {}
-- Should be an array of entities where each entity is like the component store
World.entities = {}
-- Should be a table of strings mapped to functions that take any single or multiple entities as values
World.systems = {}
-- Like an entity but can be global
World.global = {}

local function elemAll(e,c)
    local elems = {}
    for _,k in ipairs(c) do
        if e[k] then table.insert(elems,e[k]) end
    end
    return elems
end

-- Takes a system and a table of components, applies system
function Cmap(system, components)
    for _,entity in ipairs(World.entities) do
        if elemAll(entity,components) == components then
            system(entity)
        end
    end
end

function World.entities:add(components)
    local fromCstore = {}
    for _,v in pairs(components) do
        if World.components[v] then
            table.insert(fromCstore, World.components[v])
        end
    end
    if fromCstore ~= {} then table.insert(self,fromCstore) end
end

function World.global:add(component,value)
    self[component] = value
end

function World.components:add(name,defaultValue)
    self[name] = defaultValue
end

-- Where entities is a table of tables of components, each  subtable is one entity onto itself
-- Systems should be a table of named functions simply
function World:create(components, entities, systems)
    self.components = components
    for _,v in ipairs(entities) do
        World.entities:add(v)
    end
    self.systems = systems
end
