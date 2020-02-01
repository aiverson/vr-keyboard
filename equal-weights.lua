
local M = {}

local alphabet = "abcdefghijklmnopqrstuvwxyz "

function M.new_state()
  return {
    prev = nil,
    text = "",
  }
end

function M.predict(state)
  local res = {}
  for i = 1, #alphabet do
    res[i] = {prob = 1/#alphabet, disp = alphabet:sub(i, i)}
  end
  return res
end

function M.advance(state, choice)
  return {
    prev = state,
    prob = 1 / #alphabet
  }, alphabet:sub(choice, choice)
end

function M.reverse(state)
  return state.prev, state.prob
end

return M
