local model = require 'keymodel'

local function new_tree()
  local root = model.new_state()
  return {
    center = 0,
    zoom = 1,
    root = root,
    selected = root,
    active_path = {},
    inactive_path = {}
  }
end

local z_delta = 0.001
local min_size = 0.001
local traverse_speed = 2

local function compute_bounds(region, modelstate, disp)
  local offset = region.offset
  local width = region.width
  if width < min_size or offset > 0.5 or offset + width < -0.5 then
    return nil
  end
  local children = {}
  for i, subnode in ipairs(model.predict(modelstate)) do
    local subregion = {offset = offset, width = width * subnode.prob}
    offset = offset + subregion.width
    --TODO: cache model predictions
    local subbounds = compute_bounds(subregion, model.advance(modelstate, i), subnode.disp)
    children[i] = subbounds or {}
  end
  return {region = region, children = children, disp = disp or ""}
end

local function render_bounds(bounds, depth)
  if not bounds or not bounds.region then return end
  local x1 = math.max(bounds.region.offset, -0.5)
  local x2 = math.min(bounds.region.offset + bounds.region.width, 0.5)
  local y1 = 0.5
  local y2 = math.max(0.5 - bounds.region.width, -0.5)
  local cx, cy, cz = (x1 + x2) / 2, (y1 + y2) / 2, z_delta * depth
  lovr.graphics.plane("line", cx, cy, cz, x2 - x1, y2 - y1)
  if bounds.region.width > 0.05 then
    lovr.graphics.print(bounds.disp, cx, y2, cz, 0.05)
  end
  for i, child in ipairs(bounds.children) do
    render_bounds(child, depth + 1)
  end
end

local bounds_tree = {}

local function rendertree(state)
  lovr.graphics.setColor(255, 255, 255)
  render_bounds(bounds_tree, 0)
end


local tree = new_tree()

local function compute_path(tree, bounds, modelstate)
  if not bounds or not bounds.children then print ("path abort") return end
  for i, v in ipairs(bounds.children) do
    if v.region and v.region.offset < 0 and v.region.offset + v.region.width > 0 and v.region.width > 0.5 then
      local newstate, val = model.advance(modelstate, i)
      table.insert(tree.active_path, val)
      compute_path(tree, v, newstate)
    end
  end
end

local text = ""

function lovr.update(dt)
  for i, hand in ipairs(lovr.headset.getHands()) do
    local x, y = lovr.headset.getAxis(hand, "touchpad")
    tree.center = (tree.center - x * dt * traverse_speed) * (1 + y * dt * traverse_speed)
    tree.zoom = tree.zoom + tree.zoom * y * dt * traverse_speed
  end
  if tree.center > tree.zoom/2 then tree.center = tree.zoom/2 end
  if tree.center < -tree.zoom/2 then tree.center = -tree.zoom/2 end
  if tree.zoom < 0.5 then tree.zoom = 0.5 end
  print("tree position", tree.center, tree.zoom)
  local new_bounds = {
      offset = tree.center - tree.zoom / 2,
      width = tree.zoom
  }
  bounds_tree = compute_bounds({
      offset = tree.center - tree.zoom / 2,
      width = tree.zoom
                               },
    tree.root)
  while not (bounds_tree.region.offset < -0.5 and bounds_tree.region.offset + bounds_tree.region.width > 0.5) do
    print "backing up root"
    local back, ratio, offset = model.reverse(tree.root)
    if not back then break end
    table.remove(tree.inactive_path)
    tree.root = back
    local new_width, new_offset = tree.zoom / ratio, -tree.zoom / ratio * offset - bounds_tree.region.offset --TODO: This is currently bugged and results in teleportation when backing up the root.
    --local new_width, new_offset = tree.zoom / ratio, ratio * offset + bounds_tree.region.offset --TODO: This is currently bugged and results in teleportation when backing up the root.
    print("changing widths", tree.zoom, bounds_tree.region.offset, new_width, new_offset)
    local new_zoom = new_width
    local new_center = new_offset + new_width / 2
    tree.zoom, tree.center = new_zoom, new_center
    bounds_tree = compute_bounds({
        offset = tree.center - tree.zoom / 2,
        width = tree.zoom
                                 },
      tree.root)
  end
  print "done backing up root"
  local moving_root = true
  local focused_node = bounds_tree
  while moving_root do
    moving_root = false
    for i, v in ipairs(focused_node.children) do
      if v.region and v.region.offset < -0.5 and v.region.offset + v.region.width > 0.5 then
        local next_root, val = model.advance(tree.root, i)
        print("lowering root", i, val)
        table.insert(tree.inactive_path, val)
        local new_zoom = tree.zoom * v.region.width / focused_node.region.width
        local new_center = v.region.offset + v.region.width / 2
        tree.zoom, tree.center = new_zoom, new_center
        tree.root = next_root
        focused_node = v
        moving_root = true
      end
    end
  end
  print "done lowering root"
  tree.active_path = {}
  compute_path(tree, focused_node, tree.root)
  text = tostring(#tree.inactive_path) .. " " .. tostring(#tree.active_path) .. " ".. table.concat(tree.inactive_path) .. table.concat(tree.active_path)
end

local function show_controller(hand)
  local x, y, z, a, b, c, d = lovr.headset.getPose(hand)
  lovr.graphics.push()
  lovr.graphics.translate(x, y, z)
  lovr.graphics.rotate(a, b, c, d)
  lovr.graphics.setColor(127, 0, 0)
  lovr.graphics.box("fill", 0, 0, 0, 0.1, 0.1, 0.3)
  local tx, ty = lovr.headset.getAxis(hand, "touchpad")
  lovr.graphics.push()
  lovr.graphics.translate(tx / 10, 0.05, -ty / 10)
  lovr.graphics.setColor(255, 255, 255)
  lovr.graphics.box("fill", 0, 0, 0, 0.01, 0.01, 0.01)
  lovr.graphics.pop()
  lovr.graphics.translate(0, 0.1, 0)
  rendertree(tree)
  lovr.graphics.pop()
end

function lovr.draw()
  lovr.graphics.setColor(255, 255, 255)
  lovr.graphics.print(text, 0, 1.7, -3, .5)

  for i, hand in ipairs(lovr.headset.getHands()) do
    --[[local x, y, z = lovr.headset.getPosition(hand)
    lovr.graphics.sphere(x, y, z, .1)
    local tx, ty = lovr.headset.getAxis(hand, "touchpad")
    lovr.graphics.sphere(x + tx/10, y + ty/10, z + 0.1, 0.01)
    --]]
    show_controller(hand)
  end
end
