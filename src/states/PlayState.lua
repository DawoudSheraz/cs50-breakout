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
    self.balls[0].dx = math.random(-200, 200)
    self.balls[0].dy = math.random(-50, -60)
    self.powerup = Powerup()
end

function PlayState:update(dt)

    if self:checkPause() then
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.powerup:update(dt)

    if self.powerup:collides(self.paddle) then
        self.powerup:reset()
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

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health

                    self.health = math.min(3, self.health + 1)

                    -- self.powerup:makeVisible()
                    
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
                        ball = self.balls[0],
                        recoverPoints = self.recoverPoints
                    })
                end

                ball:postBrickCollision(brick)

                -- only allow colliding with one brick, for corners
                break
            end
        end
end


    -- -- if ball goes below bounds, revert to serve state and decrease health
    for idx, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            
            self.powerup:reset()
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