-- QuickDungeon by Steve Mattsen
-- Version 0.1.6

vars = {
  createFromAllLines = false,
  deleteAllWalls = false,
  collision = false,
}

function onLoad(save_state)
  self.setScale({1, 1, 1})
  self.setName("QuickDungeon version 0.1.6")
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

  local bounds = bboxObj(self)

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
    local angleMod = 0
    if v.loop == true then
      if (#v.points == 4) then
        -- It's a rectangle object
        angleMod = 0
      else
        -- It's a circle object
        angleMod = 180
      end
    elseif #v.points > 2 then
      --It's a free-form line. Let's simplify and clean up the lines.
       v.points = cleanLineObj(v.points)
      --Now let's see if the end points (or close to them) intersect.
      local intersect = false
      for j = 1, 3, 1 do
        for jj = 0, 2, 1 do
          local first = {
            v.points[j],
            v.points[j+1]
          }
          local last = {
            v.points[#v.points-jj],
            v.points[#v.points-(jj+1)],
          }
          intersect = linesIntersect(first, last)
          if intersect != false then
            -- Remove extra end points.
            for k = 0, jj, 1 do
              table.remove(v.points)
            end
            for k = 0, j, 1 do
              table.remove(v.points, 1)
            end
            -- Connect end points at intersection.
            v.points[1] = intersect
            v.points[#v.points] = intersect
            break
          end
        end
        if intersect != false then break end
      end
    end
    for pi, pv in pairs(v.points) do
      if prevPoint == nil then
        prevPoint = pv
      else
        angle = math.atan2(prevPoint.x - pv.x, prevPoint.z - pv.z)
        angle = math.deg(angle)
        wall = createWall(prevPoint, pv, v.color)
        wall.setRotation({0, (angle + angleMod), 0})
        prevPoint = pv
      end
    end

    pointCount = #v.points
    -- Figure out what to do about the end points.
    local endWall = nil
    if v.loop == true then
      -- We know the end points should be connected. Carry on.
      endWall = createWall(prevPoint, v.points[1], v.color)
    elseif #v.points > 2 then
      -- It's a free-form line. They might need connecting.
      debug('Determining if first and last points should be connected.', 2)
      -- Connect the first and last points if they're close enough.
      diffX = math.abs(prevPoint.x - v.points[1].x)
      diffY = math.abs(prevPoint.z - v.points[1].z)
      if diffX < 0.2 and diffY < 0.2 then
        endWall = createWall(prevPoint, v.points[1], v.color)
      end
    end
    if endWall != nil then
      angle = math.atan2(prevPoint.x - v.points[1].x, prevPoint.z - v.points[1].z)
      angle = math.deg(angle)
      endWall.setRotation({0, (angle + angleMod), 0})
    end
  end
end

function createWall(p1, p2, color)
  if color == nil then
    color = Color.fromString("White")
  end
  debug('Creating wall.', 2)
  local pos = p1:lerp(p2, 0.5);
  local box = spawnObject({
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
    normal = "http://cloud-3.steamusercontent.com/ugc/1746806640213441402/BE8FD4CDE275420894F2C64B1B3D6AA8CBBAA088/",
    diffuse = "http://cloud-3.steamusercontent.com/ugc/1746806640213402696/266BC0FA86A7F0B7C8B6434272456EAA0D53BB73/",
    material = 1,
  })
  box.addTag("QuickDungeon Wall")
  box.setColorTint(color)
  return box
end

function deleteWalls(walls)
  debug('Deleting selected walls.', 1)
  for i, v in pairs(walls) do
    destroyObject(v)
  end
end

function collectWalls()
  debug("Collecting walls", 1)
  local walls = getObjectsWithTag("QuickDungeon Wall")
  if vars['affectGlobal'] == true then
    return walls
  end
  local result = {}
  local bbox = bboxObj(self)
  debug("Checking bounding boxes with plate.", 2)
  for i, v in pairs(walls) do
    if boundsOverlap(bbox, bboxObj(v)) == true then
      table.insert(result, v)
    end
  end
  return result
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
  box.setScale({0.1, 0.2, p1:distance(p2) * 0.0714286}) -- 1 / 14, width of walls.
  setSuperLock(box, true)
end

function makeBoundingBoxes(lineObjs)
  debug('Making bounding boxes for drawn objects', 1)
  if lineObjs == nil then
    return nil
  end
  local result = {}
  for i, v in pairs(lineObjs) do
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

function bboxObj(obj)
  local b = obj.getBounds()
  local halfWidth = (b.size.x / 2)
  local halfHeight = (b.size.z / 2)
  return {
    {
      x = b.center.x - halfWidth,
      y = 0,
      z = b.center.z - halfHeight
    }, {
      x = b.center.x + halfWidth,
      y = 0,
      z = b.center.z + halfHeight
    }
  }
end

function bboxLineObj(line)
  -- Returns the bounding box of a line object.
  -- Note that this is different from a line segment.
  -- A line object is a group of line segments from one draw action in TTS.
end

function bboxLineSeg(lineSeg)
  -- Checks the min and max values of both points, returns a bounding box.
end

function linesIntersect(line1, line2)
  -- Equations taken from https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection#Given_two_points_on_each_line_segment
  -- t = (x1-x3)(y3-y4) - (y1-y3)(x3-x4) / (x1-x2)(y3-y4) - (y1-y2)(x3-x4)
  -- u = (x2-x1)(y1-y3) - (y2-y1)(x1-x3) / (x1-x2)(y3-y4) - (y1-y2)(x3-x4)
  local g1 = (line1[1].x - line2[1].x) * (line2[1].z - line2[2].z)
  g1 = g1 - ((line1[1].z - line2[1].z) * (line2[1].x - line2[2].x))
  local g2 = (line1[1].x - line1[2].x) * (line2[1].z - line2[2].z)
  g2 = g2 - ((line1[1].z - line1[2].z) * (line2[1].x - line2[2].x))
  local g3 = (line1[2].x - line1[1].x) * (line1[1].z - line2[1].z)
  g3 = g3 - ((line1[2].z - line1[1].z) * (line1[1].x - line2[1].x))
  local t = g1 / g2
  local u = g3 / g2
  if t < 0 or t > 1 or u < 0 or u > 1 then
    return false
  end
  return {
    x = line1[1].x + (t * (line1[2].x - line1[1].x)),
    y = 0,
    z = line1[1].z + (t * (line1[2].z - line1[1].z))
  }
end

function cleanLineObj(points)
  local currentPoint = points[1]
  local result = { currentPoint }
  local minDistance = 0.33
  for i, v in pairs(points) do
    if currentPoint:distance(v) >= minDistance then
      table.insert(result, v)
      currentPoint = v
    else if i == #points then
      -- Always insert the last point.
      table.insert(result, v)
    end
    end
  end
  return result
end
