--[[
    LX_HeliPackSplit - nucleo.

    LO QUE ENCONTRE EN HELI PACK
    42.269 lineas de Lua, que son CINCO COPIAS del mismo codigo (una por
    helicoptero: UH60BH, AH64AP, MH6LB, EC135, OH58KW), entre 87% y 98%
    identicas entre si. De sus 94 llamadas a getSpecificPlayer, 76 estan
    clavadas en el jugador 0: el 81%.

    En pantalla dividida eso significa dos cosas, y la segunda es peor:

      1. El jugador 2 no puede volar. R.current() pregunta si el JUGADOR 0
         esta en una aeronave; si el que se subio es el 2, para el mod no hay
         nadie en ningun helicoptero.
      2. Peor: el tick simula CADA aeronave pasando el jugador 0. Si tu hijo
         pilotea, su helicoptero se vuela con TUS controles.

    Y de mando no hay absolutamente nada: cero JoypadState, cero getJoypadData
    en las 42.269 lineas. No es un arreglo, es una funcionalidad nueva.

    LO BUENO: ESTA TODO MUY CONCENTRADO
    El control de vuelo entero son cuatro lineas que pasan por un unico lector
    de ejes (keyAxis). Parcheando ese bloque y la linea del tick que elige al
    piloto se arregla el vuelo Y entra el mando, en los cinco helicopteros.

    ADEMAS EL MANDO QUEDA MEJOR QUE EL TECLADO
    keyAxis devuelve -1, 0 o 1. El modelo de vuelo multiplica por ese valor
    (CLIMB_RATE * u.vertical * ...), asi que acepta intermedios: el stick da
    control proporcional, que el teclado no puede dar.

    Nada de Heli Pack se distribuye ni se pisa: sus archivos se leen de tu
    copia instalada, se parchean en memoria y se ejecutan desde ahi.
]]

LXHP = LXHP or {}
LXHP.TARGET_MOD = "UH60BlackHawk"
LXHP.report = LXHP.report or {}

local function log(msg) print("[LX_HeliPackSplit] " .. tostring(msg)) end
LXHP.log = log

-- =====================================================================
-- Jugadores locales
-- =====================================================================

