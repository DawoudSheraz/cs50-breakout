--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.balls[0]:generateVelocities()
    self.powerup = Powerup()

    self.keyPowerup = Powerup()
    self.keyPowerup.skin = 10

    self.isLockedBrickPresent = self:checkLockedBricks()
    self.hasPickedKeyPowerup = false
end

function PlayState:update(dt)

    if self:checkPause() then
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.powerup:update(dt)
    self.keyPowerup:update(dt)

    if self.powerup:collides(self.paddle) then
        self.powerup:reset()
        -- Generate two balls after paddle has picked up power up
        for count=1,2 do
            local current_length = #self.balls
            self.balls[current_length+1] = Ball(math.random(7))
            self.balls[current_length+1]:paddleReset(self.paddle)
            self.balls[current_length+1]:generateVelocities()
        end
    end

    -- update that key powerup has been taken by paddle
    if self.keyPowerup:collides(self.paddle) then
        self.keyPowerup:reset()
        self.hasPickedKeyPowerup = true
    end

    -- update each ball and do a paddle collision check
    for idx, ball in pairs(self.balls) do
        ball:update(dt)
        if ball:collides(self.paddle) then
            ball:paddleCollisionUpdate(self.paddle)
            gSounds['paddle-hit']:play()
        end
    end



    for idx, ball in pairs(self.balls) do
        -- detect collision across all bricks with each ball
        for k, brick in pairs(self.bricks) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then
                local hitBrick = true
                
                -- If locked brick present and key has not been hit
                -- no hit functionality will achieve but ball will
                -- bounce back and collision sound will play
                if brick.isLocked and not self.hasPickedKeyPowerup then
                    hitBrick = false
                    ball:postBrickCollision(brick)
                    brick:playCollisionSound()
                end
                
                -- Brick hit should only be done if true
                if hitBrick then

                    -- add to score, +1000 if brick is locked
                    self.score = self.score + (brick.tier * 200 + brick.color * 25 + (brick.isLocked and 1000 or 0))

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- if we have enough points, recover a point of health
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health

                        self.health = math.min(3, self.health + 1)

                        -- If at the full health, then increase the paddle size
                        if self.health == 3 then
                            self.paddle:increase_size()
                        end

                        -- multiply recover points by 2
                        self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            highScores = self.highScores,
                            balls = self.balls,
                            recoverPoints = self.recoverPoints
                        })
                    end

                    ball:postBrickCollision(brick)

                    -- only allow colliding with one brick, for corners
                    break
                end
            end
        end
end


    -- Check if any ball goes below paddle and mark is invisible
    for idx, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            ball.is_visible = false
        end
    end


    -- If no ball is visible, then player missed all of them
    if not self:isAnyBallVisible() then
        self:postBallBelowPaddle()
    else
        -- Remove all the invisible balls
        self:removeInvisibleBalls()
    end

    -- rendering powerup when player at full health and only
    -- one ball is present on the screen alongwith some randomness
    if self.health == 3 and table.size(self.balls) == 1 and math.random(1000) == 10 then
        self.powerup:makeVisible()
    end

    -- Rendering key powerup
    if not self.hasPickedKeyPowerup and self.isLockedBrickPresent and math.random(500) == 10 then
        self.keyPowerup:makeVisible()
    end

    -- If powerup is missed, reset it
    if self.powerup.y >= VIRTUAL_HEIGHT then
        self.powerup:reset()
    end

    -- If key powerup is missed, reset it
    if self.keyPowerup.y >= VIRTUAL_HEIGHT then
        self.keyPowerup:reset()
        self.keyPowerup.skin = 10
    end


    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()

    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    self.powerup:render()
    self.keyPowerup:render()

    for idx, ball in pairs(self.balls) do
        ball:render()
    end


    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end

--[[
    Checking if the game is paused or not
]]
function PlayState:checkPause()
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return true
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return true
    end
    return false
end

--[[
    To be called once the ball(s) are below the paddle
]]
function PlayState:postBallBelowPaddle()
    self.health = self.health - 1
    gSounds['hurt']:play()

    -- Decrease paddle size after the ball has been missed
    self.paddle:decrease_size()

    if self.health == 0 then
        gStateMachine:change('game-over', {
            score = self.score,
            highScores = self.highScores
        })
    else
        gStateMachine:change('serve', {
            paddle = self.paddle,
            bricks = self.bricks,
            health = self.health,
            score = self.score,
            highScores = self.highScores,
            level = self.level,
            recoverPoints = self.recoverPoints
        })
    end
end

--[[
    Check if any ball is visible on the screen or not
]]
function PlayState:isAnyBallVisible()
    for idx, ball in pairs(self.balls) do
        if ball.is_visible then
            return true
        end
    end
    return false
end

--[[
    To remove invisible balls from the table to avoid memory buildup
]]
function PlayState:removeInvisibleBalls()
   for count=table.size(self.balls), 1, -1 do
    local current_val = self.balls[count-1]
        if current_val~=nil and current_val.is_visible == false then
            self.balls[count-1] = nil
        end
   end
end

--[[
    To check if the level has any locked brick
]]
function PlayState:checkLockedBricks()
    
    for idx, brick in pairs(self.bricks) do
        -- Return true on encountering first locked brick
        if brick.isLocked then
            return true
        end
    end
    return false
end
