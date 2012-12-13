-- decision.lua

local event = require("event")
local entity = require("entity")
local input = require("input")

local M = {}

local decisions = {
  skySpawn = {
    prompt = "Sky travellers can now reach Love Hotel, and they want to join the mile high club",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  groundSpawn = {
    prompt = "That cave seems to be letting in other-worldly demons... and they're horny!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  spaceSpawn = {
    prompt = "They came from outer space!",
    options = {
      {
        text = "Okay",
        func = nil,
      },
    },
  },
  burialGround = {
    prompt = "While digging out the new underground floor the work " ..
    "crew discovers an ancient native burial ground filled with " ..
    "gleaming treasures.",
    options = {
      {
        text = "Screw the ghosts, take the treasure.",
        func = function ()
          moneyChange(10000)
          if math.random() < 0.5 then
            reputationChange(-20)
            return("Ghosts!")
          end
          return("No ghosts...")
        end,
      },
      {
        text = "I'm scared, leave the treasure.",
        func = nil,
      },
    },
  },
  zoningPermit = {
    prompt = "Construction of the new top floor has drawn attention " ..
    "from city officials, who demand that you obtain a permit for " ..
    "your new hotel renovations.",
    options = {
      {
        text = "Buy a permit",
        func = function ()
          moneyChange(-2000)
          return("You payed $2000 for a permit.")
        end,
      },
      {
        text = "Bribe the officials",
        func = function ()
          moneyChange(-500)
          reputationChange(-10)
          return("You payed a $500 bribe, but word got out and you lost reputation.")
        end,
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

  if level > 2 and level < 6 then
    if math.random() < 0.5 then
      M.prompt("zoningPermit")
    end
  elseif level < -2 and level > -6 then
    if math.random() < 0.5 then
      M.prompt("burialGround")
    end
  end
end)

return M
