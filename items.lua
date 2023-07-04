-- Weapon consists of a table: { Image, Damage, Range, Cooldown seconds, Critchance % }
Weapons = { hand = { image = nil, damage = 5, range = 250, cooldown = 1, crit = 8 }
          }

Items = {
    empty = { id = 1, type = "empty", image = love.graphics.newImage("assets/empty.png") }, --item index 1
    potionHp = { id = 2, type = "potion", image = love.graphics.newImage("assets/healthPotion.png"), heal = 30, ammount = 1 }, -- item index 2
    potionStrength = { id = 3, type = "potion", image = nil, buff = 1.2, ammount = 1 }
}
