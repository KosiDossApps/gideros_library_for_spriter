-- ===================================================================================
-- Copyright - KosiDoss Apps (http://kosidossapps.com)
-- License - http://creativecommons.org/publicdomain/zero/1.0/
-- ===================================================================================

-- Change background color
application:setBackgroundColor(0x000000)

-- Setup sprites/animations and various other 
local hero = Sprite.new()
stage:addChild(hero)

local spriter  = Spriter.new("BetaFormatHero.SCML", "example_hero.txt", "example_hero.png")
local walking  = spriter:movieClip("walk", true)
local idle     = spriter:movieClip("idle_healthy", true)

hero:addChild(idle)
local width    = math.ceil(hero:getWidth())
local height   = math.ceil(hero:getHeight())
hero:setPosition(width/2,height)

local isIdle   = true
local velocity = 6
local dest     = { x=width/2, y=height, velocity=velocity }

-- Set up pubnub
require "pubnub"
multiplayer = pubnub.new({
    publish_key   = "demo",
    subscribe_key = "demo",
    secret_key    = nil,
    ssl           = nil,
    origin        = "pubsub.pubnub.com"
})

-- Set destination based on received pubnub messages
multiplayer:subscribe({
    channel  = "gideros-hero-example",
    callback = function(message)
       dest = { 
          x=(tonumber(message.x) or dest.x), 
          y=(tonumber(message.y) or dest.y), 
          velocity=(tonumber(message.velocity) or dest.velocity) 
       }
    end,
    errorback = function()
       print("Oh no!!! Dropped conection!")
    end
})

-- Set pubnub message on mouse events
local function onMouse(event)
   multiplayer:publish{
      channel = "gideros-hero-example",
      message = { x=math.ceil(event.x), y=math.ceil(event.y), velocity=velocity }
   }
end
stage:addEventListener(Event.MOUSE_UP,   onMouse)
stage:addEventListener(Event.MOUSE_DOWN, onMouse)
stage:addEventListener(Event.MOUSE_MOVE, onMouse)
 
-- Move hero toward destination
local function onEnterFrame()
   local x = hero:getX()
   local y = hero:getY()
   if x == dest.x and y == dest.y then
      if not isIdle then
         hero:removeChild(walking)
         hero:addChild(idle)
         isIdle = true
      end
   else
      if isIdle then
         hero:removeChild(idle)
         hero:addChild(walking)
         isIdle = false
      end
      if not (x == dest.x) then
         if x < dest.x then
            hero:setScaleX(1)
            x = x + math.min(dest.velocity,dest.x-x)
         else
            hero:setScaleX(-1)
            x = x - math.min(dest.velocity,x-dest.x)
         end
      end
      if not (y == dest.y) then
         if y < dest.y then
            y = y + math.min(dest.velocity,dest.y-y)
         else
            y = y - math.min(dest.velocity,y-dest.y)
         end
      end
      hero:setPosition(x,y)
   end
end
stage:addEventListener(Event.ENTER_FRAME, onEnterFrame)

