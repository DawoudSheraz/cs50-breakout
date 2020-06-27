--[[
    Powerup Class

    This will contain the code for powerup that is going to spawn randomly during a 
    level.
]]

Powerup = Class{}

function Powerup:init()

    self.width = 16
    self.height = 16

    -- Starting position
    self.x = math.random(VIRTUAL_WIDTH/2 - 50, VIRTUAL_WIDTH/2 + 50)
    self.y = VIRTUAL_HEIGHT/2

    -- Generate a random dy for power up
    self.dy = math.random(50, 80)

    -- Give default skin of double ball powerup
    self.skin = 9

    -- If the power up should be visible
    self.is_visible = false
end

--[[
    update the power up y position
]]
function Powerup:update(dt)
    if self.is_visible then
        self.y = self.y + self.dy * dt
    end
end

--[[
    Reset the powerup position and generate a random skin
]]
function Powerup:reset()
    self.x = math.random(VIRTUAL_WIDTH/2 - 50, VIRTUAL_WIDTH/2 + 50)
    self.y = VIRTUAL_HEIGHT/2
    self.dy = math.random(50, 80)
    self.skin = 9
    self.is_visible = false
end

--[[
    Make render condition True
]]
function Powerup:makeVisible()
    self.is_visible = true
end

-- Renders the power up
function Powerup:render()
    if self.is_visible then
        love.graphics.draw(gTextures['main'], gFrames['powerup'][self.skin-1], self.x, self.y)
    end
end

--[[
    Check if the powerup has collided with paddle(target) using AABB collision
]]
function Powerup:collides(target)
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    return true
end
