local occurrences = {
  e = 21912,
  t = 16587,
  a = 14810,
  o = 14003,
  i = 13318,
  n = 12666,
  s = 11450,
  r = 10977,
  h = 10795,
  d = 7874,
  l = 7253,
  u = 5246,
  c = 4943,
  m = 4761,
  f = 4200,
  y = 3853,
  w = 3819,
  g = 3693,
  p = 3316,
  b = 2715,
  v = 2019,
  [" "] = 1500, --guestimate
  k = 1257,
  x = 315,
  q = 205,
  j = 188,
  z = 128,
}

local alphabet = "abcdefghijklmnopqrstuvwxyz "

local total_occurs = 0
for k, v in pairs(occurrences) do
  total_occurs = total_occurs + v
end

local M = {}

function M.new_state()
  return {
    prev = nil,
    text = "",
  }
end

function M.predict(state)
  local res = {}
  for i = 1, #alphabet do
    res[i] = {prob = occurrences[alphabet:sub(i, i)] / total_occurs, disp = alphabet:sub(i, i)}
  end
  return res
end

function M.advance(state, choice)
  local children = M.predict(state)
  local sum = 0
  for i = 1, choice do
    sum = sum + children[i].prob
  end
  return {
    prev = state,
    prob = occurrences[alphabet:sub(choice, choice)] / total_occurs,
    offset = sum
  }, alphabet:sub(choice, choice)
end

function M.reverse(state)
  return state.prev, state.prob, state.offset
end

return M
