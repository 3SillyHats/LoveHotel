-- decision.lua

local event = require("event")
local entity = require("entity")
local input = require("input")

local M = {}

local decisions = {
  skySpawn = {
    prompt = "Sky travellers can now reach Love Hotel, and they want to join the mile high club.",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  groundSpawn = {
    prompt = "The cave seems to be letting in other-worldly demons... and they're horny!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  spaceSpawn = {
    prompt = "Starfarers are arriving at Love Hotel - make sure that they spend all of that space cash!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  star1 = {
    prompt = "You are the manager of Love Hotel. To turn it into the best romantic" ..
    " hotel in the world, you will need to earn money and gain all five stars by satisfying" ..
    " your clients needs.",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  star2 = {
    prompt = "Love Hotel is now a two star establishment! You can now buy" ..
    " condom machines and build a new themed suite.",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  star3 = {
    prompt = "Good work reaching three stars! You can now buy" ..
    " dining rooms and kitchens, hire cooks, and build a new themed suite." ..
    " But people will be upset if they run out of condoms!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  star4 = {
    prompt = "Four stars - you're nearly there! You can now hire a stocker, " ..
    "buy a freezer, andbuild a new themed suite." ..
    " People expect food and will be upset if they leave hungry!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  star5 = {
    prompt = "Congratulations! Love Hotel is now a five-star resort." ..
    " You can now build spas and the final themed suite, but you have already" ..
    " won so you shouldn't feel bad if you just leave now. Have a lovely day.",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
}

-- Create and reuse the same decision menu entity
local decisionMenu = entity.new(STATE_DECISION)
local decisionCom = entity.newComponent({
  decision = nil,
  selected = nil,
  result = nil,
  
  draw = function (self)
    love.graphics.setFont(gFont)
    love.graphics.setColor(255, 255, 255)
    
    if self.result then
      love.graphics.printf(
        self.result,
        8, 96,
        240,
        "center"
        )
    else
      love.graphics.printf(
      self.decision.prompt,
      8, 32,
      240,
      "center"
      )
  
      for i,option in ipairs(self.decision.options) do
        if i == self.selected then
          love.graphics.setColor(255, 255, 255)
        else
          love.graphics.setColor(89, 89, 89)
        end
        love.graphics.printf(
          option.text,
          8, 128 + (16 * i),
          240,
          "center"
        )
      end
    end
  end,
})
entity.addComponent(decisionMenu, decisionCom)

-- Bring up the decision screen
M.prompt = function (decision)
  decisionCom.decision = decisions[decision]
  decisionCom.selected = 1
  decisionCom.result = nil
  event.notify("state.enter", 0, STATE_DECISION)
end
event.subscribe("decision.prompt", 0, function (e)
  M.prompt(e.decision)
end)

-- Handle input on decision screen
event.subscribe("pressed", 0, function (button)
  if gState == STATE_DECISION then
    if button == "a" then
      if decisionCom.result then
        event.notify("state.enter", 0, STATE_PLAY)
      else
        local func = decisionCom.decision.options[decisionCom.selected].func
        if func then
          decisionCom.result = func()
        end
        if not decisionCom.result then
          event.notify("state.enter", 0, STATE_PLAY)
        end
      end
    elseif button == "up" then
      decisionCom.selected = math.max(1, decisionCom.selected - 1)
    elseif button == "down" then
      decisionCom.selected = math.min(#decisionCom.decision.options,
          decisionCom.selected + 1)
    end
    return true
  end
end)

-- Setup some handlers to prompt decisions
local topStar = 0
event.subscribe("stars", 0, function (stars)
  if stars > topStar then
    topStar = stars
    M.prompt("star" .. topStar)
  end
end)
event.subscribe("floor.new", 0, function (level)
  if level == SKY_SPAWN then
    M.prompt("skySpawn")
    return
  elseif level == GROUND_SPAWN then
    M.prompt("groundSpawn")
    return
  elseif level == SPACE_SPAWN then
    M.prompt("spaceSpawn")
    return
  end
end)

return M
