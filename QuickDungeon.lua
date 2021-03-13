-- QuickDungeon by Steve Mattsen
-- Version 0.1.5

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
  if vars['affectGlobal'] == true then
    return allLines;
  end

  bounds = self.getBounds()
  debug('Bounds: ' .. dump(bounds), 3)
  local halfWidth = (bounds.size.x / 2)
  local halfHeight = (bounds.size.z / 2)
  debug('Halfwidth: ' .. halfWidth, 3)
  debug('Halfheight: ' .. halfHeight, 3)
  local p1 = {
    x = bounds.center.x - halfWidth,
    y = 0,
    z = bounds.center.z - halfHeight
  }
  local p2 = {
    x = bounds.center.x + halfWidth,
    y = 0,
    z = bounds.center.z + halfHeight
  }
  bounds = {p1, p2}

  local result = {}
  for i,v in pairs(allLines) do
    debug('Checking plate boundaries with point ' .. i, 2)
    inBounds = boundsOverlap(bounds, v.bounds)

    if inBounds then
      table.insert(result, v)
    end
  end
  if #result == 0 then
    out("Detected no lines under the plate.")
    return nil
  end
  return result
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
  pos = p1:lerp(p2, 0.5);
  box = spawnObject({
    type = "Custom_Model",
    position = {pos.x, 2, pos.z},
    scale = {0,0,0},
    sound = false,
     callback_function = function (obj) callbackSinglePlane(obj, p1, p2) end
  })
  setSuperLock(box, true)
  box.setCustomObject({
    mesh = "http://cloud-3.steamusercontent.com/ugc/1746806450112931199/56EEE121BF2C6F71E25A8204D27FBB1BF0BB9DAD/",
    collider = "http://cloud-3.steamusercontent.com/ugc/1746806450115851187/E838009DA69AD28BE1F57666B26D9EAF85942FD3/",
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
  if vars['affectGlobal'] == true then
    return walls
  end
  return {}
end
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
  if box == nil then
    return nil
  end
  setSuperLock(box, true)
  angle = math.atan2(p1.x - p2.x, p1.z - p2.z)
  angle = math.deg(angle)
  box.setRotation({0, angle + 180, 0})
  box.setScale({0.1, 0.2, p1:distance(p2) * 0.075})
  setSuperLock(box, true)
end

function makeBoundingBoxes(lines)
  debug('Making bounding boxes for drawn objects', 1)
  if lines == nil then
    return nil
  end
  local result = {}
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
    table.insert(result, v)
  end
  return result
end

function setSuperLock(obj, state)
  if obj == nil then
    return false
  end
  if state ~= true then
    state = false
  end
  obj.locked = state
  obj.interactable = state
  local box = obj.getComponent("BoxCollider");
  if box != nil then
    box.set("enabled", state)
  end
end

function boundsOverlap(bbox1, bbox2)
  -- Assumes bbox1 and 2 are two points in {lowerLeft, upperRight} format.
  if bbox1[1].z > bbox2[2].z then
    -- bbox1 is above bbox2
    return false
  elseif bbox1[2].z < bbox2[1].z then
    -- bbox1 is below bbox2
    return false
  elseif bbox1[1].x > bbox2[2].x then
    -- bbox1 is to the right of bbox2
    return false
  elseif bbox1[2].x < bbox2[1].x then
    -- bbox1 is to the left of bbox2
    return false
  end
  return true
end