function LXHP.localPlayers()
    local list = {}
    if type(getSpecificPlayer) ~= "function" then return list end
    for i = 0, 3 do
        local ok, p = pcall(getSpecificPlayer, i)
        if ok and p ~= nil then list[#list + 1] = p end
    end
    return list
end

function LXHP.numOf(player)
    if player == nil then return nil end
    local ok, n = pcall(function() return player:getPlayerNum() end)
    if ok and type(n) == "number" and n >= 0 and n <= 3 then return n end
    return nil
end

-- El jugador local que conduce ESE vehiculo, si hay alguno.
function LXHP.driverOf(vehicle)
    if vehicle == nil then return nil end
    for _, p in ipairs(LXHP.localPlayers()) do
        local ok, isD = pcall(function() return vehicle:isDriver(p) end)
        if ok and isD == true then return p end
    end
    return nil
end

-- El primer jugador local sentado en una aeronave del mod. isAircraft viene
-- del helicoptero que llama, porque cada copia tiene la suya.
function LXHP.pilotIn(isAircraft)
    for _, p in ipairs(LXHP.localPlayers()) do
        local ok, v = pcall(function() return p:getVehicle() end)
        if ok and v ~= nil then
            local okA, yes = pcall(isAircraft, v)
            if okA and yes then return p, v end
        end
    end
    return nil, nil
end

-- =====================================================================
-- Mitad de pantalla
-- =====================================================================
-- Fuera de pantalla dividida el viewport ES la ventana entera, asi que todo
-- lo que use esto se comporta igual que el original para quien juega solo.

function LXHP.viewport(player)
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    if type(getPlayerScreenWidth) ~= "function" then return 0, 0, sw, sh end
    local n = LXHP.numOf(player) or 0
    local okW, w = pcall(getPlayerScreenWidth, n)
    local okH, h = pcall(getPlayerScreenHeight, n)
    local okL, l = pcall(getPlayerScreenLeft, n)
    local okT, t = pcall(getPlayerScreenTop, n)
    if not (okW and okH and okL and okT) then return 0, 0, sw, sh end
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
        return 0, 0, sw, sh
    end
    return l or 0, t or 0, w, h
end

local function clamp(v, lo, hi)
    if hi < lo then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function LXHP.centre(player, w, h)
    local l, t, vw, vh = LXHP.viewport(player)
    local x = l + (vw - (tonumber(w) or 0)) / 2
    local y = t + (vh - (tonumber(h) or 0)) / 2
    return math.floor(clamp(x, l, l + vw - (tonumber(w) or 0))),
           math.floor(clamp(y, t, t + vh - (tonumber(h) or 0)))
end

-- =====================================================================
-- Mando
-- =====================================================================

-- Mapeo por defecto: el de un helicoptero de verdad.
--   stick izquierdo  Y = colectivo (subir / bajar)     X = pedales (giro)
--   stick derecho    Y = ciclico adelante / atras      X = ciclico lateral
-- Con layout = "juego" se cambia a lo que espera quien viene de un auto:
--   izquierdo Y = adelante / atras, derecho Y = subir / bajar.
LXHP.cfg = {
    layout   = "helicoptero",
    deadzone = 0.22,   -- los sticks nunca descansan exactamente en cero
    invertY  = false,
}

function LXHP.joypadId(playerNum)
    if type(getJoypadData) ~= "function" then return nil end
    local ok, jd = pcall(getJoypadData, playerNum)
    if not ok or jd == nil then return nil end
    local okId, id = pcall(function() return jd.id end)
    if okId and id ~= nil then return id end
    return nil
end

-- Lee un stick con zona muerta, reescalando lo que queda para que el recorrido
-- util siga yendo de 0 a 1 (si no, el control arranca de golpe en 0.22).
local function readAxis(fn, id)
    if type(fn) ~= "function" then return 0 end
    local ok, v = pcall(fn, id)
    if not ok or type(v) ~= "number" then return 0 end
    local dz = LXHP.cfg.deadzone
    local a = math.abs(v)
    if a <= dz then return 0 end
    local scaled = (a - dz) / (1 - dz)
    if scaled > 1 then scaled = 1 end
    return (v < 0) and -scaled or scaled
end

--[[
    El eje de vuelo de UN jugador.

    - Si ese jugador tiene mando, manda el stick (analogico).
    - Si no, y es el jugador del teclado, se lee el teclado como siempre.
    - Si no tiene mando y tampoco es el del teclado, no tiene control: es lo
      correcto, no hay con que volar.

    Jugando solo y sin mando el resultado es identico al original.
]]
function LXHP.axis(player, cual, posKey, negKey)
    local n = LXHP.numOf(player)
    local id = n and LXHP.joypadId(n) or nil

    if id ~= nil then
        local izqX = readAxis(rawget(_G, "getJoypadMovementAxisX"), id)
        local izqY = readAxis(rawget(_G, "getJoypadMovementAxisY"), id)
        local derX = readAxis(rawget(_G, "getJoypadAimingAxisX"), id)
        local derY = readAxis(rawget(_G, "getJoypadAimingAxisY"), id)
        -- en los sticks, Y crece hacia ABAJO
        local sube, adelante
        if LXHP.cfg.layout == "juego" then
            adelante, sube = -izqY, -derY
        else
            sube, adelante = -izqY, -derY
        end
        if LXHP.cfg.invertY then sube, adelante = -sube, -adelante end

        if cual == "vertical" then return sube end
        if cual == "fwd"      then return adelante end
        if cual == "yaw"      then return izqX end
        if cual == "strafe"   then return derX end
        return 0
    end

    -- sin mando: teclado, y solo para quien tiene el teclado
    if n ~= nil and n ~= 0 then return 0 end
    if type(isKeyDown) ~= "function" then return 0 end
    local a = 0
    local okP, downP = pcall(isKeyDown, posKey)
    local okN, downN = pcall(isKeyDown, negKey)
    if okP and downP then a = a + 1 end
    if okN and downN then a = a - 1 end
    return a
end

-- Boton de accion (arrancar motor, disparar) del mando de ese jugador.
function LXHP.button(player, cual)
    local n = LXHP.numOf(player)
    local id = n and LXHP.joypadId(n) or nil
    if id == nil then return false end
    local fn
    if cual == "fire" then fn = rawget(_G, "isJoypadRTPressed")
    elseif cual == "start" then fn = rawget(_G, "isJoypadAPressed")
    else return false end
    if type(fn) ~= "function" then return false end
    local ok, down = pcall(fn, id)
    return ok and down == true
end

-- =====================================================================
-- Cargador de parches de texto
-- =====================================================================

local function readModFile(modId, rel)
    local ok, reader = pcall(getModFileReader, modId, rel, false)
    if not ok or not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n") .. "\n"
end

local function escapePattern(s)
    return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", function(c) return "%" .. c end))
end

local function plainReplace(src, find, repl)
    local pat = escapePattern(find)
    local parts, pos, count = {}, 1, 0
    while true do
        local s, e = string.find(src, pat, pos)
        if not s then break end
        parts[#parts + 1] = string.sub(src, pos, s - 1)
        parts[#parts + 1] = repl
        pos = e + 1
        count = count + 1
    end
    parts[#parts + 1] = string.sub(src, pos)
    return table.concat(parts), count
end

local function countOccurrences(src, find)
    local _, n = plainReplace(src, find, "")
    return n
end

LXHP._plainReplace = plainReplace

function LXHP.LoadPatched(rel, patches)
    local src = readModFile(LXHP.TARGET_MOD, rel)
    if not src then
        log("ERROR: no pude leer " .. rel .. " de " .. LXHP.TARGET_MOD ..
            ". Heli Pack activo? (archivo NO cargado)")
        return false
    end

    local applied, skipped, total = {}, {}, 0
    local patched = src
    for _, p in ipairs(patches) do
        local n = countOccurrences(patched, p.find)
        local ok
        if p.count == "*" then ok = n > 0 else ok = (n == (p.count or 1)) end
        if ok then
            patched = plainReplace(patched, p.find, p.repl)
            applied[#applied + 1] = p.id
            total = total + n
        else
            skipped[#skipped + 1] = p.id .. " (encontrado " .. n ..
                ", esperado " .. tostring(p.count) .. ")"
        end
    end

    local chunk, err = loadstring(patched, "@UH60BlackHawk/" .. rel)
    if not chunk then
        log("ERROR compilando " .. rel .. " parcheado: " .. tostring(err) ..
            " -> uso el ORIGINAL sin parches")
        chunk, err = loadstring(src, "@UH60BlackHawk/" .. rel)
        applied, total = {}, 0
        if not chunk then
            log("ERROR compilando original " .. rel .. ": " .. tostring(err))
            return false
        end
    end

    LXHP.report[rel] = { applied = applied, skipped = skipped, changes = total }
    if #skipped > 0 then
        log(rel .. ": " .. total .. " cambios, OMITIDOS: " .. table.concat(skipped, "; "))
    end

    if LXHP.DRY_RUN then return true end
    return chunk()
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        local files, changes, bad = 0, 0, 0
        for _, r in pairs(LXHP.report or {}) do
            files = files + 1
            changes = changes + (r.changes or 0)
            bad = bad + #r.skipped
        end
        log("pantalla dividida y mando: " .. changes .. " cambios en " .. files ..
            " archivos" .. (bad > 0 and (", " .. bad .. " parches omitidos") or ""))
    end)
end
