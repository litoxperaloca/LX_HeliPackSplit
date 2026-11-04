-- LX_HeliPackSplit: reemplaza este archivo de Heli Pack por un cargador que
-- lee el ORIGINAL instalado, le aplica los cambios de pantalla dividida y
-- mando en memoria, y lo ejecuta. Si Heli Pack cambia y un fragmento deja de
-- coincidir, ese parche se omite con aviso en console.txt y el original sigue
-- funcionando igual.
--
-- Heli Pack son cinco copias del mismo codigo, una por helicoptero. Este
-- archivo es el de AH64AP; los otros cuatro llevan los mismos parches.
require "LXHP_Core"

return LXHP.LoadPatched("media/lua/client/AH64AP/Runtime.lua", {
    { id = "ejes_de_vuelo_con_mando_teclas", count = 1,
      find = [=[        u.fwd = keyAxis(Keyboard.KEY_W, Keyboard.KEY_S)
        u.yaw = keyAxis(Keyboard.KEY_D, Keyboard.KEY_A)
        local Keys = AH64AP.Keys                  -- client/AH64AP/Keys.lua: Options > Mods can change them
        u.strafe = keyAxis(Keys.get("right"), Keys.get("left"))
        u.vertical = keyAxis(Keys.get("climb"), Keys.get("descend"))]=],
      repl = [=[        u.fwd = LXHP.axis(p, "fwd", Keyboard.KEY_W, Keyboard.KEY_S)
        u.yaw = LXHP.axis(p, "yaw", Keyboard.KEY_D, Keyboard.KEY_A)
        local Keys = AH64AP.Keys                  -- client/AH64AP/Keys.lua: Options > Mods can change them
        u.strafe = LXHP.axis(p, "strafe", Keys.get("right"), Keys.get("left"))
        u.vertical = LXHP.axis(p, "vertical", Keys.get("climb"), Keys.get("descend"))]=] },
    { id = "aeronave_de_cualquier_jugador", count = 1,
      find = [=[function R.current()
    local p = getSpecificPlayer(0)
    local v = p and p:getVehicle()
    if not v or not AH64AP.isAircraft(v) then return nil end
    return lookup(v), p, v
end]=],
      repl = [=[function R.current()
    local p, v = LXHP.pilotIn(AH64AP.isAircraft)
    if not p or not v then return nil end
    return lookup(v), p, v
end]=] },
    { id = "descubrir_para_cada_jugador", count = 1,
      find = [=[    discover(p, cell, dt)]=],
      repl = [=[    for _, lxp in ipairs(LXHP.localPlayers()) do discover(lxp, cell, dt) end]=] },
    { id = "simular_con_su_piloto", count = 1,
      find = [=[        else
            R.update(s, p, cell, dt)
        end]=],
      repl = [=[        else
            R.update(s, LXHP.driverOf(s.vehicle) or p, cell, dt)
        end]=] },
})
