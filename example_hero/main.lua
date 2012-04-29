-- ===================================================================================
-- Copyright - KosiDoss Apps (http://kosidossapps.com)
-- License - http://creativecommons.org/publicdomain/zero/1.0/
-- ===================================================================================

application:setBackgroundColor(0x000000)

spriter = Spriter.new("BetaFormatHero.SCML", "example_hero.txt", "example_hero.png")

a = spriter:movieClip("walk", true)
stage:addChild(a)
a:setPosition(150,200)

b = spriter:movieClip("idle_healthy", true)
stage:addChild(b)
b:setPosition(150,400)
