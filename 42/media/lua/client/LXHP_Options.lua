--[[
    LX_HeliPackSplit - opciones.
    Menu principal -> Opciones -> MODS -> "LX Heli Pack Split".

    Las correcciones de pantalla dividida no se configuran: estan siempre.
    Aca se elige unicamente que hace cada stick, porque eso es gusto.
]]

if not PZAPI or not PZAPI.ModOptions then return end
require "LXHP_Core"
if LXHP == nil or LXHP.cfg == nil then return end

local CFG = LXHP.cfg

local opts = PZAPI.ModOptions:create("LXHeliPackSplit", getText("UI_LXHP_name"))
opts:addDescription(getText("UI_LXHP_desc"))
opts:addSeparator()

-- 1 = helicoptero (izq = colectivo + pedales, der = ciclico)
-- 2 = juego       (izq = adelante/atras + giro, der = subir/bajar + lateral)
local sLayout = opts:addSlider("LAYOUT", getText("UI_LXHP_layout"), 1, 2, 1, 1,
                               getText("UI_LXHP_layout_tip"))
local sDead   = opts:addSlider("DEADZONE", getText("UI_LXHP_dead"), 0.05, 0.45, 0.01, 0.22,
                               getText("UI_LXHP_dead_tip"))
local tInv    = opts:addTickBox("INVERT_Y", getText("UI_LXHP_invert"), false,
                                getText("UI_LXHP_invert_tip"))

opts.apply = function(self)
    CFG.layout   = (tonumber(sLayout:getValue()) == 2) and "juego" or "helicoptero"
    CFG.deadzone = tonumber(sDead:getValue()) or 0.22
    CFG.invertY  = (tInv:getValue() == true)
    LXHP.log(("mando: layout %s, zona muerta %.2f, Y invertida %s")
        :format(CFG.layout, CFG.deadzone, CFG.invertY and "si" or "no"))
end

-- apply() lo llama el menu al aceptar; al arrancar hay que llamarlo nosotros
-- para que los valores guardados lleguen a CFG antes del primer vuelo.
if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(opts.apply, opts) end)
end
