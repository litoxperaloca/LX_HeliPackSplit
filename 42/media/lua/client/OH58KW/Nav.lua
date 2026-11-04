-- LX_HeliPackSplit: reemplaza este archivo de Heli Pack por un cargador que
-- lee el ORIGINAL instalado, le aplica los cambios de pantalla dividida y
-- mando en memoria, y lo ejecuta. Si Heli Pack cambia y un fragmento deja de
-- coincidir, ese parche se omite con aviso en console.txt y el original sigue
-- funcionando igual.
--
-- Heli Pack son cinco copias del mismo codigo, una por helicoptero. Este
-- archivo es el de OH58KW; los otros cuatro llevan los mismos parches.
require "LXHP_Core"

return LXHP.LoadPatched("media/lua/client/OH58KW/Nav.lua", {
    { id = "piloto_de_cualquier_jugador", count = 1,
      find = [=[local function piloting()
    local p = getSpecificPlayer(0)
    local v = p and p:getVehicle()
    return v ~= nil and OH58KW.isAircraft(v) and v:isDriver(p)
end]=],
      repl = [=[local function piloting()
    local p, v = LXHP.pilotIn(OH58KW.isAircraft)
    return p ~= nil and v ~= nil and v:isDriver(p)
end]=] },
})
