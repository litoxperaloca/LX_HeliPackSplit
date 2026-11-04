-- LX_HeliPackSplit: reemplaza este archivo de Heli Pack por un cargador que
-- lee el ORIGINAL instalado, le aplica los cambios de pantalla dividida y
-- mando en memoria, y lo ejecuta. Si Heli Pack cambia y un fragmento deja de
-- coincidir, ese parche se omite con aviso en console.txt y el original sigue
-- funcionando igual.
--
-- Heli Pack son cinco copias del mismo codigo, una por helicoptero. Este
-- archivo es el de UH60BH; los otros cuatro llevan los mismos parches.
require "LXHP_Core"

return LXHP.LoadPatched("media/lua/client/UH60BH/Guards.lua", {
    { id = "arrancar_motor_con_mando", count = 1,
      find = [=[local function wStart()
    local p = getSpecificPlayer(0)
    local down = p ~= nil and not UH60BH.typing() and forwardDown()]=],
      repl = [=[local function wStart()
    local p = LXHP.pilotIn(UH60BH.isAircraft) or getSpecificPlayer(0)
    -- el teclado es del jugador 1; los demas arrancan con A de su mando
    local down = p ~= nil and not UH60BH.typing()
        and ((LXHP.numOf(p) == 0 and forwardDown()) or LXHP.button(p, "start"))]=] },
})
