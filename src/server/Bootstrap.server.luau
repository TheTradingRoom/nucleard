-- Nuclear'd Server Bootstrap
-- Initializes all server-side game systems

print("[Nuclear'd] Server starting...")

local GameManager = require(script.Parent.Services.GameManager)
GameManager.Init()

print("[Nuclear'd] Server ready.")
