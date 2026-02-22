-- Nuclear'd Server Bootstrap
-- Initializes all server-side game systems

print("[Nuclear'd] Server starting...")

local GameManager = require(script.Services.GameManager)
GameManager.Init()

print("[Nuclear'd] Server ready.")
