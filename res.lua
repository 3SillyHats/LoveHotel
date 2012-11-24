-- res.lua

local M = {}

local resources = {}

local findPattern = function (text, pattern, start)
    return string.sub(text, string.find(text, pattern, start))
end

local loadRes = {}
loadRes[".png"] = love.graphics.newImage
loadRes[".wav"] = function (name)
  love.audio.newSource(name, "static")
end
loadRes[".mp3"] = function (name)
  love.audio.newSource(name, "streaming")
end
loadRes[".glsl"] = function (name)
  pixelEffect = nil
  local success, result = pcall(function ()
    return love.graphics.newPixelEffect(
        love.filesystem.read(name)
    )
  end)
  if success then
    pixelEffect = result
  end
  return pixelEffect
end

M.get = function (name)
  if not resources[name] then
    local extension = findPattern(name, "\.[^.]+$")
    resources[name] = loadRes[extension]("res/" .. name)
  end
  return resources[name]
end


return M
