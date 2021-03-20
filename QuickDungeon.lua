-- QuickDungeon by Steve Mattsen
-- Version 0.1.6
#include QuickDungeon\debug
#include QuickDungeon\geometry
#include QuickDungeon\linkedPoint

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
  debug('Create button clicked.', 1)
  local lineObjs = Global.getVectorLines()
  -- Prepare
  prepareLineObjs(lineObjs)
  -- Collect
  lines = collectLineObjs(lineObjs)
  if lineObjs == nil then
    return
  end
  -- Sanitize
  sanitizeLineObjs(lineObjs)
  -- Group
  -- Link
  -- Join 
  -- Analyze
  -- Action
  makeWalls(lineObjs)
end

function deleteWallsButtonClick()
  deleteWalls(collectWalls())
end

function prepareLineObjs(lineObjs)
  debug('Making bounding boxes for line objects', 1)
  if lineObjs == nil then
    return nil
  end
  for i, v in pairs(lineObjs) do
    debug('Finding bounds for line object ' .. i .. ": " .. dump(v), 2)
    v.id = i
    v.bbox = bboxLineObj(v)
  end
end

function collectLineObjs( allLines )
  if vars['affectGlobal'] == true then
    debug('Collecting all line objects in Global.', 1)
    return allLines;
  end
  debug('Filtering out all line objects not under plate.', 1)

  local bbox = bboxObj(self)
  local result = {}
  for i,v in pairs(allLines) do
    debug('Checking plate boundaries with line ' .. i, 2)
    local inBounds = boundsOverlap(bbox, v.bbox)

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

function sanitizeLineObjs(lineObjs)
  for i,v in pairs(lineObjs) do
    if #v.points > 2 and v.loop == false then
     --It's a free-form line. Let's simplify and clean up the lines.
      v.points = cleanLineObj(v.points)
     --Now let's see if the end points (or close to them) intersect.
      v.points = cleanEndPoints(v.points)
    end
  end
end

function groupLines(lines)
  debug('Sorting lines into groups', 1)
  local groups = {}
  while #lines > 0 do
    local group = {}
    local line = table.remove(lines)
    table.insert(group, line)
    groupLinesByBbox(group, lines, line.bbox)
    table.insert(groups, group)
  end
  return groups
end

function groupLinesByBbox(group, lines, bbox)
  -- Recursive function which will populate group with the first line and any lines that overlap its bbox.
  -- Will remove the line from lines if grouped.
  for i, v in pairs(lines) do
    --Check if the line overlaps
    if boundsOverlap( bbox, v.bbox ) == true then
      table.remove(lines, i);
      table.insert(group, v)
      groupLinesByBbox(group, lines, v.bbox)
    end
  end
end
function makeWalls(lines)
  debug('Creating the calculated walls.', 1)
  if lines == nil then
     return nil
  end
  -- Make line groups based on bbox collision.
  local groups = groupLines(lines)
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
  p1 = Vector(p1)
  p2 = Vector(p2)
  if color == nil then
    color = Color.fromString("White")
  end
  debug('Creating wall from ' .. dump(p1) .. ' to ' .. dump(p2), 2)
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
  box.setScale({0.1, 0.2, p1:distance(p2) * (1/14)}) -- 1 / 14, width of walls.
  setSuperLock(box, true)
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

function cleanLineObj(points)
  local currentPoint = points[1]
  local result = { currentPoint }
  local minDistance = 0.33
  for i, v in pairs(points) do
    if currentPoint:distance(v) >= minDistance then
      table.insert(result, v)
      currentPoint = v
    elseif i == #points then
      -- Always insert the last point.
      table.insert(result, v)
    end
  end
  return result
end

function cleanEndPoints(points)
  local intersect = false
  for i = 1, 3, 1 do
    for ii = 0, 2, 1 do
      local first = {
        points[i],
        points[i+1]
      }
      local last = {
        points[#points-ii],
        points[#points-(ii+1)],
      }
      intersect = linesIntersect(first, last)
      if intersect != false then
        -- Remove extra end points.
        for j = 0, ii, 1 do
          table.remove(points)
        end
        for j = 0, i, 1 do
          table.remove(points, 1)
        end
        -- Connect end points at intersection.
        points[1] = intersect
        points[#points] = intersect
        return points
      end
    end
  end
  return points
end

-- Save copied tables in `copies`, indexed by original table.
function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
