-- Nuclear'd Server Bootstrap
-- Initializes all server-side game systems

print("[Nuclear'd] Server starting...")

local success, err = pcall(function()
	local GameManager = require(script.Parent.Services.GameManager)
	GameManager.Init()
end)

if success then
	print("[Nuclear'd] Server ready.")
else
	warn("[Nuclear'd] SERVER INIT FAILED:", err)
end
