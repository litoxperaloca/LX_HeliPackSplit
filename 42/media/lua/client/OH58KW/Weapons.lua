-- LX_HeliPackSplit: reemplaza este archivo de Heli Pack por un cargador que
-- lee el ORIGINAL instalado, le aplica los cambios de pantalla dividida y
-- mando en memoria, y lo ejecuta. Si Heli Pack cambia y un fragmento deja de
-- coincidir, ese parche se omite con aviso en console.txt y el original sigue
-- funcionando igual.
--
-- Heli Pack son cinco copias del mismo codigo, una por helicoptero. Este
-- archivo es el de OH58KW; los otros cuatro llevan los mismos parches.
require "LXHP_Core"

return LXHP.LoadPatched("media/lua/client/OH58KW/Weapons.lua", {
    { id = "disparar_con_el_gatillo_teclas", count = 1,
      find = [=[    if not vehicle or OH58KW.typing() or not (gunsHeld or isKeyDown(fireKey())) then return end]=],
      repl = [=[    if not vehicle or OH58KW.typing() or not (gunsHeld or isKeyDown(fireKey())
        or LXHP.button(LXHP.driverOf(vehicle), "fire")) then return end]=] },
})
