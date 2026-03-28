# FivemCarFight (FiveM)

Vehicle-Fight prevents vehicle-based combat exploits by restricting firing based on vehicle whitelist, aiming angle, and speed. It adds collision visuals (particles + camera shake), can disable action-mode, and includes a client heartbeat to detect event spam.

## Features
- Angle-based firing restriction with configurable min/max degrees
- Speed-based firing restriction (km/h)
- Whitelist for safe vehicles
- Passenger-angle restrictions
- Collision effects (particles + camera shake)
- Client heartbeat to detect resource-stopper / event spam

## Requirements
- FXServer / FiveM
- Copy the resource folder into your server `resources` directory

## Installation
1. Place this folder inside your server `resources` directory.
2. Add the resource to your `server.cfg` or start it manually:

```ini
ensure ytax_kocsifight
```

3. Restart or start the resource on the server.

## Configuration
Open `config.lua` and adjust settings. Defaults are in the file.

- `allowedVehicles` (table): map vehicle model names (lowercase) or model-hash strings to `true`. Vehicles here are treated as allowed.
- `restrictionAngleMin` / `restrictionAngleMax` (numbers): angle range (degrees) where restrictions apply (defaults in `config.lua`).
- `restrictionSpeed` (number): speed threshold in km/h for restriction checks.
- `collisionSystem` (bool): enable collision particle effects.
- `collisionSpeed` (number): minimum collision speed (km/h) to trigger effects.
- `icons` (table): icons used for 3D indicators (`Speed`, `Angle`, `PassengerAngle`).
- `Debug` (bool): show the in-game debug overlay (useful for testing).
- `ActionModeDisable` (bool): disable GTA action-mode when enabled.

Example snippet (see full `config.lua` for defaults):

```lua
Config.restrictionAngleMin = 230
Config.restrictionAngleMax = 330
Config.restrictionSpeed = 20
Config.collisionSystem = true
Config.collisionSpeed = 70
Config.Debug = false
```

## Server setup
- Edit `server/server.lua` and set `DISCORD_WEBHOOK` to your webhook URL to enable Discord logging. Leave empty (`""`) to disable webhook messages.

## Commands
- `vehiclefight_logtest` — run from the server console to send a test embed to the configured webhook.

## Testing / Usage
1. Set `Config.Debug = true` for visible debug info in-game.
2. Join the server and enter a vehicle. Test aiming/backwards firing to confirm restrictions and indicators.
3. Collisions above the configured `collisionSpeed` will display particle effects and camera shake.

Heartbeat and anti-stop behavior: clients send `vehiclefight_ping` every 5s. The server monitors pings and will flag or drop clients that miss multiple heartbeats or spam events.

## Troubleshooting
- Resource fails to start: check server console for Lua errors and ensure `fxmanifest.lua` exists.
- Restrictions not triggering: verify `config.lua` values and ensure the resource is running.
- Discord logging not working: confirm `DISCORD_WEBHOOK` is set and the server has outbound access.

## Contributing
- Pull requests welcome. Keep changes focused and tested locally.

## License
This project is licensed under the MIT License. See `LICENSE` for details.
