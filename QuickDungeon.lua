-- QuickDungeon by Steve Mattsen
-- Version 0.1.5

logStyle('quickdungeon0', 'White')
logStyle('quickdungeon1', 'Blue')
logStyle('quickdungeon2', 'Green')
logStyle('quickdungeon3', 'Yellow')

function debug(msg, level)
  if level == nil then
    level = 1
  end
  if msg == nil then
    msg = ''
  end
  if debugLevel >= level then
    log('QD-' .. level .. ': ' .. dump(msg), '', 'quickdungeon' .. level)
  end
end

function setDebug(level)
  if level == nil then
    level = 0
  end
  debugLevel = level
  debug('Set debug level to ' .. level, 0)
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

setDebug(0)
-- level 0: no debug
-- Level 1: function calls
-- level 2: Loops and major events
-- level 3: Local variables (very slow)


vars = {
  createFromAllLines = false,
  deleteAllWalls = false,
  collision = false,
}

function onLoad(save_state)
  self.setScale({1, 1, 1})
  self.setName("QuickDungeon version 0.1.5")
  self.setDescription("by Steve Mattsen")
end

function makeWallButtonClick()
  debug('Starting the make wall process', 1)
  lines = Global.getVectorLines()
  makeBoundingBoxes(lines)
  lines = collectLines(lines)
  makeWalls(lines)
end

function deleteWallsButtonClick()
  deleteWalls(collectWalls())
end

function collectLines( allLines )
  debug('Filtering out unneessary lines.', 1)
  if vars['createFromAllLines'] == true then
    return allLines;
  end

  bounds = self.getBounds()
  debug('Bounds: ' .. dump(bounds), 3)
  local halfWidth = (bounds.size.x / 2)
  local halfHeight = (bounds.size.z / 2)
  debug('Halfwidth: ' .. halfWidth, 3)
  debug('Halfheight: ' .. halfHeight, 3)
  local p1 = {
    x = bounds.center.x + halfWidth,
    y = 0,
    z = bounds.center.z + halfHeight
  }
  local p2 = {
    x = bounds.center.x - halfWidth,
    y = 0,
    z = bounds.center.z - halfHeight
  }
  local bounds = {p1, p2}

  lines = {}
  for i,v in pairs(allLines) do
    debug('Checking plate boundaries with point ' .. i, 2)
    inBounds = isInBounds(v.points[1], bounds) and isInBounds(v.points[2], bounds)

    if inBounds then
      table.insert(lines, v)
    end
  end
  if #lines == 0 then
    out("Detected no lines under the plate.")
    return nil
  end
  return lines
end

function makeWalls(lines)
    debug('Creating the calculated walls.', 1)
  if lines == nil then
     return nil
   end

  for i, v in pairs(lines) do
    local prevPoint = nil
    for pi, pv in pairs(v.points) do
      if prevPoint == nil then
        prevPoint = pv
      else
        createWall(prevPoint, pv)
        prevPoint = pv
      end
    end

    pointCount = v.points
    pointCount = #pointCount
    if v.loop == true or v.square == true then
      createWall(prevPoint, v.points[1])
    elseif pointCount > 2 then
      debug('Determining if first and last points should be connected.', 2)
      -- Connect the first and last points if they're close enough.
      diffX = math.abs(prevPoint.x - v.points[1].x)
      diffY = math.abs(prevPoint.z - v.points[1].z)
      if diffX < 0.2 and diffY < 0.2 then
        createWall(prevPoint, v.points[1])
      end
    end
  end
end

function createWall(p1, p2)
  debug('Creating wall.', 1)
  box = spawnObject({
    type = "Custom_Model",
    position = p1:lerp(p2, 0.5),
    scale = {0.125, 2.5, p1:distance(p2) },
    sound = false,
     callback_function = function (obj) callbackSinglePlane(obj, p1, p2) end
  })
  box.locked = true
  box.getComponent("BoxCollider").set("enabled", false)
  box.setCustomObject({
    mesh = "http://cloud-3.steamusercontent.com/ugc/1746806450112931199/56EEE121BF2C6F71E25A8204D27FBB1BF0BB9DAD/",
    material = 3,
  })
  box.addTag("QuickDungeon Wall")
  box.setColorTint(Color.fromString("Grey"))
end

function deleteWalls(walls)
  for i, v in pairs(walls) do
    destroyObject(v)
  end
end

function collectWalls()
  walls = getObjectsWithTag("QuickDungeon Wall")
  if vars['deleteAllWalls'] == true then
    return walls
  end
  return {}
end

function out(msg)
  printToAll("QuickDungeon: " .. msg)
end

function pingLine(line)
  Player.getPlayers()[1].pingTable(line.points[1]:lerp(line.points[2], 0.5))
end

function isInBounds(point, bounds)
  -- Bounds is a two-point table. Top right and bottom left in that order
  if point.x > bounds[1].x then
    return false
  elseif point.x < bounds[2].x then
    return false
  elseif point.z > bounds[1].z then
    return false
  elseif point.z < bounds[2].z then
    return false
  end
  return true
end

function die()
  self.destruct()
  debug("Deleted self.", 1)
end

function setVar(lua, v, id)
  if v == "True" then
    vars[id] = true
  elseif v == "False" then
    vars[id] = false
  else
    vars[id] = value
  end
end

function callbackSinglePlane(box, p1, p2)
  box.locked = true
  if vars['collision'] ~= true then
    box.getComponent("BoxCollider").set("enabled", false)
  end
  box.setCustomObject({
    mesh = "http://cloud-3.steamusercontent.com/ugc/1746806450112931199/56EEE121BF2C6F71E25A8204D27FBB1BF0BB9DAD/",
    material = 3,
  })
  angle = math.atan2(p1.x - p2.x, p1.z - p2.z)
  angle = math.deg(angle)
  box.setRotation({0, angle + 180, 0})
  box.setScale({0.1, 0.2, p1:distance(p2) * 0.075})
end

function makeBoundingBoxes(lines)
  debug('Making bounding boxes for drawn objects', 1)
  if lines == nil then
    return nil
  end
  for i, v in pairs(lines) do
    local maxX, maxZ = -10000, -10000
    local minX, minZ = 10000, 10000
    debug('Finding bounds for line ' .. i .. ": " .. dump(v), 3)
    for pi, pv in pairs(v.points) do
      debug('Point number ' .. pi .. ': ' .. dump(pv), 3)
      if pv.x > maxX then
        maxX = pv.x
      end
      if pv.x < minX then
        minX = pv.x
      end
      if pv.z > maxZ then
        maxZ = pv.z
      end
      if pv.z < minZ then
        minZ = pv.z
      end
    end
    debug('Bounds now set to: ' .. minX .. ', ' .. minZ .. ' -> ' .. maxX .. ', ' .. maxZ, 2)
    if debugLevel >= 3 then
      Player["White"].pingTable({minX, 0, minZ})
      Player["White"].pingTable({maxX, 0, maxZ})
    end
    v.bounds = {
      {x=minX, y=0, z=minZ},
      {x=maxX, y=0, z=maxZ}
    }
  end
end
