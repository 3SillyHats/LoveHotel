function love.conf(t)
    t.title = "Love Hotel"
    t.author = "3 Silly Hats"
    t.url = "http://3sillyhats.com/lovehotel"
    t.identity = "lovehotel"
    t.version = "0.8.0"
    t.console = false
    t.release = true
    t.screen.width = 256
    t.screen.height = 224
    t.screen.fullscreen = true
    t.screen.vsync = true
    t.screen.fsaa = 0
    t.modules.joystick = true
    t.modules.audio = true
    t.modules.keyboard = true
    t.modules.event = true
    t.modules.image = true
    t.modules.graphics = true
    t.modules.timer = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.physics = false
end
