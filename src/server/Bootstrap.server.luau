-- Nuclear'd Server Bootstrap
-- Initializes all server-side game systems

print("[Nuclear'd] Server starting...")

local success, err = pcall(function()
	local Services = script.Parent:WaitForChild("Services", 10)
	if not Services then
		error("Services folder not found in ServerScriptService")
	end

	local GameManager = require(Services:WaitForChild("GameManager"))
	GameManager.Init()
end)

if success then
	print("[Nuclear'd] Server ready.")
else
	warn("[Nuclear'd] SERVER INIT FAILED:", err)
end
