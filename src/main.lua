--==========================================================================
--  Kicia Rebuild  -  Rivals
--  Kiciahook v3, rebuilt from a decompiled build.
--==========================================================================
if getgenv().KiciaRebuild and getgenv().KiciaRebuild.Unload then
    pcall(getgenv().KiciaRebuild.Unload)
end
if not game:IsLoaded() then game.Loaded:Wait() end

local K = { connections = {}, cleanups = {}, destroyed = false }
getgenv().KiciaRebuild = K

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local rawget, rawset = rawget, rawset

function K.fn(name)
    local v
    pcall(function() v = getfenv(0)[name] end)
    if type(v) ~= "function" then pcall(function() v = getfenv()[name] end) end
    return type(v) == "function" and v or nil
end

local getthreadidentity_ = K.fn("getthreadidentity") or K.fn("getidentity")
local setthreadidentity_ = K.fn("setthreadidentity") or K.fn("setidentity")
local sethiddenproperty_ = K.fn("sethiddenproperty")
local gethui_ = K.fn("gethui")
local function identity(n)
    if not setthreadidentity_ then return function() end end
    local old = getthreadidentity_ and getthreadidentity_() or nil
    pcall(setthreadidentity_, n)
    return function() if old then pcall(setthreadidentity_, old) end end
end
K.identity = identity
local function hudParent()
    local ok, h = pcall(function() return gethui_ and gethui_() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end
K.hudParent = hudParent

function K.track(c) K.connections[#K.connections + 1] = c return c end
function K.onUnload(f) K.cleanups[#K.cleanups + 1] = f end

--==========================================================================
--  Signal / Trove (Kicia's own small versions)
--==========================================================================
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _handlers = {} }, Signal) end
function Signal:Connect(fn)
    local h = { fn = fn, connected = true }
    table.insert(self._handlers, h)
    local sig = self
    return {
        Connected = true,
        Disconnect = function(c)
            if not h.connected then return end
            h.connected = false
            c.Connected = false
            local i = table.find(sig._handlers, h)
            if i then table.remove(sig._handlers, i) end
        end,
    }
end
function Signal:Once(fn)
    local c
    c = self:Connect(function(...) c:Disconnect() fn(...) end)
    return c
end
function Signal:Fire(...)
    local list = table.clone(self._handlers)
    for _, h in ipairs(list) do
        if h.connected then task.spawn(h.fn, ...) end
    end
end
function Signal:FireSync(...)
    for _, h in ipairs(table.clone(self._handlers)) do
        if h.connected then h.fn(...) end
    end
end
function Signal:Destroy() table.clear(self._handlers) end
K.Signal = Signal

local Trove = {}
Trove.__index = Trove
function Trove.new(name) return setmetatable({ _name = name, _items = {} }, Trove) end
local function cleanItem(o)
    local t = typeof(o)
    if t == "RBXScriptConnection" then o:Disconnect()
    elseif t == "Instance" then pcall(function() o:Destroy() end)
    elseif t == "thread" then pcall(task.cancel, o)
    elseif type(o) == "function" then pcall(o)
    elseif type(o) == "table" then
        --  some objects (Kicia's signal connections) error on unknown fields
        local function member(k)
            local ok, v = pcall(function() return o[k] end)
            return ok and type(v) == "function" and v or nil
        end
        local cancel, getStatus = member("cancel"), member("getStatus")
        if cancel and getStatus then pcall(cancel, o) return end
        local destroy = member("Destroy")
        if destroy then pcall(destroy, o) return end
        local disconnect = member("Disconnect")
        if disconnect then pcall(disconnect, o) end
    end
end
function Trove:Add(o) table.insert(self._items, o) return o end
function Trove:Connect(sig, fn) return self:Add(sig:Connect(fn)) end
function Trove:Extend() return self:Add(Trove.new(self._name)) end
function Trove:Remove(o, keep)
    local i = table.find(self._items, o)
    if i then
        table.remove(self._items, i)
        if not keep then cleanItem(o) end
    end
end
--  Promise held until it settles; cancelled if the trove is cleaned first.
function Trove:AddPromise(promise)
    if tostring(promise:getStatus()) == "Started" then
        self:Add(promise)
        promise:finally(function()
            if not self._cleaning then self:Remove(promise, true) end
        end)
    end
    return promise
end
--  Sub-trove that cleans itself up when `instance` is destroyed.
function Trove:AttachExtend(instance)
    local sub = self:Extend()
    sub:Connect(instance.Destroying, function() self:Remove(sub) end)
    return sub
end
function Trove:Clean()
    local items = self._items
    self._items = {}
    self._cleaning = true
    for i = #items, 1, -1 do cleanItem(items[i]) end
    self._cleaning = false
end
Trove.Destroy = Trove.Clean
K.Trove = Trove

--==========================================================================
--  Kicia's constant pool (v86[...]) as recovered from usage in the dump
--==========================================================================
local C = {
    [3] = "Toggle", [9] = 20, [12] = 12, [18] = "0", [26] = 4, [34] = true, [44] = "Enabled",
    [45] = 90, [48] = 2, [53] = 20, [55] = "Mode", [56] = 2, [62] = 0.1, [63] = 1, [68] = "table",
    [75] = "None", [83] = 64, [91] = 100, [95] = "number", [101] = 0.5, [108] = 255, [116] = "boolean",
    [118] = 16, [122] = 8, [126] = 0.15, [127] = "CFrame", [128] = "Frame", [133] = 10, [137] = 256,
    [147] = 0.1, [149] = 1, [153] = false, [155] = 3, [160] = 50, [162] = 8, [165] = "string",
    [170] = 9, [173] = 0.88, [175] = 5, [186] = 0, [192] = 30, [195] = 0.7,
}
K.C = C

--==========================================================================
--  Kicia's own UI, settings store and Combat menu (lifted from the dump)
--==========================================================================
local v86 = {
    [2] = "ReactiveStore",
    [3] = "Toggle",
    [4] = "UIListLayout",
    [5] = "BackgroundColor3",
    [6] = 0,
    [7] = 60,
    [8] = 60,
    [9] = 20,
    [12] = 12,
    [13] = 14,
    [14] = "Settings",
    [15] = 120,
    [16] = "min",
    [17] = 200,
    [18] = "0",
    [19] = 200,
    [20] = "Vector3",
    [21] = "Always",
    [22] = "",
    [23] = 1.4707963267948965,
    [24] = "Roboto",
    [25] = 24,
    [26] = 4,
    [27] = "Color",
    [28] = 0.2,
    [29] = "Size",
    [30] = 0.35,
    [31] = 29,
    [32] = 24,
    [33] = "Button",
    [34] = true,
    [35] = "ConfigManager",
    [36] = "ApplyMigrations",
    [37] = "TextBounds",
    [38] = "DeleteFile",
    [39] = "Slider",
    [40] = "...",
    [42] = "left",
    [43] = "Proggy Clean",
    [44] = "Enabled",
    [45] = 90,
    [46] = "UIGradient",
    [47] = "CanvasGroup",
    [48] = 0.3,
    [49] = 2,
    [50] = "Side",
    [51] = " ",
    [52] = "BottomRight",
    [53] = 92,
    [54] = 6,
    [55] = "Mode",
    [56] = 2,
    [57] = "TextColor",
    [58] = 80,
    [59] = "Font",
    [60] = 29,
    [61] = 20,
    [62] = 0.1,
    [63] = 1,
    [64] = "ScrollingFrame",
    [65] = 200,
    [66] = 0.5,
    [67] = 100,
    [68] = "table",
    [69] = "Catalog unavailable",
    [70] = "GradientDark",
    [71] = 10,
    [72] = 12,
    [73] = "Keybind",
    [74] = 0.9,
    [75] = "None",
    [76] = "LoadFromFile",
    [77] = "FireServer",
    [78] = 720,
    [79] = 255,
    [80] = "Text",
    [81] = 1,
    [82] = "Realize() can only be called on the root",
    [83] = 64,
    [84] = 0.5,
    [85] = "UIStroke",
    [87] = 0.8,
    [88] = "TabHighlight",
    [89] = "Loading",
    [90] = "Gradient",
    [91] = 100,
    [92] = "TextButton",
    [93] = "ColorSequence",
    [94] = "Options",
    [95] = "number",
    [96] = "Unselected",
    [97] = "Mode",
    [98] = "UICorner",
    [99] = "ExportToJson",
    [100] = 14,
    [101] = 0.5,
    [102] = 231,
    [103] = 52,
    [104] = "Fonts",
    [105] = 0.85,
    [106] = "Menu Keybind",
    [107] = 40,
    [108] = 255,
    [109] = 77,
    [110] = 70,
    [111] = "Fetching items...",
    [112] = "Invisible",
    [113] = "UIPadding",
    [114] = "primary",
    [115] = "Color3",
    [116] = "boolean",
    [118] = 16,
    [119] = 159,
    [120] = "Outline",
    [121] = "ImageButton",
    [122] = 8,
    [123] = 19,
    [124] = "X",
    [125] = "Proggy Tiny",
    [126] = 0.15,
    [127] = "CFrame",
    [128] = "Frame",
    [129] = "Show Watermark",
    [131] = "AbsoluteSize",
    [132] = "Breathing",
    [133] = 10,
    [134] = "GradientTop",
    [135] = "TextLabel",
    [136] = "Unselected Text",
    [137] = 256,
    [138] = 0.85,
    [139] = "Accent",
    [140] = "danger",
    [141] = "GradientDeep",
    [142] = "Silent Load",
    [143] = 32,
    [144] = 20,
    [145] = "Dialog has been destroyed",
    [146] = "ImageLabel",
    [147] = 0.1,
    [148] = "TextBox",
    [149] = 1,
    [150] = "stop",
    [151] = "family",
    [153] = false,
    [154] = "ScrollBarImageColor3",
    [155] = 3,
    [156] = "ImageColor3",
    [157] = 20,
    [158] = "secondary",
    [159] = 20,
    [160] = 50,
    [161] = 0.5,
    [162] = 8,
    [163] = 80,
    [164] = "hue",
    [165] = "string",
    [166] = "family",
    [167] = "TextColor3",
    [168] = "ElementBackground",
    [169] = "FromJson",
    [170] = 9,
    [172] = "none",
    [173] = 0.88,
    [174] = "Unselected",
    [175] = 5,
    [176] = "UISizeConstraint",
    [177] = "Try a different search.",
    [178] = "ElementBackground",
    [181] = 10,
    [182] = "HttpService",
    [183] = 72,
    [184] = "Color",
    [186] = 0,
    [187] = "GradientMid",
    [189] = "Position",
    [190] = "Search...",
    [191] = "TabShadow",
    [192] = 30,
    [193] = 0,
    [194] = "Hold",
    [195] = 0.7,
    [196] = "Viewport",
    [197] = "Y",
    [198] = 400,
    [199] = "Unload",
    [200] = 26,
}
--  Environment Kicia's modules expect: the module table and the aliases its
--  loader set up before them (v102 = rawget, v103 = rawset, v107 = pcall).
local tbl17 = { cache = {} }
local v102, v103, v107 = rawget, rawset, pcall
--  The obfuscator's integrity counters. Every check in the lifted code has one
--  branch that hangs and one that runs the real code; these values sit inside
--  the window where all of them take the real branch (n26 in [4790, 4809),
--  n25 in [3866, 3887]).
local n25, n26 = 3870, 4800
local flag2, flag3 = true, true
local function n29() return 0 end
local cloneref = K.fn("cloneref") or function(x) return x end
local gethui = K.fn("gethui") or function() return game:GetService("CoreGui") end
local getthreadidentity = K.fn("getthreadidentity") or K.fn("getidentity") or function() return 8 end
local setthreadidentity = K.fn("setthreadidentity") or K.fn("setidentity") or function() end
--  The rest of the loader's locals (clonefunction'd so hooks on them can't see us).
local function clonefn(f)
    local c = K.fn("clonefunction")
    if c and f then
        local ok, r = pcall(c, f)
        if ok and r then return r end
    end
    return f
end
local fireServer = clonefn(Instance.new("RemoteEvent").FireServer)
local fireServer2 = clonefn(Instance.new("UnreliableRemoteEvent").FireServer)
local v104 = clonefn(K.fn("sethiddenproperty"))
local v108 = clonefn(K.fn("setfflag")) or function() end
local v109 = clonefn(K.fn("isexecutorclosure")) or function() return false end
local v110 = clonefn(K.fn("setrawmetatable")) or setmetatable
local v111 = clonefn(K.fn("getrawmetatable")) or getmetatable
local v112 = clonefn(v111(game).__newindex)
local v113 = clonefn(v111(game).__index)
local v114 = clonefn(game.FindFirstChildOfClass)
local function n27() return 0 end
local firetouchinterest = K.fn("firetouchinterest") or function() end
local getconnections = K.fn("getconnections") or function() return {} end
local setclipboard = K.fn("setclipboard") or K.fn("toclipboard") or function() end
local InstanceHandle
pcall(function() InstanceHandle = getfenv(0).InstanceHandle end)
if InstanceHandle == nil then pcall(function() InstanceHandle = getgenv().InstanceHandle end) end
if InstanceHandle == nil then InstanceHandle = { new = function(x) return x end } end
--  The modules the decompiler lost (their bodies are `fn35(...) end` in
--  the dump), rebuilt from how the rest of Kicia's code calls them.

--  k: Trove
tbl17.k = function() return { new = function(name) return Trove.new(name) end } end

--  w: viewport / pointer / key / path helpers
do
    local UIS = UserInputService
    local GuiService = game:GetService("GuiService")
    local function camera() return workspace.CurrentCamera end
    local W = {}
    function W.appendPath(path, key)
        local p = table.clone(path)
        table.insert(p, key)
        return p
    end
    function W.currentViewportSize()
        local c = camera()
        return c and c.ViewportSize or Vector2.new(1920, 1080)
    end
    function W.connectCurrentCameraViewport(trove, cb)
        local inner = trove:Extend()
        local function bind()
            inner:Clean()
            local c = camera()
            if c == nil then return end
            inner:Connect(c:GetPropertyChangedSignal("ViewportSize"), function() cb(c.ViewportSize) end)
            cb(c.ViewportSize)
        end
        trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bind)
        bind()
    end
    function W.absoluteToLayerOffset(layer, pos)
        return pos - layer.AbsolutePosition
    end
    function W.clampOffsetToViewport(x, y, size)
        local vp = W.currentViewportSize()
        return math.clamp(x, 0, math.max(0, vp.X - size.X)), math.clamp(y, 0, math.max(0, vp.Y - size.Y))
    end
    function W.clampGuiToViewport(gui)
        local vp = W.currentViewportSize()
        local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
        local dx = math.clamp(ap.X, 0, math.max(0, vp.X - as.X)) - ap.X
        local dy = math.clamp(ap.Y, 0, math.max(0, vp.Y - as.Y)) - ap.Y
        if dx ~= 0 or dy ~= 0 then
            local p = gui.Position
            gui.Position = UDim2.new(p.X.Scale, p.X.Offset + dx, p.Y.Scale, p.Y.Offset + dy)
        end
    end
    function W.snapPosition(u)
        return UDim2.new(u.X.Scale, math.round(u.X.Offset), u.Y.Scale, math.round(u.Y.Offset))
    end
    function W.onScreenKeyboardTop()
        local ok, visible = pcall(function() return UIS.OnScreenKeyboardVisible end)
        if not ok or not visible then return nil end
        local ok2, pos = pcall(function() return UIS.OnScreenKeyboardPosition end)
        return ok2 and pos and pos.Y or nil
    end
    function W.connectOnScreenKeyboard(trove, cb)
        pcall(function() trove:Connect(UIS:GetPropertyChangedSignal("OnScreenKeyboardVisible"), cb) end)
        pcall(function() trove:Connect(UIS:GetPropertyChangedSignal("OnScreenKeyboardPosition"), cb) end)
    end
    function W.getPointerPosition()
        return UIS:GetMouseLocation()
    end
    function W.matchesPointerDrag(input, started, movement)
        if started ~= nil and started.UserInputType == Enum.UserInputType.Touch then return input == started end
        return input.UserInputType == movement
    end
    function W.round(v, step)
        if step == nil or step == 0 then return v end
        return math.round(v / step) * step
    end
    W.KeyNames = {
        [Enum.UserInputType.MouseButton1] = "MB1", [Enum.UserInputType.MouseButton2] = "MB2",
        [Enum.UserInputType.MouseButton3] = "MB3", [Enum.KeyCode.LeftShift] = "LShift",
        [Enum.KeyCode.RightShift] = "RShift", [Enum.KeyCode.LeftControl] = "LCtrl",
        [Enum.KeyCode.RightControl] = "RCtrl", [Enum.KeyCode.LeftAlt] = "LAlt", [Enum.KeyCode.RightAlt] = "RAlt",
    }
    function W.serializeKey(key)
        if typeof(key) ~= "EnumItem" then return nil end
        return tostring(key.EnumType) .. "." .. key.Name
    end
    function W.deserializeKey(s)
        if type(s) ~= "string" then return nil end
        local kind, name = s:match("^(%w+)%.(%w+)$")
        if kind == nil then return nil end
        local ok, v = pcall(function() return Enum[kind][name] end)
        return ok and v or nil
    end
    function W.findScrollingAncestor(inst)
        local p = inst and inst.Parent
        while p ~= nil do
            if p:IsA("ScrollingFrame") then return p end
            p = p.Parent
        end
        return nil
    end
    function W.isEffectivelyVisible(gui)
        local p = gui
        while p ~= nil and p ~= game do
            if p:IsA("GuiObject") and not p.Visible then return false end
            if p:IsA("LayerCollector") then return p.Enabled end
            p = p.Parent
        end
        return false
    end
    function W.ensureStorageDirectories(dir)
        local isf, mkf = K.fn("isfolder"), K.fn("makefolder")
        if not (isf and mkf) or type(dir) ~= "string" then return end
        local function make(path)
            local acc
            for part in path:gmatch("[^/]+") do
                acc = acc and (acc .. "/" .. part) or part
                pcall(function() if not isf(acc) then mkf(acc) end end)
            end
        end
        make(dir)
        make(dir .. "/configs")
    end
    tbl17.w = function() return W end
end

--  P: two-way link between a control and a settings path. Sliders ask for
--  Debounce so dragging writes once per short burst instead of every frame.
do
    local P = {}
    function P.bind(trove, config, control, path, opts)
        local debounce = opts ~= nil and opts.Debounce == true
        local writeBack = opts ~= nil and opts.WriteBack or nil
        control:Set(config:Get(path), true)
        trove:Connect(config:Changed(path), function(v) control:Set(v, true) end)
        local pending, scheduled = nil, false
        local function write(v)
            if writeBack then writeBack(v) else config:Set(path, v) end
        end
        trove:Connect(control.Changed, function(v)
            if not debounce then write(v) return end
            pending = v
            if scheduled then return end
            scheduled = true
            task.delay(0.05, function()
                scheduled = false
                write(pending)
            end)
        end)
    end
    tbl17.P = function() return P end
end

--  c5: the critically damped Spring (Position, Velocity, Target, Speed, Damper).
do
    local Spring = {}
    local function posVel(self, now)
        local p0, v0, p1, d, s = self._p0, self._v0, self._target, self._damper, self._speed
        local t = s * (now - self._t0)
        local d2 = d * d
        local h, si, co
        if d2 < 1 then
            h = math.sqrt(1 - d2)
            local ep = math.exp(-d * t) / h
            co, si = ep * math.cos(h * t), ep * math.sin(h * t)
        elseif d2 == 1 then
            h = 1
            local ep = math.exp(-d * t) / h
            co, si = ep, ep * t
        else
            h = math.sqrt(d2 - 1)
            local u, v = math.exp((-d + h) * t) / (2 * h), math.exp((-d - h) * t) / (2 * h)
            co, si = u + v, u - v
        end
        local a0, a1 = h * co + d * si, 1 - (h * co + d * si)
        local a2 = si / s
        local b0, b1, b2 = -s * si, s * si, h * co - d * si
        return a0 * p0 + a1 * p1 + a2 * v0, b0 * p0 + b1 * p1 + b2 * v0
    end
    function Spring.new(initial, clock)
        initial = initial or 0
        clock = clock or os.clock
        return setmetatable({ _clock = clock, _t0 = clock(), _p0 = initial, _v0 = 0 * initial, _target = initial,
            _damper = 1, _speed = 1 }, Spring)
    end
    function Spring:Impulse(v) self.Velocity = self.Velocity + v end
    function Spring:SetTarget(value, doNotAnimate)
        if doNotAnimate then
            self._p0, self._v0, self._target, self._t0 = value, 0 * value, value, self._clock()
        else
            self.Target = value
        end
    end
    function Spring:TimeSkip(delta)
        local now = self._clock()
        local p, v = posVel(self, now + delta)
        self._p0, self._v0, self._t0 = p, v, now
    end
    Spring.__index = function(self, k)
        if Spring[k] then return Spring[k] end
        if k == "Value" or k == "Position" or k == "p" then local p = posVel(self, self._clock()) return p
        elseif k == "Velocity" or k == "v" then local _, v = posVel(self, self._clock()) return v
        elseif k == "Target" or k == "t" then return self._target
        elseif k == "Damper" or k == "d" then return self._damper
        elseif k == "Speed" or k == "s" then return self._speed
        elseif k == "Clock" then return self._clock end
        return nil
    end
    Spring.__newindex = function(self, k, v)
        local now = self._clock()
        if k == "Value" or k == "Position" or k == "p" then
            local _, vel = posVel(self, now)
            self._p0, self._v0 = v, vel
        elseif k == "Velocity" or k == "v" then
            local pos = posVel(self, now)
            self._p0, self._v0 = pos, v
        elseif k == "Target" or k == "t" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._target = pos, vel, v
        elseif k == "Damper" or k == "d" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._damper = pos, vel, v
        elseif k == "Speed" or k == "s" then
            local pos, vel = posVel(self, now)
            self._p0, self._v0, self._speed = pos, vel, v < 0 and 0 or v
        elseif k == "Clock" then
            local pos, vel = posVel(self, now)
            self._clock, self._t0, self._p0, self._v0 = v, v(), pos, vel
            return
        else
            rawset(self, k, v)
            return
        end
        self._t0 = now
    end
    tbl17.c5 = function() return Spring end
end

--  ca: the AI aim mode's network weights. They are not in the dump; cc falls
--  back to Linear movement without them.
tbl17.ca = function() return nil end

--  hH: weather emitter specs and lightning / thunder constants. Kicia's own
--  values are not in the dump; these fit every field the weather module reads
--  and use particle textures that ship with Roblox.
do
    local soft = "rbxasset://textures/particles/smoke_main.dds"
    local sparkle = "rbxasset://textures/particles/sparkles_main.dds"
    local function spec(t)
        t.RotationMin, t.RotationMax = t.RotationMin or 0, t.RotationMax or 360
        t.RotationSpeedMin, t.RotationSpeedMax = t.RotationSpeedMin or -40, t.RotationSpeedMax or 40
        return t
    end
    local W = {
        EmitterSpecsByPreset = {
            Snow = {
                spec({ Texture = soft, TransparencyMax = 0.15, LifetimeMin = 6, LifetimeMax = 9, BaseRate = 220,
                    SpeedMin = 6, SpeedMax = 10, SizeStart = 0.35, SizeEnd = 0.25, BaseSpread = 0.4, BaseAccelerationY = -1 }),
                spec({ Texture = sparkle, TransparencyMax = 0.35, LifetimeMin = 6, LifetimeMax = 9, BaseRate = 60,
                    SpeedMin = 5, SpeedMax = 8, SizeStart = 0.2, SizeEnd = 0.15, BaseSpread = 0.6, BaseAccelerationY = -0.5 }),
            },
            Rain = {
                spec({ Texture = soft, TransparencyMax = 0.35, LifetimeMin = 1.2, LifetimeMax = 1.8, BaseRate = 600,
                    SpeedMin = 70, SpeedMax = 90, SizeStart = 0.12, SizeEnd = 0.1, BaseSpread = 0.05, BaseAccelerationY = -40,
                    RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0,
                    Orientation = Enum.ParticleOrientation.VelocityParallel }),
            },
            Blizzard = {
                spec({ Texture = soft, TransparencyMax = 0.1, LifetimeMin = 3, LifetimeMax = 5, BaseRate = 700,
                    SpeedMin = 18, SpeedMax = 28, SizeStart = 0.3, SizeEnd = 0.2, BaseSpread = 0.8, BaseAccelerationY = -6 }),
                spec({ Texture = soft, TransparencyMax = 0.75, LifetimeMin = 3, LifetimeMax = 5, BaseRate = 120,
                    SpeedMin = 14, SpeedMax = 22, SizeStart = 3, SizeEnd = 5, BaseSpread = 1, BaseAccelerationY = -2 }),
            },
        },
        LightningPresetSet = { Rain = true },
        LightningRadiusMin = 20,
        LightningGroundDrop = 40,
        LightningRayLength = 1000,
        LightningJitter = 30,
        ThunderSoundId = "",
        ThunderSpeed = 340,
        ThunderVolumeFloor = 0.2,
        ThunderFalloff = 600,
        ThunderPitchMin = 0.85,
        ThunderPitchMax = 1.1,
    }
    tbl17.hH = function() return W end
end

--  iQ: the Visuals > Player ESP page. Its builder is lost; rebuilt with the
--  same menu calls Kicia's other pages use, over Kicia's own Esp settings.
tbl17.iQ = function()
    return function(_, _, grid)
        local enable = tbl17.h6()
        local fonts = tbl17.az().Order
        local function P(...) return { "Esp", ... } end

        local main = grid:AddSection({ Title = "Player ESP", Side = "left" })
        enable(main, "Enable ESP", { "Always", "Toggle", "Hold" }, P("Main"), true)
        main:AddDropdown({ Label = "Box Fit", Options = { "Static", "Dynamic" }, Config = P("Main", "Mode") })

        local look = grid:AddSection({ Title = "Text", Side = "right" })
        look:AddToggle({ Label = "Use Display Names", Config = P("Settings", "UseDisplayName") })
        look:AddDropdown({ Label = "Font", Options = fonts, Config = P("Settings", "Font") })
        look:AddSlider({ Label = "Font Size", Min = 8, Max = 32, Config = P("Settings", "FontSize") })
        look:AddDropdown({ Label = "Text Case", Options = { "Standard", "UPPERCASE", "lowercase" }, Config = P("Settings", "TextCase") })
        look:AddDropdown({ Label = "Text Surround", Options = { "None", "[]", "()", "<>", "{}" }, Config = P("Settings", "TextSurround") })
        look:AddDivider({ Label = "Flags" })
        look:AddDropdown({ Label = "Flag Font", Options = fonts, Config = P("Settings", "FlagFont") })
        look:AddSlider({ Label = "Flag Font Size", Min = 6, Max = 24, Config = P("Settings", "FlagFontSize") })
        look:AddDropdown({ Label = "Flag Text Case", Options = { "Standard", "UPPERCASE", "lowercase" }, Config = P("Settings", "FlagTextCase") })
        look:AddDropdown({ Label = "Flag Surround", Options = { "None", "[]", "()", "<>", "{}" }, Config = P("Settings", "FlagTextSurround") })
        look:AddGroup({ Source = look:AddToggle({ Label = "Scale With Distance", Config = P("Settings", "DistanceScaling") }) })
            :AddSlider({ Label = "Reference Distance", Min = 10, Max = 300, Config = P("Settings", "DistanceScalingRef") })

        local function side(title, key, where)
            local s = grid:AddSection({ Title = title, Side = where })
            local function Q(...) return P(key, ...) end
            --  Kicia's ESP draws a side only when Main AND this side are enabled
            enable(s, "Enable " .. title .. " ESP", { "Always", "Toggle", "Hold" }, P(key), true)
            local function color(label, path, transparency)
                local t = s:AddToggle({ Label = label, Config = Q(path, "Enabled") })
                s:AddColor({ Row = t.Row, Config = Q(path, "Color"), Transparency = transparency and Q(path, "Transparency") or nil, Alpha = transparency or nil })
                return t
            end
            local function gradient(label, path)
                local t = s:AddToggle({ Label = label, Config = Q(path, "Enabled") })
                s:AddColor({ Row = t.Row, Gradient = "editable", Alpha = true, Config = Q(path, "Color"), Transparency = Q(path, "Transparency") })
                return t
            end
            color("Name", "Name", true)
            s:AddGroup({ Source = color("Box", "Box") }):AddDropdown({ Label = "Style", Options = { "Full", "Corner" }, Config = Q("Box", "Style") })
            gradient("Filled Box", "FilledBox")
            local hb = s:AddToggle({ Label = "Health Bar", Config = Q("HealthBar", "Enabled") })
            s:AddColor({ Row = hb.Row, Gradient = "editable", Config = Q("HealthBar", "Color") })
            s:AddGroup({ Source = hb }):AddDropdown({ Label = "Color Mode", Options = { "Solid", "Gradient", "Reactive" }, Config = Q("HealthBar", "ColorMode") })
            color("Health Number", "HealthNumber")
            color("Held Weapon", "HeldWeapon", true)
            local ab = s:AddToggle({ Label = "Ammo Bar", Config = Q("AmmoBar", "Enabled") })
            s:AddColor({ Row = ab.Row, Gradient = "editable", Config = Q("AmmoBar", "Color") })
            s:AddGroup({ Source = ab }):AddDropdown({ Label = "Color Mode", Options = { "Solid", "Gradient", "Reactive" }, Config = Q("AmmoBar", "ColorMode") })
            color("Distance", "Distance")
            color("Rank", "Rank")
            color("Win Streak", "Winstreak")
            color("Deflecting", "Deflecting", true)
            local ch = s:AddGroup({ Source = s:AddToggle({ Label = "Chams", Config = Q("Chams", "Enabled") }) })
            ch:AddDropdown({ Label = "Kind", Options = { "Legacy", "Highlight" }, Config = Q("Chams", "Kind") })
            local fill = ch:AddLabel({ Label = "Fill" })
            ch:AddColor({ Row = fill.Row, Alpha = true, Config = Q("Chams", "InnerColor"), Transparency = Q("Chams", "InnerTransparency") })
            local outline = ch:AddLabel({ Label = "Outline" })
            ch:AddColor({ Row = outline.Row, Alpha = true, Config = Q("Chams", "OutlineColor"), Transparency = Q("Chams", "OutlineTransparency") })
            local glow = ch:AddToggle({ Label = "Glow", Config = Q("Chams", "Glow") })
            ch:AddColor({ Row = glow.Row, Config = Q("Chams", "GlowColor") })
            s:AddGroup({ Source = gradient("Skeleton", "Skeleton") })
                :AddSlider({ Label = "Thickness", Min = 1, Max = 6, Config = Q("Skeleton", "Thickness") })
            local hm = s:AddGroup({ Source = color("Head Marker", "HeadMarker", true) })
            hm:AddDropdown({ Label = "Shape", Options = { "Cross", "Circle", "Diamond" }, Config = Q("HeadMarker", "Shape") })
            hm:AddToggle({ Label = "Filled", Config = Q("HeadMarker", "Filled") })
            local hmo = hm:AddToggle({ Label = "Outline", Config = Q("HeadMarker", "Outline") })
            hm:AddColor({ Row = hmo.Row, Alpha = true, Config = Q("HeadMarker", "OutlineColor"), Transparency = Q("HeadMarker", "OutlineTransparency") })
            local tr = s:AddGroup({ Source = gradient("Tracer", "Tracer") })
            tr:AddSlider({ Label = "Thickness", Min = 1, Max = 6, Config = Q("Tracer", "Thickness") })
            tr:AddDropdown({ Label = "From", Options = { "Bottom", "Center", "Top", "Mouse" }, Config = Q("Tracer", "Origin") })
            tr:AddDropdown({ Label = "To", Options = { "Feet", "Head" }, Config = Q("Tracer", "Target") })
            local tro = tr:AddToggle({ Label = "Outline", Config = Q("Tracer", "Outline") })
            tr:AddColor({ Row = tro.Row, Alpha = true, Config = Q("Tracer", "OutlineColor"), Transparency = Q("Tracer", "OutlineTransparency") })
            tr:AddSlider({ Label = "Outline Thickness", Min = 1, Max = 6, Config = Q("Tracer", "OutlineThickness") })
        end
        side("Enemies", "Enemy", "left")
        side("Teammates", "Team", "right")
    end
end

--  eZ: Kicia's online user service (sessions with user.kicia.cc). Offline here:
--  nothing is sent anywhere, connecting is refused.
tbl17.eZ = function()
    local Offline = {}
    Offline.__index = Offline
    function Offline.new()
        local Signal = tbl17.g()
        local self = setmetatable({ Connected = Signal.new(), ShowActiveChanged = Signal.new(),
            PeerPayloadReceived = Signal.new(), PeerRemoved = Signal.new(), ShowActivated = Signal.new(),
            _playerByHash = {} }, Offline)
        self._leaving = Players.PlayerRemoving:Connect(function(p) self.PeerRemoved:Fire(p) end)
        return self
    end
    function Offline:ShouldShowActive() return false end
    function Offline:IsConnected() return false end
    function Offline:Send() return tbl17.a().err("UserServer", "offline", "the online user service is disabled") end
    function Offline:FindPlayerByHash() return nil end
    function Offline:Connect() return tbl17.ay().reject("the online user service is disabled") end
    function Offline:Destroy()
        self.Connected:Destroy()
        self.ShowActiveChanged:Destroy()
        self.PeerPayloadReceived:Destroy()
        self.PeerRemoved:Destroy()
        self.ShowActivated:Destroy()
        self._leaving:Disconnect()
    end
    return Offline
end
--  Kicia's own modules, lifted from the dump (extract.py). Do not edit by hand.
do -- a
local function fn35()
return {
ok = function(arg)
return { Ok = true, Value = arg }
end,
err = function(arg, arg2, arg3)
return { Ok = false, Error = { Source = arg, Stage = arg2, Detail = arg3, Timestamp = os.clock() } }
end,
formatError = function(arg)
local v115 = tostring
local detail = arg.Detail
return string.format("'%s' @ %s failed during stage '%s'; %s", tostring(arg.Source), tostring(arg.Timestamp), tostring(arg.Stage), v115(detail))
end,
VoidOk = table.freeze({ Ok = true, Value = nil }),
}
end

tbl17.a = function()
local a = tbl17.cache.a

if not a then
a = { c = fn35() }
tbl17.cache.a = a
end

return a.c
end
end
do -- b
local function fn35()
tbl17.a()
local v115 = nil

return {
use = function(arg)
v115 = arg
end,
get = function()
assert(v115)
return v115
end,
}
end

tbl17.b = function()
local b = tbl17.cache.b

if not b then
b = { c = fn35() }
tbl17.cache.b = b
end

return b.c
end
end
do -- d
local function fn35()
local function copy(t)
if type(t) ~= "table" then return t end
local o = {}
for k, v in next, t do o[k] = copy(v) end
return setmetatable(o, getmetatable(t))
end
return copy
end

tbl17.d = function()
local d = tbl17.cache.d

if not d then
d = { c = fn35() }
tbl17.cache.d = d
end

return d.c
end
end
do -- e
local function fn35()
local v115 = tbl17.a()

return function(arg, arg2)
local parts = arg:split("/")
arg2 = arg2 or ""

for k, v116 in parts, nil, nil do
if v116 == "" then
continue
end
local str7 = k == #parts and "" or "/"
local v117 = tostring
arg2 ..= string.format("%s%s", tostring(v116), v117(str7))
if isfile(arg2) then
return v115.err("ensureFolderPath", "collision", string.format("expected `%s` to be non-existant or a folder, found a file instead.", tostring(arg2)))
end

if not isfolder(arg2) then
makefolder(arg2)
end
end

return v115.VoidOk
end
end

tbl17.e = function()
local e = tbl17.cache.e

if not e then
e = { c = fn35() }
tbl17.cache.e = e
end

return e.c
end
end
do -- f
local function fn35()
local v115 = tbl17.a()
local v116 = tbl17.d()
local v117 = tbl17.e()
local v118 = cloneref(game:GetService(v86[182]))
local index2 = {}
index2.__index = index2

local function fn36(arg)
local v119 = v86[68]
if type(arg) == v119 then
return v116(arg)
end
return arg
end

local function fn37(arg)
if arg == nil or arg == "" then
return ""
end

if arg:sub(-v86[63]) == "/" then
return arg
end
return arg .. "/"
end

local function fn38(arg)
if arg == "" then
return v115.err("ConfigManager", "validateConfigName", "config name cannot be empty")
end

if arg:find("/") or arg:find("\\") then
return v115.err("ConfigManager", "validateConfigName", "expected no directory traversal")
end
return v115.VoidOk
end

index2.new = function(arg)
assert(type(arg.CurrentVersion) == "number" and arg.CurrentVersion >= v86[63], "expected `CurrentVersion` >= 1")
local v119 = fn37(arg.SavePath)

if v119 ~= "" then
local v120 = v117(v119)

if not v120.Ok then
error(v120.Error.Detail, 2)
end
end

local serialize = arg.Serialize or function(arg2)
return arg2
end

local deserialize = arg.Deserialize or function(arg2)
return arg2
end

local v120 = fn36(arg.DefaultConfig)

local tbl18 = {
Data = fn36(v120),
_defaultConfig = v120,
_currentVersion = arg.CurrentVersion,
_legacyVersion = arg.LegacyVersion or 1,
_savePath = v119,
_migrations = arg.Migrations or {},
_serialize = serialize,
_deserialize = deserialize,
}

setmetatable(tbl18, index2)
return tbl18
end

index2._ConfigPath = function(arg, arg2)
if arg2:match("%.json$") then
return arg._savePath .. arg2
end
local v119 = tostring
return string.format("%s%s.json", tostring(arg._savePath), v119(arg2))
end

index2._ApplyMigrations = function(arg, arg2, arg3)
if arg2 < 1 then
return v115.err("ConfigManager", "ApplyMigrations", string.format("invalid file version %s", tostring(arg2)))
end

if arg._currentVersion < arg2 then
local v119 = tostring
local currentVersion = arg._currentVersion
return v115.err("ConfigManager", "ApplyMigrations", string.format("file version %s is newer than current version %s", tostring(arg2), v119(currentVersion)))
end

local v119 = fn36(arg3)

while arg2 < arg._currentVersion do
local v120 = arg._migrations[arg2]
if v120 == nil then
local v121 = tostring
return v115.err("ConfigManager", v86[36], string.format("missing migration for version %s -> %s", tostring(arg2), v121(arg2 + 1)))
end
local v121, v122 = v107(v120, v119, arg2, arg2 + v86[63])
if not v121 then
local v123 = tostring
return v115.err(v86[35], "ApplyMigrations", string.format("migration %s -> %s failed: %s", tostring(arg2), tostring(arg2 + v86[63]), v123(v122)))
end

if v122 == nil then
local v123 = tostring
return v115.err("ConfigManager", "ApplyMigrations", string.format("migration %s -> %s returned nil", tostring(arg2), v123(arg2 + 1)))
end
arg2 += 1
v119 = v122
end

return v115.ok(v119)
end

index2.SetData = function(arg, data)
arg.Data = data
end

index2.Reset = function(arg)
local v119 = v116(arg._defaultConfig)
arg.Data = v119
return v119
end

index2.ToJson = function(arg, arg2)
if arg2 == nil then
arg2 = arg.Data
end

local v119, v120 = v107(arg._serialize, arg2)
if not v119 then
return v115.err("ConfigManager", "ToJson", string.format("failed to serialize config: %s", tostring(v120)))
end
local v121, v122 = v107(v118.JSONEncode, v118, { Version = arg._currentVersion, Data = v120 })
if not v121 then
return v115.err("ConfigManager", "ToJson", string.format("failed to encode config payload as JSON: %s", tostring(v122)))
end
return v115.ok(v122)
end

index2.FromJson = function(arg, arg2)
local v119, v120 = v107(v118.JSONDecode, v118, arg2)
if not v119 then
return v115.err(v86[35], v86[169], string.format("failed to decode JSON payload: %s", tostring(v120)))
end

if type(v120) ~= "table" then
return v115.err("ConfigManager", "FromJson", "expected decoded config JSON to be a table")
end
local legacyVersion = arg._legacyVersion
local version = v120.Version
local data = v120.Data

if version == nil and data == nil then
version = v120.version
data = v120.data
end

if not (type(version) == "number" and data ~= nil) then
data = v120
version = legacyVersion
end

local v121 = arg:_ApplyMigrations(version, data)
if not v121.Ok then
return v115.err("ConfigManager", v86[169], v121.Error.Detail)
end
local v122, v123 = v107(arg._deserialize, v121.Value)
if not v122 then
return v115.err("ConfigManager", "FromJson", string.format("failed to deserialize config data: %s", tostring(v123)))
end

if v123 == nil then
return v115.err("ConfigManager", "FromJson", "deserializer returned nil")
end
arg.Data = v123
return v115.ok(v123)
end

index2._SaveImpl = function(arg, arg2, arg3, arg4)
local v119 = fn38(arg2)
if not v119.Ok then
return v119
end
local v120 = arg:_ConfigPath(arg2)
if arg4 and isfile(v120) then
return v115.err("ConfigManager", "SaveImpl", string.format("path `%s` already exists", tostring(v120)))
end
local v121 = arg:ToJson(arg3)
if not v121.Ok then
return v115.err("ConfigManager", "SaveImpl", v121.Error.Detail)
end
writefile(v120, v121.Value)
return v115.VoidOk
end

index2.SaveToFile = function(arg, arg2, arg3)
return arg:_SaveImpl(arg2, nil, arg3)
end

index2.LoadFromFile = function(arg, arg2)
local v119 = fn38(arg2)
if not v119.Ok then
return v115.err("ConfigManager", v86[76], v119.Error.Detail)
end
local v120 = arg:_ConfigPath(arg2)
if not isfile(v120) then
return v115.err(v86[35], "LoadFromFile", string.format("path `%s` does not exist", tostring(v120)))
end
local v121 = readfile(v120)
return arg:FromJson(v121)
end

index2.Exists = function(arg, arg2)
if not fn38(arg2).Ok then
return v86[153]
end
return isfile(arg:_ConfigPath(arg2))
end

index2.SaveDefaultToFile = function(arg, arg2, arg3)
return arg:_SaveImpl(arg2, arg._defaultConfig, arg3)
end

index2.Delete = function(arg, arg2)
local v119 = fn38(arg2)
if not v119.Ok then
return v119
end
local v120 = arg:_ConfigPath(arg2)
if not isfile(v120) then
return v115.err("ConfigManager", v86[38], string.format("path `%s` does not exist", tostring(v120)))
end
delfile(v120)
return v115.VoidOk
end

index2.AllConfigs = function(arg)
local tbl18 = {}
if arg._savePath == "" then
return tbl18
end

for _, v119 in listfiles(arg._savePath) do
if isfile(v119) then
local match = (v119:match("[/\\]([^/\\]+)$") or v119):match("(.+)%.json$")

if match ~= nil then
table.insert(tbl18, match)
end
end
end

return tbl18
end

return index2
end

tbl17.f = function()
local f = tbl17.cache.f

if not f then
f = { c = fn35() }
tbl17.cache.f = f
end

return f.c
end
end
do -- g
local function fn35()local I;local function W(N,...)local P=I;I=nil;N(...);I=P;end;local function N(...)W(...);while true do W(coroutine.yield());end;end;local W={};W.__index=W;W.Disconnect=function(P)if not P.Connected then return;end;P.Connected=false;if P._signal._handlerListHead==P then P._signal._handlerListHead=P._next;else local a=P._signal._handlerListHead;while a and a._next~=P do a=a._next;end;if a then a._next=P._next;end;end;end;W.Destroy=W.Disconnect;setmetatable(W,{__index=function(P,P)error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(P)),2);end,__newindex=function(P,P,a)error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(P)),2);end});local P={};P.__index=P;P.new=function()return(setmetatable({_handlerListHead=false,_proxyHandler=nil,_yieldedThreads=nil},P));end;P.Wrap=function(a)assert(typeof(a)=="RBXScriptSignal","Argument #1 to Signal.Wrap must be a RBXScriptSignal; got "..typeof(a));local e=P.new();e._proxyHandler=a:Connect(function(...)e:Fire(...);end);return e;end;P.Is=function(a)return type(a)=="table"and getmetatable(a)==P;end;P.Connect=function(a,e)local c=setmetatable({Connected=true,_signal=a,_fn=e,_next=false},W);if a._handlerListHead then c._next=a._handlerListHead;a._handlerListHead=c;else a._handlerListHead=c;end;return c;end;P.ConnectOnce=function(W,a)return W:Once(a);end;P.Once=function(W,a)local e;local c=false;e=W:Connect(function(...)if c then return;end;c=true;e:Disconnect();a(...);end);return e;end;P.GetConnections=function(W)local a,e={},W._handlerListHead;while e do table.insert(a,e);e=e._next;end;return a;end;P.DisconnectAll=function(W)local a=W._handlerListHead;while a do a.Connected=false;a=a._next;end;W._handlerListHead=false;a= v102 (W,"_yieldedThreads");if a then for e in a,nil,nil do if coroutine.status(e)=="suspended"then warn(debug.traceback(e,"signal disconnected; yielded thread cancelled",2));task.cancel(e);end;end;table.clear(W._yieldedThreads);end;end;P.Fire=function(W,...)local a=W._handlerListHead;while a do if a.Connected then W=I;if not W then I=coroutine.create(N);end;task.spawn(I,a._fn,...);end;a=a._next;end;end;P.FireDeferred=function(I,...)local W=I._handlerListHead;while W do local I=W;task.defer(function(...)if I.Connected then I._fn(...);end;end,...);W=W._next;end;end;P.Wait=function(I)local W= v102 (I,"_yieldedThreads");if not W then W={}; v103 (I,"_yieldedThreads",W);end;local N=coroutine.running();W[N]=true;I:Once(function(...)W[N]=nil;if coroutine.status(N)=="suspended"then task.spawn(N,...);end;end);return coroutine.yield();end;P.Destroy=function(I)I:DisconnectAll();local W= v102 (I,"_proxyHandler");if W then W:Disconnect();end;end;return table.freeze({new=P.new,Wrap=P.Wrap,Is=P.Is});end

tbl17.g = function()
local g = tbl17.cache.g

if not g then
local g2 = { c = fn35() }
tbl17.cache.g = g2
g = g2
end

return g.c
end
end
do -- h
local function fn35()
local v115 = tbl17.g()
local index2 = {}
index2.__index = index2
local index3 = {}
index3.__index = index3
index3.Enable = function(l)if l.Connected then return;end;l.Connected=true;l._inner=l._signal._inner:Connect(l._callback);end
index3.Disable = function(l)if not l.Connected then return;end;l.Connected=false;local I=l._inner;if I~=nil then I:Disconnect();end;l._inner=nil;end
index3.Disconnect = index3.Disable
index3.Destroy = index3.Disable
index2.Connect = function(I,W)local N=setmetatable({_signal=I,_callback=W,_inner=nil,Connected=false}, index3 );N:Enable();return N;end
index2.Fire = function(l,I)l._inner:Fire(I);end

index2.FireDeferred = function(arg, arg2)
arg._inner:FireDeferred(arg2)
end

index2.Once = function(arg, arg2)
return arg._inner:Once(arg2)
end

index2.Wait = function(arg)
return arg._inner:Wait()
end

index2.DisconnectAll = function(arg)
arg._inner:DisconnectAll()
end

index2.GetConnections = function(arg)
return arg._inner:GetConnections()
end

index2.Destroy = function(arg)
arg._inner:Destroy()
end

return table.freeze({ new = function()
return (setmetatable({ _inner = v115.new() }, index2))
end })
end

tbl17.h = function()
local h = tbl17.cache.h

if not h then
local h2 = { c = fn35() }
tbl17.cache.h = h2
h = h2
end

return h.c
end
end
do -- i
local function fn35()
local tbl18 = {}

return {
atomic = function(arg)
setmetatable(arg, tbl18)
return arg
end,
isAtomic = function(I)return type(I)=="table"and getmetatable(I)== tbl18 ;end,
}
end

tbl17.i = function()
local i = tbl17.cache.i

if not i then
local i2 = { c = fn35() }
tbl17.cache.i = i2
i = i2
end

return i.c
end
end
do -- j
local function fn35()
if true then
local isAtomic = tbl17.i().isAtomic
local tbl18

tbl18 = {
PathToKey = function(l)return table.concat(l,".");end,
KeyToPath = function(l)return l:split(".");end,
NavigateTo = function(l,I,W)if#I==0 then return nil;end;for N=1,#I,1 do local P=I[N];if N==#I then return l[P];end;l=l[P];if l==nil then if W then return nil;end;error(string.format("Invalid path specified '%s', key %s is nil!",tostring(table.concat(I,".")),tostring(P)),2);elseif type(l)~="table"then if W then return nil;end;error(string.format("Invalid path specified '%s', key %s is not a branch!",tostring(table.concat(I,".")),tostring(P)),2);end;end;return nil;end,
Set = function(I,W,N)for P=1,#W,1 do local a=W[P];if P==#W then I[a]=N;return;end;P=I[a];if P==nil then P={};I[a]=P;elseif type(P)~="table"then local N= tbl18 .PathToKey(W);error(string.format("Invalid path specified '%s', key %s is not a table!",tostring(N),tostring(a)),2);end;I=P;end;end,
ForEachEntry = function(I,W)local N={};local function P(a)for e,c in a,nil,nil do table.insert(N,e);W(N,c);if type(c)=="table"and not  isAtomic (c)then P(c);end;table.remove(N);end;end;P(I);end,
ForEachLeafValue = function(I,W,N)local P={};local function a(e,c)for E,p in e,nil,nil do table.insert(P,E);local e=if c~=nil then c[E]else nil;local c=type(e)=="table";E=if type(p)=="table"and not  isAtomic (p)and not(c and( isAtomic (e)))and(e==nil or c)then(a(p,if c then e else nil))else if c and not  isAtomic (e)then false else N(P,p)==true;table.remove(P);if E then return true;end;end;return false;end;a(I,W);end,
}

return tbl18
end

while v86[34] do
end
end

tbl17.j = function()
local j = tbl17.cache.j

if not j then
local j2 = { c = fn35() }
tbl17.cache.j = j2
j = j2
end

return j.c
end
end
do -- l
local function fn35()
local v115 = tbl17.f()
local v116 = tbl17.h()
local v117 = tbl17.j()
local v118 = tbl17.a()
local v119 = tbl17.g()
local v120 = tbl17.k()
local v121 = tbl17.d()
local isAtomic = tbl17.i().isAtomic
local index2 = {}
index2.__index = index2

index2.new = function(arg)
local ReactiveStore = v120.new("ReactiveStore")

return setmetatable({
_trove = ReactiveStore,
Default = arg.DefaultConfig,
Data = v121(arg.DefaultConfig),
_middleware = {},
_configManager = v115.new({
DefaultConfig = arg.DefaultConfig,
CurrentVersion = arg.CurrentVersion,
LegacyVersion = arg.LegacyVersion,
SavePath = arg.SavePath,
Migrations = arg.Migrations,
Serialize = arg.Serialize,
Deserialize = arg.Deserialize,
}),
_listenerByPathKey = {},
_listenerTrieRoot = {},
_pendingUpdateByPathKey = {},
_pendingOrder = {},
_isFlushing = false,
_isLoading = false,
_lastPublishedValueByPathKey = {},
_liveValueByPathKey = {},
Reloaded = ReactiveStore:Add(v119.new()),
Changed = ReactiveStore:Add(v119.new()),
}, index2)
end

index2.UseMiddleware = function(arg, middleware)
arg._middleware = middleware
end

local tbl18 = {}

index2.GetPropertyChangedSignal = function(arg, arg2)
local v122 = v117.PathToKey(arg2)
local v123 = arg._listenerByPathKey[v122]

if v123 == nil then
local v124 = arg._trove:Add(v116.new())
arg._listenerByPathKey[v122] = v124
local listenerTrieRoot = arg._listenerTrieRoot

for _, v125 in arg2, nil, nil do
local v126 = listenerTrieRoot[v125]

if v126 ~= nil then
listenerTrieRoot = v126
else
local tbl19 = {}
listenerTrieRoot[v125] = tbl19
listenerTrieRoot = tbl19
end
end

listenerTrieRoot[tbl18] = v124
v123 = v124
end

return v123
end

index2._FireChanged = function(l,I,W,N)local P=l._pendingUpdateByPathKey[I];if not N and P==nil and l._lastPublishedValueByPathKey[I]==W then return;end;if P==nil then table.insert(l._pendingOrder,I);end;l._pendingUpdateByPathKey[I]={Value=W};end
index2._Flush = function(l)if l._isFlushing then return;end;l._isFlushing=true;while#l._pendingOrder>0 do local I,W=l._pendingOrder,l._pendingUpdateByPathKey;l._pendingUpdateByPathKey={};l._pendingOrder={};for N,N in I,nil,nil do local I,P=W[N],l._listenerByPathKey[N];if P then P:Fire(I.Value);end;l._lastPublishedValueByPathKey[N]=I.Value;end;end;l._isFlushing=false;end
index2._FireForChangedPaths = function(arg, paths)
local function publish(p)
local value = v117.NavigateTo(arg.Data, p, true)
arg:_FireChanged(v117.PathToKey(p), value, type(value) == "table")
end
local function below(node, p)
for k, child in next, node do
if k ~= tbl18 and type(child) == "table" then
table.insert(p, k)
if child[tbl18] ~= nil then publish(p) end
below(child, p)
table.remove(p)
end
end
end
for _, path in paths do
local node, prefix = arg._listenerTrieRoot, {}
for i = 1, #path do
node = node[path[i]]
if node == nil then break end
prefix[i] = path[i]
if node[tbl18] ~= nil then publish(prefix) end
if i == #path then below(node, table.clone(prefix)) end
end
end
end
index2._FireListenersOnly = function(arg, path)
arg:_FireForChangedPaths({ path })
arg:_Flush()
end
index2.Get = function(I,W,N)return  v117 .NavigateTo(I.Data,W,N);end
index2.Set = function(I,W,N)local P=I._middleware;local a=P.Set;N=if a~=nil then(a(P,W,N))else N;local e=I.Data;a= v117 .NavigateTo(e,W,true)~=N;if a then  v117 .Set(e,W,N);end;e=P.SetApplied;if e~=nil then e(P,W,N);end;if a then I:_FireForChangedPaths({W});end;e= v117 .PathToKey(W);a=I._liveValueByPathKey[e];if a~=nil then a.Base=N;end;if I._pendingUpdateByPathKey[e]==nil then I:_FireChanged(e,N);end;I:_Flush();if not I._isLoading then I.Changed:Fire(W,N);end;end
index2.SetLiveOverride = function(I,W,N)local P= v117 .PathToKey(W);if I._liveValueByPathKey[P]==nil then I._liveValueByPathKey[P]={Path=W,Base= v117 .NavigateTo(I.Data,W,true)};end; v117 .Set(I.Data,W,N);I:_FireListenersOnly(W,N);end

index2.ClearLiveOverride = function(arg, arg2)
local v122 = v117.PathToKey(arg2)
local v123 = arg._liveValueByPathKey[v122]
if v123 == nil then
return
end
arg._liveValueByPathKey[v122] = nil
v117.Set(arg.Data, arg2, v123.Base)
arg:_FireListenersOnly(arg2, v123.Base)
end

index2.GetBase = function(I,W)local N=I._liveValueByPathKey[ v117 .PathToKey(W)];if N~=nil then return N.Base;end;return  v117 .NavigateTo(I.Data,W,true);end

index2.RebaseLiveOverride = function(arg, arg2, base)
local v122 = arg._liveValueByPathKey[v117.PathToKey(arg2)]
if v122 == nil then
return v86[153]
end
v122.Base = base
return true
end

index2.PublishPath = function(arg, arg2)
arg:_FireListenersOnly(arg2, v117.NavigateTo(arg.Data, arg2, true))
end

index2._PersistableData = function(arg)
local data = arg.Data
local flag19 = true

if next(arg._liveValueByPathKey) ~= nil then
data = v121(data)

for _, v122 in arg._liveValueByPathKey, nil, nil do
v117.Set(data, v122.Path, v122.Base)
end

flag19 = false
end

local middleware = arg._middleware
local persistable = middleware.Persistable
local v122

if persistable ~= nil then
v122 = persistable(middleware, data, flag19)
else
v122 = data
end

return v122
end

index2.SaveToFile = function(arg, arg2, arg3)
arg._configManager:SetData(arg:_PersistableData())
return arg._configManager:SaveToFile(arg2, arg3)
end

index2.CreateDefault = function(arg, arg2)
return arg._configManager:SaveDefaultToFile(arg2, v86[34])
end

local fn36 = nil

fn36 = function(arg, arg2)
if type(arg) ~= "table" or isAtomic(arg) then
local v122 = (arg2 == nil and { arg } or { arg2 })[1]
return (type(v122) == "table" and { (v121(v122)) } or { v122 })[1]
end

if type(arg2) ~= "table" then
return v121(arg)
end
local v122 = table.clone(arg)

for k, v123 in arg, nil, nil do
v122[k] = fn36(v123, arg2[k])
end

for k, v123 in arg2, nil, nil do
if arg[k] == nil then
v122[k] = (type(v123) == "table" and { (v121(v123)) } or { v123 })[v86[63]]
end
end

return v122
end

local fn37 = nil

fn37 = function(arg, arg2, arg3, arg4, arg5)
for k, v122 in arg, nil, nil do
if not (arg2 ~= nil and arg2[k] ~= nil) then
table.insert(arg4, k)
local v123 = (arg3 ~= nil and { arg3[k] } or { nil })[1]

if type(v122) == "table" and not isAtomic(v122) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
fn37(v122, nil, v123, arg4, arg5)
end

arg[k] = nil
table.insert(arg5, table.clone(arg4))
table.remove(arg4)
end
end

if arg2 == nil then
return
end

for k, v122 in arg2, nil, nil do
table.insert(arg4, k)
local tbl19 = arg[k]
local v123 = (arg3 ~= nil and { arg3[k] } or { nil })[1]

if type(v122) == "table" and not isAtomic(v122) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
if type(tbl19) ~= "table" or isAtomic(tbl19) then
tbl19 = {}
arg[k] = tbl19
table.insert(arg5, table.clone(arg4))
end

fn37(tbl19, v122, v123, arg4, arg5)
elseif tbl19 ~= v122 then
if type(tbl19) == "table" and not isAtomic(tbl19) and (v123 == nil or type(v123) == "table" and not isAtomic(v123)) then
fn37(tbl19, nil, v123, arg4, arg5)
end

arg[k] = v122
table.insert(arg5, table.clone(arg4))
end

table.remove(arg4)
end
end

index2._ApplyLoadedData = function(arg, arg2)
local v122 = fn36(arg.Default, arg2)
arg._isLoading = true
table.clear(arg._lastPublishedValueByPathKey)
table.clear(arg._pendingUpdateByPathKey)
table.clear(arg._pendingOrder)
table.clear(arg._liveValueByPathKey)
local tbl19 = {}
fn37(arg.Data, v122, arg.Default, {}, tbl19)
local loaded = arg._middleware.Loaded

if loaded ~= nil then
loaded(arg._middleware, v122)
end

arg:_FireForChangedPaths(tbl19)
arg:_Flush()
arg.Reloaded:Fire()
arg._isLoading = v86[153]
end

index2.LoadFromFile = function(arg, arg2)
local v122 = arg._configManager:LoadFromFile(arg2)
if not v122.Ok then
return v118.err("ReactiveStore", "LoadFromFile", v122.Error.Detail)
end
local value = v122.Value
arg:_ApplyLoadedData(value)
return v118.ok(value)
end

index2.ExportToJson = function(arg)
local v122 = arg._configManager:ToJson(arg:_PersistableData())
if not v122.Ok then
return v118.err("ReactiveStore", v86[99], v122.Error.Detail)
end
return v118.ok(v122.Value)
end

index2.InstallFromJson = function(arg, arg2, arg3)
local v122 = arg._configManager:FromJson(arg3)
if not v122.Ok then
return v118.err("ReactiveStore", "InstallFromJson", v122.Error.Detail)
end
local v123 = arg._configManager:SaveToFile(arg2)
if not v123.Ok then
return v118.err(v86[2], "InstallFromJson", v123.Error.Detail)
end
return v118.VoidOk
end

index2.LoadFromJson = function(arg, arg2)
local v122 = arg._configManager:FromJson(arg2)
if not v122.Ok then
return v118.err(v86[2], "LoadFromJson", v122.Error.Detail)
end
arg:_ApplyLoadedData(v122.Value)
return v118.VoidOk
end

index2.DeleteFile = function(arg, arg2)
local v122 = arg._configManager:Delete(arg2)
if not v122.Ok then
return v118.err("ReactiveStore", "DeleteFile", v122.Error.Detail)
end
return v118.VoidOk
end

index2.AllConfigs = function(arg)
return arg._configManager:AllConfigs()
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.l = function()
local l = tbl17.cache.l

if not l then
l = { c = fn35() }
tbl17.cache.l = l
end

return l.c
end
end
do -- m
local function fn35()
local tbl18

tbl18 = {
normalize = function(arg)
local tbl19 = {}

for k, v115 in arg, nil, nil do
local kind = typeof(v115)
local tbl20

if kind == "Color3" then
tbl20 = { __type = v86[115], R = v115.R, G = v115.G, B = v115.B }
elseif kind == "EnumItem" then
tbl20 = { __type = "EnumItem", EnumType = tostring(v115.EnumType), Name = v115.Name }
elseif kind == "Vector3" then
tbl20 = { __type = v86[20], X = v115.X, Y = v115.Y, Z = v115.Z }
elseif kind == v86[127] then
tbl20 = { __type = "CFrame", Components = { v115:GetComponents() } }
elseif kind == "ColorSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = { Time = v117.Time, R = v117.Value.R, G = v117.Value.G, B = v117.Value.B }
end

tbl20 = { __type = v86[93], Keypoints = v116 }
elseif kind == "NumberSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = { Time = v117.Time, Value = v117.Value, Envelope = v117.Envelope }
end

tbl20 = { __type = "NumberSequence", Keypoints = v116 }
elseif kind == "table" then
tbl20 = tbl18.normalize(v115)
else
tbl20 = v115
end

tbl19[k] = tbl20
end

return tbl19
end,
parse = function(arg)
local tbl19 = {}

for k, v115 in arg, nil, nil do
if typeof(v115) == "table" then
local type_ = v115.__type

if type(type_) ~= "string" then
tbl19[k] = tbl18.parse(v115)
else
if type_ == "Color3" then
v115 = Color3.new(v115.R, v115.G, v115.B)
elseif type_ == "EnumItem" then
v115 = Enum[v115.EnumType][v115.Name]
elseif type_ == "Vector3" then
v115 = Vector3.new(v115.X, v115.Y, v115.Z)
elseif type_ == "CFrame" then
v115 = CFrame.new(unpack(v115.Components))
elseif type_ == v86[93] then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = ColorSequenceKeypoint.new(v117.Time, Color3.new(v117.R, v117.G, v117.B))
end

v115 = ColorSequence.new(v116)
elseif type_ == "NumberSequence" then
local v116 = table.create(#v115.Keypoints)

for k2, v117 in v115.Keypoints, nil, nil do
v116[k2] = NumberSequenceKeypoint.new(v117.Time, v117.Value, v117.Envelope)
end

v115 = NumberSequence.new(v116)
end

tbl19[k] = v115
end

continue
end

tbl19[k] = v115
end

return tbl19
end,
}

return tbl18
end

tbl17.m = function()
local m = tbl17.cache.m

if not m then
local m2 = { c = fn35() }
tbl17.cache.m = m2
m = m2
end

return m.c
end
end
do -- n
local function fn35()
local GlobalTrove = tbl17.k().new("GlobalTrove")

K.GlobalTrove = GlobalTrove

return GlobalTrove
end

tbl17.n = function()
local n = tbl17.cache.n

if not n then
local n33 = { c = fn35() }
tbl17.cache.n = n33
n = n33
end

return n.c
end
end
do -- r
local function fn35()
tbl17.l()
tbl17.g()
tbl17.k()
return {}
end

tbl17.r = function()
local r = tbl17.cache.r

if not r then
r = { c = fn35() }
tbl17.cache.r = r
end

return r.c
end
end
do -- s
local function fn35()return table.freeze({Medium=Font.new("rbxassetid://12187365364",Enum.FontWeight.Medium,Enum.FontStyle.Normal),SemiBold=Font.new("rbxassetid://12187365364",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal),Bold=Font.new("rbxassetid://12187365364",Enum.FontWeight.Bold,Enum.FontStyle.Normal)});end

tbl17.s = function()
local s = tbl17.cache.s

if not s then
local s2 = { c = fn35() }
tbl17.cache.s = s2
s = s2
end

return s.c
end
end
do -- t
local function fn35()return{Players=cloneref(game:GetService("Players")),GuiService=cloneref(game:GetService("GuiService")),UserInputService=cloneref(game:GetService("UserInputService")),RunService=cloneref(game:GetService("RunService")),TweenService=cloneref(game:GetService("TweenService")),HttpService=cloneref(game:GetService("HttpService")),CoreGui=cloneref(game:GetService("CoreGui"))};end

tbl17.t = function()
local t = tbl17.cache.t

if not t then
if n26 >= 4809 then
while true do
end
else
local t2 = { c = fn35() }
tbl17.cache.t = t2
t = t2
end
end

return t.c
end
end
do -- u
local function fn35()local I= tbl17 .t();local l,W,N=I.GuiService,I.UserInputService,{DesignSize=UDim2.fromOffset(919,643),MinSize=UDim2.fromOffset(700,400),Scale=1};local function I()return workspace.CurrentCamera;end;local function P(a)if not a then return false;end;a=I();if a==nil then return false;end;local I=a.ViewportSize;return math.min(I.X,I.Y)>500;end;local function I(a)if a then return false;end;a=W.PreferredInput;if a==Enum.PreferredInput.Touch then return true;end;if a==Enum.PreferredInput.KeyboardAndMouse or a==Enum.PreferredInput.Gamepad then return false;end;a=W:GetLastInputType();if a==Enum.UserInputType.Touch then return true;end;if a==Enum.UserInputType.MouseButton1 or a==Enum.UserInputType.MouseButton2 or a==Enum.UserInputType.MouseMovement or a==Enum.UserInputType.Keyboard then return false;end;return W.TouchEnabled and not W.KeyboardEnabled;end;local a=l:IsTenFootInterface();local l=I(a);local I;N.IsMobile=function()return l;end;N.ForceMobileLayout=function(e)l=true;I=e==true;end;N.IsTablet=function()local l=I;if l==nil then l=P(N.IsMobile());I=l;end;return l;end;N.HasTouch=function()return not a and W.TouchEnabled;end;N.WantsMobileButtons=function()return N.HasTouch()or(N.IsMobile());end;return N;end

tbl17.u = function()
local u = tbl17.cache.u

if not u then
local u2 = { c = fn35() }
tbl17.cache.u = u2
u = u2
end

return u.c
end
end
do -- v
local function fn35()local I,W,N,P= tbl17 .u(),{},table.freeze({IsCompact=false,Rail=table.freeze({Width=100,HeaderHeight=85,TabsTop=102,TabSize=66,TabGap=4,TabIconSize=26,LogoSize=Vector2.new(48,37),ShowLabels=true}),Page=table.freeze({HasTitleBlock=true,OuterInset=18,HorizontalInset=17,HeaderHeight=85,TabsHeight=84,BottomInset=17,TitleTextSize=18,DescriptionTextSize=13,TabMinWidth=50,TabHeight=50,TabIconSize=24,TabTextSize=16,TabGap=14,TabPaddingLeft=13,TabPaddingRight=16,SearchCollapsedWidth=90,SearchExpandedWidth=260,SearchHeight=33,SearchRightInset=14}),Navigation=table.freeze({CueDepth=12,RevealPadding=4,VisibilityEpsilon=1}),Grid=table.freeze({Gap=17,MinColumnWidth=220}),Section=table.freeze({Gap=17,TitleGap=16,InnerPadding=12,ElementGap=12,GroupGap=12,TitleTextSize=16,MultiHeaderHeight=45,MultiHeaderGap=12,MultiHeaderPadding=12,MultiPaneTop=57,MultiTabTextSize=16}),Row=table.freeze({Height=24,TextSize=16,ControlVerticalInset=0,ControlHeight=22,AttachmentGap=11,ListRowHeight=26}),Button=table.freeze({RowHeight=24,VisualHeight=22,Gap=13})}),table.freeze({IsCompact=true,Rail=table.freeze({Width=52,HeaderHeight=48,TabsTop=52,TabSize=44,TabGap=2,TabIconSize=20,LogoSize=Vector2.new(24,19),ShowLabels=false}),Page=table.freeze({HasTitleBlock=true,OuterInset=12,HorizontalInset=12,HeaderHeight=44,TabsHeight=40,BottomInset=12,TitleTextSize=16,DescriptionTextSize=10,TabMinWidth=44,TabHeight=34,TabIconSize=18,TabTextSize=13,TabGap=6,TabPaddingLeft=8,TabPaddingRight=10,SearchCollapsedWidth=32,SearchExpandedWidth=220,SearchHeight=32,SearchRightInset=8}),Navigation=table.freeze({CueDepth=12,RevealPadding=4,VisibilityEpsilon=1}),Grid=table.freeze({Gap=12,MinColumnWidth=220}),Section=table.freeze({Gap=12,TitleGap=8,InnerPadding=8,ElementGap=8,GroupGap=8,TitleTextSize=15,MultiHeaderHeight=36,MultiHeaderGap=8,MultiHeaderPadding=8,MultiPaneTop=44,MultiTabTextSize=13}),Row=table.freeze({Height=32,TextSize=14,ControlVerticalInset=4,ControlHeight=24,AttachmentGap=8,ListRowHeight=32}),Button=table.freeze({RowHeight=32,VisualHeight=30,Gap=8})});local l=table.freeze({IsCompact=true,Rail=P.Rail,Page=table.freeze({HasTitleBlock=false,OuterInset=12,HorizontalInset=12,HeaderHeight=0,TabsHeight=44,BottomInset=12,TitleTextSize=16,DescriptionTextSize=10,TabMinWidth=44,TabHeight=36,TabIconSize=18,TabTextSize=14,TabGap=6,TabPaddingLeft=8,TabPaddingRight=10,SearchCollapsedWidth=32,SearchExpandedWidth=220,SearchHeight=32,SearchRightInset=8}),Navigation=P.Navigation,Grid=table.freeze({Gap=12,MinColumnWidth=330}),Section=P.Section,Row=table.freeze({Height=40,TextSize=15,ControlVerticalInset=6,ControlHeight=28,AttachmentGap=8,ListRowHeight=40}),Button=table.freeze({RowHeight=40,VisualHeight=36,Gap=8})});W.get=function()if not I.IsMobile()then return N;end;if I.IsTablet()then return P;end;return l;end;return W;end

tbl17.v = function()
local v115 = tbl17.cache.v

if not v115 then
v115 = { c = fn35() }
tbl17.cache.v = v115
end

return v115.c
end
end
do -- x
local function fn35() tbl17 .k();local I,W= tbl17 .t(), tbl17 .w();local l,N,P=I.UserInputService,{},setmetatable({},{__mode="k"});N.suppressActivation=function(I)P[I]=true;end;local I=W.findScrollingAncestor;N.connectPress=function(a,e,c,E)local p,T,t,x=false;local function S(J)if not p then return;end;p,T,t=false,nil,nil;if x~=nil then x:Disconnect();x=nil;end;E(J);end;a:Add({Destroy=function()p,T,t=false,nil,nil;if x~=nil then x:Disconnect();x=nil;end;end});a:Connect(e.InputBegan,function(E)if p then return;end;local J=E.UserInputType;if J~=Enum.UserInputType.MouseButton1 and J~=Enum.UserInputType.Touch then return;end;T,t,p=E,J,true;c();x=l.InputEnded:Connect(function(c)if T==nil then return;end;if not W.matchesPointerDrag(c,T,Enum.UserInputType.MouseButton1)then return;end;S(false);end);end);a:Connect(e.MouseLeave,function()if t==Enum.UserInputType.MouseButton1 then S(true);end;end);end;N.connectClick=function(a,e,c)if e:IsA("GuiButton")then a:Connect(e.Activated,function(E,p)if P[E]then P[E]=nil;return;end;c();end);return;end;a:Connect(e.InputBegan,function(P)local a=P.UserInputType;if a==Enum.UserInputType.MouseButton1 or a==Enum.UserInputType.Touch then c();end;end);end;N.connectDrag=function(P,a,e,c)local E,p,T,t,x=c or function(c,c)end;local c,S,J,B,X=false,false,0;local function H()J+=1;if B~=nil then B:Disconnect();B=nil;end;if X~=nil then X:Disconnect();X=nil;end;p,T,t,x,c,S=nil,nil,nil,nil,false,false;end;local function k(D)local Q=c;H();if Q then E(false,D);end;end;local function D()if p==nil or c or S then return;end;c=true;E(true,false);end;P:Add({Destroy=H});P:Connect(a.InputBegan,function(P)local E=P.UserInputType;if E~=Enum.UserInputType.MouseButton1 and E~=Enum.UserInputType.Touch then return;end;H();p=P;T=P.Position;t=I(a);x=t and t.CanvasPosition or nil;J+=1;local I=J;task.delay(0.3,function()if J==I then D();end;end);X=l.InputEnded:Connect(function(I)if p==nil then return;end;if not W.matchesPointerDrag(I,p,Enum.UserInputType.MouseButton1)then return;end;J+=1;k(false);end);B=l.InputChanged:Connect(function(l)if p==nil or S then return;end;if not W.matchesPointerDrag(l,p,Enum.UserInputType.MouseMovement)then return;end;local I,W=t,x;if I~=nil and W~=nil then local P=I.CanvasPosition-W;if P.X*P.X+P.Y*P.Y>0.25 then if c then k(true);else S=true;J+=1;end;return;end;end;if not c and T~=nil then W,I=l.Position.X-T.X,l.Position.Y-T.Y;if W*W+I*I>=100 then D();end;end;if c then e(l);end;end);end);end;return N;end

tbl17.x = function()
local x = tbl17.cache.x

if not x then
x = { c = fn35() }
tbl17.cache.x = x
end

return x.c
end
end
do -- y
local function fn35()
tbl17.k()
tbl17.r()
local color = Color3.fromRGB(255, v86[108], v86[108])
local tweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return { attach = function(arg, arg2, parent, arg3)
local trigger = parent
local cornerRadius = nil

if arg3 ~= nil then
trigger = arg3.Trigger or parent
cornerRadius = arg3.CornerRadius
end

local frame = Instance.new("Frame")
frame.BackgroundTransparency = v86[63]
frame.Size = UDim2.fromScale(1, 1)
frame.BorderSizePixel = v86[186]
frame.ClipsDescendants = v86[34]
frame.ZIndex = 0
frame.Parent = parent

if cornerRadius ~= nil then
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, cornerRadius)
uiCorner.Parent = frame
end

arg2:Connect(trigger.InputBegan, function(arg4)
local userInputType = arg4.UserInputType
if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.Touch then
return
end
local absoluteSize = parent.AbsoluteSize
local absolutePosition = parent.AbsolutePosition
local n = arg4.Position.X - absolutePosition.X
local n33 = arg4.Position.Y - absolutePosition.Y
local n34 = math.max(absoluteSize.X, absoluteSize.Y) * v86[49]
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(0.5, v86[101])
frame2.Position = UDim2.fromOffset(n, n33)
frame2.Size = UDim2.fromOffset(0, 0)
frame2.BackgroundColor3 = color
frame2.BackgroundTransparency = 0.84
frame2.BorderSizePixel = 0
frame2.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[63], 0)
uiCorner.Parent = frame2
local v115 = arg:Tween(frame2, { Size = UDim2.fromOffset(n34, n34), BackgroundTransparency = 1 }, tweenInfo)

if v115 ~= nil then
v115.Completed:Once(function()
frame2:Destroy()
end)
else
frame2:Destroy()
end
end)
end }
end

tbl17.y = function()
local y = tbl17.cache.y

if not y then
local y2 = { c = fn35() }
tbl17.cache.y = y2
y = y2
end

return y.c
end
end
do -- z
local function fn35()return{Accent=Color3.fromRGB(255,141,141),Outline=Color3.fromRGB(18,18,18),Background=Color3.fromRGB(0,0,0),ElementBackground=Color3.fromRGB(6,6,6),TabButtonSelected=Color3.fromRGB(28,28,28),Unselected=Color3.fromRGB(75,72,72),TextColor=Color3.fromRGB(197,197,197),ToggleCircleUnselected=Color3.fromRGB(64,64,64),ToggleBackgroundUnselected=Color3.fromRGB(12,13,13),GradientTop=Color3.fromRGB(14,14,14),GradientMid=Color3.fromRGB(6,6,6),GradientDark=Color3.fromRGB(3,3,3),GradientDeep=Color3.fromRGB(0,0,0),TabHighlight=Color3.fromRGB(42,42,42),TabShadow=Color3.fromRGB(16,16,16)};end

tbl17.z = function()
local z = tbl17.cache.z

if not z then
local z2 = { c = fn35() }
tbl17.cache.z = z2
z = z2
end

return z.c
end
end
do -- A
local function fn35()
tbl17.k()
local v115 = tbl17.z()
local index2 = {}
index2.__index = index2
local tbl18 = {}
local tbl19 = { Tokens = v115 }

local function fn36(arg, arg2)
local n = #arg
if n == 1 then
return ColorSequence.new(v115[arg[1]])
end
local tbl20 = {}

for k, v116 in arg, nil, nil do
local n33

if arg2 ~= nil then
n33 = arg2[k]
else
n33 = (k - 1) / (n - 1)
end

tbl20[k] = ColorSequenceKeypoint.new(n33, v115[v116])
end

return ColorSequence.new(tbl20)
end

local function fn37(arg, arg2)
if arg._tokenSet[arg2] then
return
end
arg._tokenSet[arg2] = true
local tbl20 = tbl18[arg2]

if tbl20 == nil then
tbl20 = {}
tbl18[arg2] = tbl20
end

tbl20[arg] = v86[34]
end

index2.new = function()
return setmetatable({ _propBindingsByToken = {}, _gradients = {}, _statefulApplyByToken = {}, _tokenSet = {} }, index2)
end

index2.Bind = function(arg, arg2, arg3, arg4)
arg2[arg3] = v115[arg4]
local tbl20 = arg._propBindingsByToken[arg4]

if tbl20 == nil then
tbl20 = {}
arg._propBindingsByToken[arg4] = tbl20
end

table.insert(tbl20, { Instance = arg2, Property = arg3 })
fn37(arg, arg4)
end

index2.BindGradient = function(arg, arg2, arg3, arg4)
arg2.Color = fn36(arg3, arg4)
table.insert(arg._gradients, { Gradient = arg2, Tokens = arg3, Times = arg4 })

for _, v116 in arg3, nil, nil do
fn37(arg, v116)
end
end

index2.BindStateful = function(arg, arg2, arg3)
local tbl20 = arg._statefulApplyByToken[arg2]

if tbl20 == nil then
tbl20 = {}
arg._statefulApplyByToken[arg2] = tbl20
end

table.insert(tbl20, arg3)
fn37(arg, arg2)
end

index2.Destroy = function(arg)
for k in arg._tokenSet, nil, nil do
local v116 = tbl18[k]

if v116 ~= nil then
v116[arg] = nil
end
end

table.clear(arg._tokenSet)
table.clear(arg._propBindingsByToken)
table.clear(arg._gradients)
table.clear(arg._statefulApplyByToken)
end

tbl19.newBatch = function(arg)
local v116 = index2.new()

if arg ~= nil then
arg:Add(v116)
end

return v116
end

tbl19.get = function(arg)
return v115[arg]
end

local tbl20 = { "GradientTop", v86[187], v86[70], v86[141] }
local tbl21 = {}
local background = v115.Background

for _, v116 in tbl20, nil, nil do
local v117 = v115[v116]
tbl21[v116] = { R = v117.R / background.R, G = v117.G / background.G, B = v117.B / background.B }
end

local function fn38(I,W)if  v115 [I]==W then return;end; v115 [I]=W;local N= tbl18 [I];if N==nil then return;end;for P in N,nil,nil do local N=P._propBindingsByToken[I];if N~=nil then for a,a in N,nil,nil do a.Instance[a.Property]=W;end;end;for a,a in P._gradients,nil,nil do if table.find(a.Tokens,I)~=nil then a.Gradient.Color= fn36 (a.Tokens,a.Times);end;end;N=P._statefulApplyByToken[I];if N~=nil then for l,l in N,nil,nil do l(W);end;end;end;end

local function fn39(arg)
for _, v116 in tbl20, nil, nil do
local v117 = tbl21[v116]
fn38(v116, Color3.new(math.clamp(arg.R * v117.R, v86[186], 1), math.clamp(arg.G * v117.G, 0, 1), math.clamp(arg.B * v117.B, 0, 1)))
end
end

tbl19.refresh = function(arg, arg2)
fn38(arg, arg2)

if arg == "Background" then
fn39(arg2)
end
end

return tbl19
end

tbl17.A = function()
local a = tbl17.cache.A

if not a then
local a2 = { c = fn35() }
tbl17.cache.A = a2
a = a2
end

return a.c
end
end
do -- B
local function fn35()
local v115 = tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.A()
local index2 = {}
index2.__index = index2

index2.new = function(arg, arg2)
local v119 = v117.get()
local flag19 = arg2.Bare == v86[34]
local height = arg2.Height or v119.Row.Height
local n

if v119.IsCompact and not flag19 then
n = math.max(height, v119.Row.Height)
else
n = height
end

return setmetatable({
_menu = arg,
_metrics = v119,
Label = arg2.Label,
_tooltip = arg2.Tooltip,
_bare = flag19,
_isBareFlexRoot = false,
_visible = v86[34],
_height = n,
_mediumTitle = arg2.MediumTitle == true,
_rightOffset = arg2.RightOffset or 0,
_attachments = {},
_titleAccessories = {},
_titleAccessoryReserve = v86[186],
_isDestroyed = false,
_onVisibilityChanged = function()
end,
_ctx = nil,
_barePending = nil,
_isTooltipWired = false,
Frame = nil,
TitleLabel = nil,
Right = nil,
_rightLayout = nil,
}, index2)
end

index2.AttachRight = function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local tbl18 = {
Build = arg2,
BuildRoot = arg6,
IsFlexChild = arg7 == true,
IsInRight = false,
Widget = nil,
NaturalWidth = arg3,
Leading = arg4,
Trove = v115.new(),
Cleanup = nil,
}

local cleanup = { Destroy = function()
arg:_DetachAttachment(tbl18)
end }

tbl18.Cleanup = cleanup

if arg5 ~= nil then
arg5:Add(cleanup)
end

if arg._isDestroyed then
tbl18.Trove:Destroy()
return
end
table.insert(arg._attachments, tbl18)
local ctx = arg._ctx
if ctx == nil then
return
end
local barePending = arg._barePending

if barePending ~= nil then
arg._barePending = nil
arg:_BuildBareRoot(barePending.Parent, barePending.LayoutOrder, ctx)
return
end

arg:_RealizeAttachment(tbl18, ctx)
end

index2._DetachAttachment = function(arg, arg2)
local v119 = table.find(arg._attachments, arg2)
if v119 == nil then
return
end
local isInRight = arg2.IsInRight
table.remove(arg._attachments, v119)
arg2.Trove:Destroy()
arg2.Widget = nil
arg2.Cleanup = nil

if arg._bare and isInRight then
local flag19 = v86[153]

for _, v120 in arg._attachments, nil, nil do
if v120.IsInRight then
flag19 = true
break
end
end

if not flag19 then
local right = arg.Right

if right ~= nil then
right:Destroy()
arg.Right = nil
arg._rightLayout = nil
end
end
end

if #arg._attachments > 0 then
return
end
arg._isDestroyed = true
arg._barePending = nil
local frame = arg.Frame

if frame ~= nil then
frame:Destroy()
arg.Frame = nil
end

arg.TitleLabel = nil
arg.Right = nil
arg._rightLayout = nil
arg._isBareFlexRoot = false
arg._onVisibilityChanged()
end

index2.AttachTitleAccessory = function(arg, arg2, arg3, arg4)
local tbl18 = { Build = arg2, Trove = v115.new(), Widget = nil }

local tbl19 = { Destroy = function()
local v119 = table.find(arg._titleAccessories, tbl18)

if v119 ~= nil then
table.remove(arg._titleAccessories, v119)
end

tbl18.Trove:Destroy()
tbl18.Widget = nil
end }

if arg4 ~= nil then
arg4:Add(tbl19)
end

if arg._isDestroyed then
tbl18.Trove:Destroy()
return
end
table.insert(arg._titleAccessories, tbl18)
arg._titleAccessoryReserve = arg._titleAccessoryReserve + arg3
local ctx = arg._ctx

if ctx ~= nil and arg.TitleLabel ~= nil then
arg:_RealizeTitleAccessory(tbl18, ctx)
end
end

index2._RealizeTitleAccessory = function(arg, arg2, arg3)
arg2.Widget = arg2.Build(arg.TitleLabel, {
Menu = arg3.Menu,
Trove = arg2.Trove,
Batch = v118.newBatch(arg2.Trove),
ParentOverlay = arg3.ParentOverlay,
})
end

index2._EnsureRightLayout = function(arg, parent)
if arg._rightLayout ~= nil then
return
end
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
uiListLayout.Padding = UDim.new(0, arg._metrics.Row.AttachmentGap)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = parent
arg._rightLayout = uiListLayout

for k, v119 in arg._attachments, nil, nil do
if not (arg._bare and k == 1) then
local widget = v119.Widget

if widget ~= nil then
widget.LayoutOrder = v119.Leading and -1 or k
end
end
end
end

index2._EnsureBareRight = function(arg)
if arg.Right ~= nil then
return arg.Right
end
local frame = arg.Frame
if frame == nil then
return nil
end
local frame2 = Instance.new("Frame")
frame2.AnchorPoint = Vector2.new(v86[63], 0.5)
frame2.Position = UDim2.new(1, arg._rightOffset, 0.5, 0)
frame2.Size = UDim2.new(0.55, 0, v86[186], arg._height)
frame2.BorderSizePixel = 0
frame2.BackgroundTransparency = 1
frame2.Parent = frame
arg.Right = frame2
arg:_EnsureRightLayout(frame2)
return frame2
end

index2._RealizeAttachment = function(arg, arg2, arg3)
local frame

if arg._bare then
if arg._isBareFlexRoot and arg2.IsFlexChild then
frame = arg.Frame
else
frame = arg:_EnsureBareRight()
end
else
frame = arg.Right or arg.Frame

if arg.Right ~= nil and #arg._attachments >= 2 then
arg:_EnsureRightLayout(arg.Right)
end
end

if frame == nil then
return
end
arg2.IsInRight = arg.Right ~= nil and frame == arg.Right
local tbl18 = {}

for _, v119 in frame:GetChildren() do
tbl18[v119] = v86[34]
end

local v119 = arg2.Build(frame, {
Menu = arg3.Menu,
Trove = arg2.Trove,
Batch = v118.newBatch(arg2.Trove),
ParentOverlay = arg3.ParentOverlay,
})

arg2.Widget = v119

for _, v120 in frame:GetChildren() do
if not tbl18[v120] then
arg2.Trove:Add(v120)
end
end

if v119 ~= nil and arg._rightLayout ~= nil then
local layoutOrder = table.find(arg._attachments, arg2) or #arg._attachments

if arg2.Leading then
layoutOrder = -v86[63]
end

v119.LayoutOrder = layoutOrder
end
end

local function fn36(arg)
local v119 = v86[186]

for k, v120 in arg._attachments, nil, nil do
local naturalWidth = v120.NaturalWidth
if naturalWidth == nil then
return nil
end
v119 += naturalWidth

if k > 1 then
v119 += arg._metrics.Row.AttachmentGap
end
end

if v119 == 0 then
return nil
end
return v119
end

local function fn37(arg, arg2, arg3, arg4, arg5)
local flag19 = false
local flag20 = false
local size = arg5.Size
local anchorPoint = arg5.AnchorPoint
local position = arg5.Position
local position2 = arg4.Position
local size2 = arg3.Size
local automaticSize = arg3.AutomaticSize
local scale = size.X.Scale
local n = 1

if scale > 0 then
n = v86[63] - scale
end

local n33 = arg4.TextBounds.X + arg._titleAccessoryReserve

local function fn38()
if flag20 then
return
end
flag20 = true
local x = arg3.AbsoluteSize.X
if x <= 0 then
flag20 = false
return
end
local n34 = x * n - v86[162]
local v119 = fn36(arg)

if v119 ~= nil then
n34 = x - v119 - 8
end

local flag21 = n33 > n34
if flag21 == flag19 then
flag20 = false
return
end
flag19 = flag21

if flag19 then
local v120 = math.round(math.max(arg4.TextBounds.Y, arg._metrics.Row.TextSize))
arg4.AnchorPoint = Vector2.zero
arg4.Position = UDim2.new(0, 0, v86[186], v86[186])
arg5.AnchorPoint = Vector2.zero
arg5.Position = UDim2.fromOffset(0, v120 + 4)
arg5.Size = UDim2.new(1, 0, 0, size.Y.Offset)
arg3.AutomaticSize = Enum.AutomaticSize.None
arg3.Size = UDim2.new(1, 0, 0, v120 + 4 + size.Y.Offset)
else
arg4.AnchorPoint = Vector2.zero
arg4.Position = position2
arg5.AnchorPoint = anchorPoint
arg5.Position = position
arg5.Size = size
arg3.AutomaticSize = automaticSize
arg3.Size = size2
end

flag20 = false
end

fn38()
arg2.Trove:Connect(arg3:GetPropertyChangedSignal("AbsoluteSize"), fn38)

arg2.Trove:Connect(arg4:GetPropertyChangedSignal(v86[37]), function()
n33 = arg4.TextBounds.X + arg._titleAccessoryReserve
fn38()
end)
end

index2._BuildBareRoot = function(arg, arg2, layoutOrder, arg3)
local v119 = arg._attachments[1]
v119.IsInRight = false
arg._isBareFlexRoot = v119.IsFlexChild

local v120 = (v119.BuildRoot or v119.Build)(arg2, {
Menu = arg3.Menu,
Trove = v119.Trove,
Batch = v118.newBatch(v119.Trove),
ParentOverlay = arg3.ParentOverlay,
})

assert(v120 ~= nil, "Row: bare row builder returned no root")
v120.LayoutOrder = layoutOrder
v120.Visible = arg._visible
arg.Frame = v120

for _, v121 in v120:GetChildren() do
if not v121:IsA("UIListLayout") then
v119.Trove:Add(v121)
end
end

for i = 2, #arg._attachments do
local v121 = arg._attachments[i]

if v121.Widget == nil then
arg:_RealizeAttachment(v121, arg3)
end
end

arg:_WireTooltip()
end

index2.Realize = function(arg, parent, ctx, layoutOrder)
if arg._ctx ~= nil or arg._isDestroyed then
return
end
arg._ctx = ctx

if arg._bare then
if arg._attachments[1] == nil then
arg._barePending = { Parent = parent, LayoutOrder = layoutOrder }
return
end
arg:_BuildBareRoot(parent, layoutOrder, ctx)
else
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.new(1, 0, 0, arg._height)
textButton.BorderSizePixel = 0
textButton.AutomaticSize = Enum.AutomaticSize.Y
textButton.AutoButtonColor = false
textButton.Text = ""
textButton.LayoutOrder = layoutOrder
textButton.Visible = arg._visible
textButton.Parent = parent
arg.Frame = textButton
local n = arg._metrics.Row.TextSize + 4
local textLabel = Instance.new("TextLabel")
textLabel.Text = arg.Label or ""
textLabel.AnchorPoint = Vector2.zero
textLabel.BackgroundTransparency = v86[63]
textLabel.Position = UDim2.fromOffset(v86[186], math.round((arg._height - n) / 2))
textLabel.Size = UDim2.fromOffset(0, n)
textLabel.BorderSizePixel = 0
textLabel.AutomaticSize = Enum.AutomaticSize.X
textLabel.TextSize = arg._metrics.Row.TextSize
textLabel.TextXAlignment = Enum.TextXAlignment.Left

if arg._mediumTitle then
textLabel.FontFace = v116.Medium
else
textLabel.FontFace = ctx.Menu.Fonts.Main
end

ctx.Batch:Bind(textLabel, "TextColor3", "TextColor")
textLabel.Parent = textButton
arg.TitleLabel = textLabel
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, v86[186])
frame.Position = UDim2.new(v86[63], arg._rightOffset, 0, 0)
frame.Size = UDim2.new(0.55, 0, 0, arg._height)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundTransparency = 1
frame.Parent = textButton
local controlVerticalInset = arg._metrics.Row.ControlVerticalInset

if controlVerticalInset > 0 then
frame.AutomaticSize = Enum.AutomaticSize.None
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, controlVerticalInset)
uiPadding.PaddingBottom = UDim.new(v86[186], controlVerticalInset)
uiPadding.Parent = frame
end

arg.Right = frame

for _, v119 in arg._attachments, nil, nil do
if v119.Widget == nil then
arg:_RealizeAttachment(v119, ctx)
end
end

for _, v119 in arg._titleAccessories, nil, nil do
if v119.Widget == nil then
arg:_RealizeTitleAccessory(v119, ctx)
end
end

fn37(arg, ctx, textButton, textLabel, frame)
arg:_WireTooltip()
end
end

index2._WireTooltip = function(arg)
if arg._isTooltipWired or arg._tooltip == nil then
return
end
local ctx = arg._ctx
local frame = arg.Frame
if ctx == nil or frame == nil then
return
end
arg._isTooltipWired = true

ctx.Menu:AttachTooltip(ctx.Trove, frame, function()
return arg._tooltip
end)
end

index2.SetLabel = function(arg, label)
arg.Label = label
arg._menu:InvalidateSearch()
local titleLabel = arg.TitleLabel

if titleLabel ~= nil then
titleLabel.Text = label
end
end

index2.SetTooltip = function(arg, tooltip)
arg._tooltip = tooltip
arg:_WireTooltip()
end

index2.SetVisible = function(arg, visible)
if arg._visible == visible then
return
end
arg._visible = visible
local frame = arg.Frame

if frame ~= nil then
frame.Visible = visible
end

arg._onVisibilityChanged()
end

index2.IsVisible = function(arg)
return arg._visible
end

index2.Destroy = function(arg)
arg._isDestroyed = true
arg._barePending = nil

for i = #arg._attachments, 1, -v86[63] do
local v119 = arg._attachments[i]
table.remove(arg._attachments, i)
v119.Trove:Destroy()
v119.Widget = nil
v119.Cleanup = nil
end

for i = #arg._titleAccessories, 1, -1 do
local v119 = arg._titleAccessories[i]
table.remove(arg._titleAccessories, i)
v119.Trove:Destroy()
v119.Widget = nil
end

local frame = arg.Frame

if frame ~= nil then
frame:Destroy()
arg.Frame = nil
end

arg.TitleLabel = nil
arg.Right = nil
arg._rightLayout = nil
arg._isBareFlexRoot = false
arg._onVisibilityChanged()
end

return index2
end

tbl17.B = function()
local b = tbl17.cache.B

if not b then
b = { c = fn35() }
tbl17.cache.B = b
end

return b.c
end
end
do -- C
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.x()
local v119 = tbl17.y()
tbl17.B()
local v120 = tbl17.A()
local color = Color3.fromRGB(255, 255, 255)
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfo2 = TweenInfo.new(v86[62], Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color2 = Color3.fromRGB(v86[102], 92, v86[53])

local function fn36(arg, arg2)
local clamp = math.clamp
local n = arg.B * arg2
return Color3.new(math.clamp(arg.R * arg2, v86[186], v86[63]), math.clamp(arg.G * arg2, 0, v86[63]), clamp(n, 0, 1))
end

local function fn37(arg)
return arg == "primary" and v120.get("Accent") or color
end

local function fn38(arg)
local flag19 = arg == "primary"

if flag19 then
local v121 = v86[66]
flag19 = fn36(v120.get("Accent"), v121)
end

return flag19 or Color3.fromRGB(v86[65], 220, 230)
end

local function fn39(arg)
if arg == "primary" then
return color
end

if arg == "ghost" then
return v120.get("Unselected")
end
return v120.get("TextColor")
end

local function fn40(arg)
return arg == "primary" and fn36(v120.get(v86[139]), 0.6) or v120.get(v86[120])
end

local index2 = {}
index2.__index = index2

local function createFrame(arg, parent, arg2)
local menu = arg._menu
local variant = arg._variant
local button = v117.get().Button
local transparency = 0
local n = 0

if variant == "primary" then
n = 0.6
elseif variant == "ghost" then
if n26 < 4790 then
while true do
end
else
transparency = 1
n = 1
end
end

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(v86[63], v86[186])
frame.Position = UDim2.new(1, -v86[63], 0, 1)
frame.Size = UDim2.fromOffset(v86[186], button.VisualHeight)
frame.BorderSizePixel = 0
frame.BackgroundColor3 = fn37(variant)
frame.ClipsDescendants = v86[34]
frame.Parent = parent

if variant == "default" then
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
arg2.Batch:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = frame
end

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], 5)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = fn40(variant)
uiStroke.Transparency = transparency
uiStroke.Parent = frame
local instance = Instance.new(v86[92])
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.Text = ""
instance.AutoButtonColor = false
instance.Parent = frame
v119.attach(menu, arg2.Trove, frame, { Trigger = instance })
local textLabel = Instance.new("TextLabel")
textLabel.LayoutOrder = -v86[63]
textLabel.FontFace = v116.SemiBold
textLabel.TextColor3 = fn39(variant)
textLabel.Text = arg.Label
textLabel.BackgroundTransparency = 1
textLabel.Size = UDim2.fromScale(1, 1)
textLabel.BorderSizePixel = 0
textLabel.TextSize = 16
textLabel.Parent = frame
arg._title = textLabel

if variant == "default" then
arg2.Batch:Bind(textLabel, "TextColor3", "TextColor")
elseif variant == "ghost" then
arg2.Batch:Bind(textLabel, "TextColor3", "Unselected")
end

arg2.Trove:Connect(instance.MouseEnter, function()
menu:Tween(frame, { BackgroundColor3 = fn38(variant) }, tweenInfo)

if variant == "default" then
menu:Tween(uiStroke, { Color = v120.get("Accent") }, tweenInfo)
elseif variant == "primary" then
menu:Tween(uiStroke, { Transparency = n }, tweenInfo)
elseif variant == "ghost" then
menu:Tween(textLabel, { TextColor3 = v120.get("TextColor") }, tweenInfo)
end
end)

arg2.Trove:Connect(instance.MouseLeave, function()
menu:Tween(frame, { BackgroundColor3 = fn37(variant) }, tweenInfo)

if variant == "default" then
menu:Tween(uiStroke, { Color = v120.get("Outline") }, tweenInfo)
elseif variant == "primary" then
menu:Tween(uiStroke, { Transparency = transparency }, tweenInfo)
elseif variant == "ghost" then
menu:Tween(textLabel, { TextColor3 = v120.get("Unselected") }, tweenInfo)
end
end)

local backgroundColor3 = nil

v118.connectPress(arg2.Trove, instance, function()
backgroundColor3 = frame.BackgroundColor3
menu:Tween(frame, { BackgroundColor3 = fn36(backgroundColor3, 0.85) }, tweenInfo2)
end, function()
if backgroundColor3 ~= nil then
menu:Tween(frame, { BackgroundColor3 = backgroundColor3 }, tweenInfo2)
backgroundColor3 = nil
end
end)

local function fn41()
textLabel.TextColor3 = v120.get("Accent")
menu:Tween(textLabel, { TextColor3 = fn39(variant) })
arg._onClick()
arg.Clicked:Fire()
end

if not arg._requiresConfirm then
v118.connectClick(arg2.Trove, instance, fn41)
return frame
end
local v121 = nil

local function fn42()
local v122 = v121
if v122 == nil then
return
end
v121 = nil
v122:Destroy()
textLabel.Text = arg.Label
menu:Tween(textLabel, { TextColor3 = fn39(variant) }, tweenInfo)
end

v118.connectClick(arg2.Trove, instance, function()
if v121 == nil then
local v122 = arg2.Trove:Extend()
v121 = v122
menu:Tween(textLabel, { TextColor3 = color2 }, tweenInfo)

v122:Add(task.spawn(function()
for i = v86[155], 1, -1 do
textLabel.Text = string.format("%s (%s)", "Are you sure?", tostring(i))
task.wait(v86[63])
end

fn42()
end))

return
end

fn42()
fn41()
end)

return frame
end

local function createTextButton()
local button = v117.get().Button
local textButton = Instance.new("TextButton")
textButton.BackgroundTransparency = 1
textButton.Size = UDim2.new(1, v86[186], 0, button.RowHeight)
textButton.BorderSizePixel = 0
textButton.Text = ""
textButton.AutoButtonColor = false
local instance = Instance.new(v86[4])
instance.Padding = UDim.new(0, button.Gap)
instance.FillDirection = Enum.FillDirection.Horizontal
instance.HorizontalFlex = Enum.UIFlexAlignment.Fill
instance.SortOrder = Enum.SortOrder.LayoutOrder
instance.VerticalFlex = Enum.UIFlexAlignment.Fill
instance.Parent = textButton
return textButton
end

index2._New = function(arg, arg2, arg3, arg4, arg5)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = v86[33],
Row = arg2,
Label = arg4.Label or "Button",
Clicked = arg3:Add(v115.new()),
_onClick = arg4.OnClick or function()
end,
_variant = arg4.Variant or "default",
_requiresConfirm = arg4.Confirm == true,
_title = nil,
}, index2)

if arg5 then
arg2:AttachRight(function(parent, arg6)
local v121 = createTextButton()
v121.Parent = parent
createFrame(obj, v121, arg6)
return v121
end, nil, nil, arg3, nil, v86[34])
else
arg2:AttachRight(function(arg6, arg7)
return createFrame(obj, arg6, arg7)
end, nil, nil, arg3, function(parent, arg6)
local v121 = createTextButton()
v121.Parent = parent
createFrame(obj, v121, arg6)
return v121
end, true)
end

return obj
end

index2.SetLabel = function(arg, label)
arg.Label = label
local title = arg._title

if title ~= nil then
title.Text = label
end

return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnClick = function(arg, arg2)
arg._trove:Connect(arg.Clicked, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.C = function()
local c = tbl17.cache.C

if not c then
local c2 = { c = fn35() }
tbl17.cache.C = c2
c = c2
end

return c.c
end
end
do -- D
local function fn35() tbl17 .r();local l={};local function I(W)local N={};for P,P in W.Keypoints,nil,nil do table.insert(N,{Time=P.Time,Value=P.Value});end;return N;end;local function W(N)local P={};for a,a in N,nil,nil do table.insert(P,ColorSequenceKeypoint.new(a.Time,a.Value));end;return ColorSequence.new(P);end;local function N(P)local a=P[1].Value;for e=2,#P,1 do if P[e].Value~=a then return false;end;end;return true;end;local function P(a)if type(a)=="number"then return 1-a;end;return 1;end;l.decodeSolid=function(a,e)if typeof(a)~="Color3"then return nil;end;return{Rgb=a,Alpha=P(e),Stops={}};end;l.encodeSolid=function(a)return a.Rgb,1-a.Alpha;end;l.decodeSequence=function(a,e)if typeof(a)~="ColorSequence"then return nil;end;local c=I(a);if#c==0 then return nil;end;a=P(e);if N(c)then return{Rgb=c[1].Value,Alpha=a,Stops={}};end;return{Rgb=c[1].Value,Alpha=a,Stops=c};end;l.encodeSequence=function(I)local N=I.Stops;if N~=nil and#N>=2 then return W(N),1-I.Alpha;end;return ColorSequence.new(I.Rgb),1-I.Alpha;end;return l;end

tbl17.D = function()
local d = tbl17.cache.D

if not d then
d = { c = fn35() }
tbl17.cache.D = d
end

return d.c
end
end
do -- E
local function fn35() tbl17 .r();local l;l={clone=function(I)local W={};if type(I)=="table"then for N,P in I,nil,nil do if type(P)=="table"then N=P.Value;if typeof(N)=="Color3"then table.insert(W,{Time=math.clamp(tonumber(P.Time)or 0,0,1),Value=N});end;end;end;end;return W;end,sort=function(I,W)table.sort(I,function(N,P)return N.Time<P.Time;end);if W~=nil then for N,P in I,nil,nil do if P==W then return N;end;end;end;return math.max(#I,1);end,ensure=function(I,W)local N=l.clone(I);if#N>=2 then l.sort(N);N[1].Time=0;N[#N].Time=1;return N;end;return{{Time=0,Value=W},{Time=1,Value=W}};end,toSequence=function(I)local W=l.clone(I);if#W==0 then return ColorSequence.new(Color3.new(1,1,1));end;l.sort(W);local I,N,P={},W[1],W[#W];if N.Time>0 then table.insert(I,ColorSequenceKeypoint.new(0,N.Value));end;for a,a in W,nil,nil do N=math.clamp(a.Time,0,1);table.insert(I,ColorSequenceKeypoint.new(if#I>0 then(math.max(N,I[#I].Time))else N,a.Value));end;if I[#I].Time<1 then table.insert(I,ColorSequenceKeypoint.new(1,P.Value));end;return ColorSequence.new(I);end};return l;end

tbl17.E = function()
local e = tbl17.cache.E

if not e then
e = { c = fn35() }
tbl17.cache.E = e
end

return e.c
end
end
do -- F
local function fn35()
tbl17.A()

return {
addGlow = function(arg, parent, arg2)
local amount = arg2.Amount or v86[175]
local dampingFactor = arg2.DampingFactor or 0.4

for i = 1, amount do
local uiStroke = Instance.new("UIStroke")
uiStroke.LineJoinMode = Enum.LineJoinMode.Round
uiStroke.BorderOffset = UDim.new(0, i)
uiStroke.Transparency = 1 - (v86[63] - i / (amount + dampingFactor)) * (v86[63] - dampingFactor)
arg:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = parent
end
end,
bindSurfaceGradient = function(arg, arg2, arg3)
local n = #arg3
local v115 = table.clone(arg3)
table.insert(v115, arg3[n])
local tbl18 = {}

for i = 1, n do
tbl18[i] = (i - 1) / (n - 1) * v86[81]
end

tbl18[n + 1] = 1
arg:BindGradient(arg2, v115, tbl18)
end,
}
end

tbl17.F = function()
local f = tbl17.cache.F

if not f then
local f2 = { c = fn35() }
tbl17.cache.F = f2
f = f2
end

return f.c
end
end
do -- G
local function fn35()
tbl17.k()
local v115 = tbl17.F()
tbl17.r()
local v116 = tbl17.A()
local v117 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg)
local root = arg.Root
local v118, v119 = arg._place(arg._trigger, root)
local v120 = v117.absoluteToLayerOffset(arg._layer, Vector2.new(v118, v119))
local absoluteSize = root.AbsoluteSize

if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
local absoluteSize2 = arg._layer.AbsoluteSize
absoluteSize = Vector2.new(root.Size.X.Scale * absoluteSize2.X + root.Size.X.Offset, root.Size.Y.Scale * absoluteSize2.Y + root.Size.Y.Offset)
end

local anchorPoint = root.AnchorPoint
local v121, v122 = v117.clampOffsetToViewport(v120.X - absoluteSize.X * anchorPoint.X, v120.Y - absoluteSize.Y * anchorPoint.Y, absoluteSize)
local v123 = v117.onScreenKeyboardTop()
local n

if v123 == nil then
n = v122
else
n = math.clamp(v122, v86[186], math.max(0, v123 - absoluteSize.Y))
end

return math.round(v121 + absoluteSize.X * anchorPoint.X), math.round(n + absoluteSize.Y * anchorPoint.Y)
end

local function fn37(arg, arg2)
arg._geometryTrove:Clean()
arg._onToggle(arg2)
local menu = arg._menu
local root = arg.Root

if not arg2 then
local v118, v119 = fn36(arg)
menu:Tween(root, { Position = UDim2.fromOffset(v118, v119 - 15) })
menu:FadeCanvasGroup(root, false, arg._fadeState)
return
end

v117.connectOnScreenKeyboard(arg._geometryTrove, function()
local updateViewport = arg._updateViewport
if updateViewport ~= nil then
updateViewport()
return
end
arg:Reposition()
end)

local v118, v119 = fn36(arg)
root.Position = UDim2.fromOffset(v118, v119 - 15)

arg._geometryTrove:Add(task.defer(function()
if not arg.Entry.Open or root.Parent == nil then
return
end
local v120, v121 = fn36(arg)
root.Position = UDim2.fromOffset(v120, v121 - 15)
menu:FadeCanvasGroup(root, true, arg._fadeState)
menu:Tween(root, { Position = UDim2.fromOffset(v120, v121) })
end))
end

index2.new = function(arg, arg2, arg3)
local v118 = arg2:Extend()
local v119 = v116.newBatch(v118)
local canvasGroup = Instance.new("CanvasGroup")
canvasGroup.Visible = false
canvasGroup.GroupTransparency = 1
canvasGroup.BorderSizePixel = 0
canvasGroup.AnchorPoint = arg3.AnchorPoint or Vector2.zero
canvasGroup.Size = arg3.Size
canvasGroup.AutomaticSize = arg3.AutomaticSize or Enum.AutomaticSize.None

if arg3.FlatBackground then
canvasGroup.BackgroundTransparency = v86[6]
v119:Bind(canvasGroup, "BackgroundColor3", v86[168])
else
canvasGroup.BackgroundTransparency = 1
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(v86[63], 1)
frame.BorderSizePixel = 0
frame.ZIndex = v86[186]
frame.BackgroundColor3 = Color3.fromRGB(v86[108], v86[108], 255)
frame.Parent = canvasGroup
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = 90
v115.bindSurfaceGradient(v119, uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, arg3.CornerRadius or 5)
uiCorner.Parent = frame
end

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], arg3.CornerRadius or 5)
uiCorner.Parent = canvasGroup
local uiStroke = Instance.new("UIStroke")
v119:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = canvasGroup

if arg3.Glow then
v115.addGlow(v119, canvasGroup, { Amount = 5, DampingFactor = 0.6 })
end

local overlayLayer = arg:GetOverlayLayer()
canvasGroup.Parent = overlayLayer
v118:Add(canvasGroup)
local v120 = nil

local v121 = arg:RegisterOverlay(canvasGroup, {
Triggers = { arg3.Trigger },
ParentEntry = arg3.ParentEntry,
OnToggle = function(arg4)
local v121 = v120

if v121 ~= nil then
fn37(v121, arg4)
end
end,
})

v118:Add({ Destroy = function()
arg:UnregisterOverlay(v121)
end })

local obj = setmetatable({
Trove = v118,
_menu = arg,
_layer = overlayLayer,
Batch = v119,
_trigger = arg3.Trigger,
_place = arg3.Place,
_onToggle = arg3.OnToggle or function()
end,
_fadeState = { Tweening = v86[153] },
_geometryTrove = v118:Extend(),
_updateViewport = nil,
Root = canvasGroup,
Entry = v121,
}, index2)

v120 = obj

v118:Connect(arg3.Trigger:GetPropertyChangedSignal("AbsolutePosition"), function()
obj:Reposition()
end)

v117.connectCurrentCameraViewport(v118, function()
obj:Reposition()
end)

return obj
end

index2.RealizeCtx = function(arg)
return { Menu = arg._menu, Trove = arg.Trove, Batch = arg.Batch, ParentOverlay = arg.Entry }
end

index2.placeBelow = function(arg, arg2)
return function(arg3)
local absolutePosition = arg3.AbsolutePosition
return math.round(absolutePosition.X) + arg, math.round(absolutePosition.Y + arg3.AbsoluteSize.Y + arg2)
end
end

index2.AttachScrollingList = function(arg, arg2, arg3)
local root = arg.Root
local n = 12
local n33 = 12
local n34 = 12

if arg3 ~= nil then
n = arg3.Top
n33 = arg3.Bottom
n34 = arg3.Side
end

local instance = Instance.new(v86[64])
instance.Active = v86[34]
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = 0
instance.BackgroundTransparency = 1
instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
instance.CanvasSize = UDim2.fromOffset(0, 0)
instance.ScrollBarImageTransparency = 0.35
instance.ScrollBarThickness = v86[186]
instance.Selectable = false
arg.Batch:Bind(instance, "ScrollBarImageColor3", "Accent")
instance.Parent = root
local instance2 = Instance.new(v86[128])
instance2.Position = UDim2.fromOffset(n34, n)
instance2.Size = UDim2.new(1, -n34 * 2, 0, 0)
instance2.AutomaticSize = Enum.AutomaticSize.Y
instance2.BorderSizePixel = 0
instance2.BackgroundTransparency = v86[63]
instance2.Parent = instance
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, v86[12])
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = instance2
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, n33)
uiPadding.Parent = instance2
local v118 = nil

local function updateViewport()
local y = v118 and v118.Y or v86[78]
local v119 = v117.onScreenKeyboardTop()
local n35

if v119 == nil then
n35 = y
else
n35 = math.min(y, v119)
end

local n36 = uiListLayout.AbsoluteContentSize.Y + n + n33
local n37 = math.min(n36, math.max(80, n35 - v86[13]))
root.Size = UDim2.fromOffset(arg2, n37)
local scrollBarThickness = v86[186]

if n36 > n37 + 0.5 then
scrollBarThickness = 4
end

instance.ScrollBarThickness = scrollBarThickness
arg:Reposition()
end

arg._updateViewport = updateViewport
arg.Trove:Connect(uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), updateViewport)

v117.connectCurrentCameraViewport(arg.Trove, function(arg4)
v118 = arg4
updateViewport()
end)

return instance, instance2
end

index2.IsOpen = function(arg)
return arg.Entry.Open
end

index2.Toggle = function(arg)
arg._menu:ToggleOverlay(arg.Entry)
end

index2.SetOpen = function(arg, arg2)
arg._menu:SetOverlayOpen(arg.Entry, arg2)
end

index2.Reposition = function(arg)
if not arg.Entry.Open then
return
end
local v118, v119 = fn36(arg)
if arg._fadeState.Tweening then
arg._menu:Tween(arg.Root, { Position = UDim2.fromOffset(v118, v119) })
return
end
arg.Root.Position = UDim2.fromOffset(v118, v119)
end

index2.Destroy = function(arg)
arg.Trove:Destroy()
end

return index2
end

tbl17.G = function()
local g = tbl17.cache.G

if not g then
g = { c = fn35() }
tbl17.cache.G = g
end

return g.c
end
end
do -- H
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.u()
local v119 = tbl17.x()
local v120 = tbl17.G()
tbl17.B()
local v121 = tbl17.A()
local v122 = tbl17.w()
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local color = Color3.fromRGB(v86[108], v86[108], v86[108])
local index2 = {}
index2.__index = index2

local function fn36(arg)
local tbl18 = {}
local v123 = v86[165]

if type(arg) == v123 then
tbl18[arg] = true
else
local v124 = v86[68]

if type(arg) == v124 then
for k, v125 in arg, nil, nil do
local v126 = v86[165]

if type(k) == v126 and v125 == true then
tbl18[k] = true
else
local v127 = v86[95]

if type(k) == v127 and type(v125) == "string" then
tbl18[v125] = v86[34]
end
end
end
end
end

return tbl18
end

local function fn37(arg)
table.clear(arg._indexByName)

for k, v123 in arg.Options, nil, nil do
arg._indexByName[v123] = k
end
end

local function fn38(arg, arg2)
return arg._labelByValue[arg2] or arg2
end

local function fn39(arg)
local value = arg.Value
if type(value) == "string" then
return fn38(arg, value)
end

if type(value) == "table" then
local tbl18 = {}

for _, v123 in arg.Options, nil, nil do
if value[v123] then
table.insert(tbl18, fn38(arg, v123))
end
end

if v86[186] < #tbl18 then
return table.concat(tbl18, ", ")
end
end

return "Select"
end

local function fn40(arg)
local rt = arg._rt

if rt ~= nil then
rt.ValueLabel.Text = fn39(arg)
end
end

local function fn41(arg, arg2)
local value = arg.Value
if type(value) == "table" then
return value[arg2] == true
end
return value == arg2
end

local function fn42(arg, arg2, arg3, arg4)
local Unselected = v121.get("Unselected")
local imageTransparency = 1

if arg3 then
Unselected = v121.get(v86[174])
imageTransparency = 0
end

arg2.Tick.ImageColor3 = v121.get("TextColor")

if arg4 then
arg2.Button.TextColor3 = Unselected
arg2.Tick.ImageTransparency = imageTransparency
return
end

arg._menu:Tween(arg2.Button, { TextColor3 = Unselected })
arg._menu:Tween(arg2.Tick, { ImageTransparency = imageTransparency })
end

local function fn43(arg, arg2)
local panel = arg._panel
if panel == nil or not panel.Popup:IsOpen() then
return
end

for k, v123 in panel.Rows, nil, nil do
local v124 = arg.Options[k]
fn42(arg, v123, v124 ~= nil and fn41(arg, v124), arg2)
end
end

local function fn44(arg, arg2)
local panel = arg._panel
if panel == nil then
return
end
local str7 = arg2:lower()

for _, v123 in panel.Rows, nil, nil do
v123.Button.Visible = v123.Button.Text:lower():find(str7, 1, true) ~= nil
end

panel.Scroll.CanvasPosition = Vector2.zero
end

local function fn45(arg, arg2)
local v123 = arg.Options[arg2]
if v123 == nil then
return
end

if arg.Multi then
local tbl18 = {}
local value = arg.Value

if type(value) == "table" then
for k in value, nil, nil do
tbl18[k] = true
end
end

if tbl18[v123] then
tbl18[v123] = nil
else
tbl18[v123] = true
end

arg:Set(tbl18)
return
end

arg:Set(v123)
local panel = arg._panel

if arg.CloseOnSelect and panel ~= nil then
panel.Popup:SetOpen(v86[153])
end
end

local function fn46(arg, arg2, layoutOrder)
local listRowHeight = v117.get().Row.ListRowHeight
local textButton = Instance.new("TextButton")
textButton.AutoButtonColor = false
textButton.BackgroundTransparency = v86[63]
textButton.TextColor3 = v121.get(v86[96])
textButton.Text = ""
textButton.Size = UDim2.new(1, 0, v86[186], listRowHeight)
textButton.ClipsDescendants = v86[34]
textButton.TextXAlignment = Enum.TextXAlignment.Left
textButton.BorderSizePixel = 0
textButton.TextSize = v86[13]
textButton.FontFace = arg._menu.Fonts.Main
textButton.LayoutOrder = layoutOrder
textButton.Parent = arg2.Scroll
local instance = Instance.new(v86[113])
instance.PaddingTop = UDim.new(0, 5)
instance.PaddingBottom = UDim.new(0, 5)
instance.PaddingRight = UDim.new(0, 5)
instance.PaddingLeft = UDim.new(0, 29)
instance.Parent = textButton
local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = "rbxassetid://73347151382921"
imageLabel.ImageColor3 = v121.get(v86[174])
imageLabel.ImageTransparency = 1
imageLabel.BackgroundTransparency = 1
imageLabel.AnchorPoint = Vector2.new(0, 0.5)
imageLabel.Position = UDim2.new(0, -22, 0.5, 0)
imageLabel.Size = UDim2.fromOffset(14, 14)
imageLabel.BorderSizePixel = 0
imageLabel.Parent = textButton

v119.connectClick(arg._trove, textButton, function()
if arg2.Popup:IsOpen() then
fn45(arg, layoutOrder)
end
end)

return { Button = textButton, Tick = imageLabel }
end

local function fn47(arg)
local listRowHeight = v117.get().Row.ListRowHeight
local n = #arg.Rows
local scroll = arg.Scroll
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.CanvasSize = UDim2.fromOffset(0, n * listRowHeight + v86[122])

if n >= 10 then
scroll.Size = UDim2.new(v86[63], -1, 0, math.min(v86[162], n) * listRowHeight + 7)
scroll.AutomaticSize = Enum.AutomaticSize.None
else
scroll.Size = UDim2.new(1, -1, 0, v86[186])
scroll.AutomaticSize = Enum.AutomaticSize.Y
end
end

local function fn48(arg)
local panel = arg._panel
if panel == nil then
return
end
local rows = panel.Rows
local options = arg.Options

for k, v123 in options, nil, nil do
local v124 = rows[k]

if v124 == nil then
v124 = fn46(arg, panel, k)
rows[k] = v124
end

local v125 = fn38(arg, v123)

if v124.Button.Text ~= v125 then
v124.Button.Text = v125
end

if not v124.Button.Visible then
v124.Button.Visible = true
end
end

for i = #rows, #options + 1, -v86[63] do
rows[i].Button:Destroy()
rows[i] = nil
end

fn47(panel)
panel.RepositionTrove:Clean()

panel.RepositionTrove:Add(task.defer(function()
panel.Popup:Reposition()
end))
end

local function fn49(arg, arg2)
local listRowHeight = v117.get().Row.ListRowHeight
local menu = arg._menu
local root = arg2.Popup.Root
local instance = Instance.new(v86[128])
instance.BackgroundColor3 = v121.get(v86[168])
instance.BorderSizePixel = 0
instance.Size = UDim2.new(1, 0, 0, listRowHeight)
instance.ClipsDescendants = true
instance.Parent = root
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[186], v86[175])
uiCorner.Parent = instance
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = v121.get("Outline")
uiStroke.Parent = instance
local textBox = Instance.new("TextBox")
textBox.PlaceholderText = v86[190]
textBox.PlaceholderColor3 = v121.get("Unselected")
textBox.FontFace = menu.Fonts.Main
textBox.TextColor3 = v121.get(v86[174])
textBox.Text = ""
textBox.AnchorPoint = Vector2.new(0, 0.5)
textBox.Position = UDim2.new(v86[186], v86[54], 0.5, 0)
textBox.Size = UDim2.new(1, -12, 1, 0)
textBox.BackgroundTransparency = 1
textBox.BorderSizePixel = 0
textBox.TextSize = 14
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = true
textBox.Active = v86[34]
textBox.Parent = instance
arg2.SearchInput = textBox
arg2.Scroll.Position = UDim2.fromOffset(v86[186], v86[192])

arg._trove:Connect(textBox:GetPropertyChangedSignal("Text"), function()
fn44(arg, textBox.Text)
end)

arg._trove:Connect(textBox.Focused, function()
menu:Tween(textBox, { TextColor3 = v121.get("Accent") })
end)

arg._trove:Connect(textBox.FocusLost, function()
menu:Tween(textBox, { TextColor3 = v121.get("TextColor") })
end)
end

local function fn50(arg)
local panel = arg._panel
if panel ~= nil then
return panel
end
local rt = arg._rt
if rt == nil then
return nil
end
local panel2 = nil

local v123 = v120.new(arg._menu, arg._trove, {
Trigger = rt.Pill,
Size = UDim2.fromOffset(80, 0),
AutomaticSize = Enum.AutomaticSize.Y,
AnchorPoint = Vector2.new(1, 0),
Glow = v86[34],
ParentEntry = arg._parentOverlay,
Place = function(arg2, arg3)
local absolutePosition = arg2.AbsolutePosition
local n = math.floor(arg2.AbsoluteSize.X + 2 + 0.5)
local n33 = math.max(n, 80)
local n34 = v86[186]

for _, v123 in panel2.Rows, nil, nil do
if v123.Button.Visible then
n34 = math.max(n34, v123.Button.TextBounds.X)
end
end

arg3.Size = UDim2.fromOffset(math.max(n33, math.ceil(n34) + 40), v86[186])
return math.floor(absolutePosition.X + 0.5) + n, (math.floor(absolutePosition.Y + arg2.AbsoluteSize.Y + 4))
end,
OnToggle = function(arg2)
arg._menu:Tween(rt.Arrow, { Rotation = arg2 and 180 or 0 })
panel2.FocusTrove:Clean()

if not arg2 then
local searchInput = panel2.SearchInput

if searchInput ~= nil then
searchInput:ReleaseFocus()
end

return
end

local getOptions = arg._getOptions

if getOptions ~= nil then
arg:SetOptions(getOptions())
end

fn43(arg, true)
panel2.Scroll.CanvasPosition = Vector2.zero
local searchInput = panel2.SearchInput

if searchInput ~= nil then
searchInput.Text = ""
fn44(arg, "")

panel2.FocusTrove:Add(task.defer(function()
if panel2.Popup:IsOpen() then
searchInput:CaptureFocus()
end

if not flag2 then
return
end
end))
end
end,
})

local y = v122.currentViewportSize().Y
local n = math.floor(y * 0.6)

if v118.IsMobile() then
n = math.floor(y * 0.5)
end

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Active = true
scrollingFrame.ScrollBarImageTransparency = v86[101]
scrollingFrame.ScrollBarThickness = v86[26]
scrollingFrame.Size = UDim2.new(1, -v86[63], 0, 0)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.BackgroundTransparency = v86[63]
scrollingFrame.AutomaticSize = Enum.AutomaticSize.Y
scrollingFrame.CanvasSize = UDim2.fromOffset(0, v86[186])
scrollingFrame.Selectable = v86[153]
scrollingFrame.ScrollBarImageColor3 = v121.get("Accent")
scrollingFrame.Parent = v123.Root
local instance = Instance.new(v86[176])
instance.MaxSize = Vector2.new(math.huge, n)
instance.Parent = scrollingFrame
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingBottom = UDim.new(0, v86[122])
uiPadding.Parent = scrollingFrame
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollingFrame

panel2 = {
Popup = v123,
Scroll = scrollingFrame,
SearchInput = nil,
Rows = {},
RepositionTrove = v123.Trove:Extend(),
FocusTrove = v123.Trove:Extend(),
}

arg._panel = panel2

if arg.Search then
fn49(arg, panel2)
end

fn48(arg)
return panel2
end

local function createTextButton(arg, parent, arg2)
local menu = arg._menu
local v123 = v117.get()
local inline = arg.Inline
local textButton = Instance.new("TextButton")
textButton.AutoButtonColor = false
textButton.Text = ""
textButton.AnchorPoint = Vector2.new(1, v86[101])
textButton.Position = UDim2.new(1, -v86[63], 0.5, 0)
textButton.BorderSizePixel = 0
textButton.BackgroundColor3 = color

if inline then
textButton.Size = UDim2.fromOffset(0, v123.Row.ControlHeight)
textButton.ClipsDescendants = true
textButton.AutomaticSize = Enum.AutomaticSize.X
else
textButton.Size = UDim2.fromOffset(137, 24)
end

textButton.Parent = parent
local uiGradient = Instance.new("UIGradient")
uiGradient.Rotation = v86[45]
arg2.Batch:BindGradient(uiGradient, { "GradientMid", "GradientDark" })
uiGradient.Parent = textButton
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, v86[175])
uiCorner.Parent = textButton

if inline then
local uiSizeConstraint = Instance.new("UISizeConstraint")
uiSizeConstraint.MaxSize = Vector2.new(arg.MaxWidth, v123.Row.ControlHeight)
uiSizeConstraint.Parent = textButton
end

local uiStroke = Instance.new("UIStroke")

if not inline then
uiStroke.BorderOffset = UDim.new(0, -1)
end

uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = textButton
local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = "rbxassetid://84796267467531"
imageLabel.BackgroundTransparency = v86[63]
imageLabel.Size = UDim2.fromOffset(9, 5)
imageLabel.BorderSizePixel = v86[186]

if inline then
imageLabel.LayoutOrder = 1
else
imageLabel.AnchorPoint = Vector2.new(1, 0.5)
imageLabel.Position = UDim2.new(1, -8, 0.5, 0)
end

arg2.Batch:Bind(imageLabel, "ImageColor3", "Unselected")
imageLabel.Parent = textButton
local instance = Instance.new(v86[135])
instance.Text = fn39(arg)
instance.AnchorPoint = Vector2.new(0, v86[101])
instance.Position = UDim2.new(0, 5, v86[101], 0)
instance.BackgroundTransparency = 1
instance.BorderSizePixel = 0
instance.TextSize = v86[13]
instance.TextTruncate = Enum.TextTruncate.AtEnd

if inline then
instance.LayoutOrder = -1
instance.FontFace = menu.Fonts.Main
instance.AutomaticSize = Enum.AutomaticSize.XY
else
instance.ClipsDescendants = true
instance.FontFace = v116.Medium
instance.Size = UDim2.new(1, -25, 0, 0)
instance.TextXAlignment = Enum.TextXAlignment.Left
instance.AutomaticSize = Enum.AutomaticSize.Y
end

arg2.Batch:Bind(instance, "TextColor3", "TextColor")
instance.Parent = textButton

if inline then
local instance2 = Instance.new(v86[113])
instance2.PaddingBottom = UDim.new(0, 2)
instance2.Parent = instance
local uiListLayout = Instance.new("UIListLayout")
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.Padding = UDim.new(0, 6)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = textButton
local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(v86[186], 2)
uiPadding.PaddingRight = UDim.new(0, 6)
uiPadding.PaddingLeft = UDim.new(v86[186], v86[54])
uiPadding.Parent = textButton
local v124 = menu:DragTweenInfo()

arg2.Trove:Connect(instance:GetPropertyChangedSignal("Text"), function()
local controlHeight = v123.Row.ControlHeight
menu:Tween(textButton, { Size = UDim2.fromOffset(math.min(instance.AbsoluteSize.X, arg.MaxWidth), controlHeight) }, v124)
end)

arg2.Trove:Add(task.defer(function()
if instance.Parent ~= nil then
local controlHeight = v123.Row.ControlHeight
textButton.Size = UDim2.fromOffset(math.min(instance.AbsoluteSize.X + v86[144], arg.MaxWidth + 22), controlHeight)
end
end))
end

arg._rt = { Pill = textButton, ValueLabel = instance, Arrow = imageLabel }

if arg._parentOverlay == nil then
arg._parentOverlay = arg2.ParentOverlay
end

v119.connectClick(arg2.Trove, textButton, function()
if #arg.Options == 0 and arg._getOptions == nil then
return
end
local v124 = fn50(arg)

if v124 ~= nil then
v124.Popup:Toggle()
end
end)

local v124 = nil

v119.connectPress(arg2.Trove, textButton, function()
local backgroundColor3 = textButton.BackgroundColor3
v124 = backgroundColor3
menu:Tween(textButton, { BackgroundColor3 = Color3.new(backgroundColor3.R * v86[105], backgroundColor3.G * 0.85, backgroundColor3.B * 0.85) }, tweenInfo)
end, function()
if v124 ~= nil then
menu:Tween(textButton, { BackgroundColor3 = v124 }, tweenInfo)
v124 = nil
end
end)

return textButton
end

local function fn51(arg, arg2, arg3, arg4, arg5, arg6, arg7)
local obj = setmetatable({
_trove = arg3,
_menu = arg,
Kind = "Dropdown",
Row = arg2,
Multi = arg5,
Search = arg4.Search == true,
Inline = arg4.Inline == true,
CloseOnSelect = arg4.CloseOnSelect == true,
MaxWidth = arg4.MaxWidth or 300,
Options = table.clone(arg4.Options or {}),
_labelByValue = arg4.Labels or {},
Value = arg6,
Changed = arg3:Add(v115.new()),
ValueChanged = arg3:Add(v115.new()),
_onChanged = arg7,
_getOptions = arg4.GetOptions,
_isOptionsPublished = arg4.Options ~= nil or arg4.GetOptions == nil,
_indexByName = {},
_rt = nil,
_panel = nil,
_parentOverlay = nil,
}, index2)

fn37(obj)
local n = 138

if obj.Inline then
n = nil
end

arg2:AttachRight(function(arg8, arg9)
return createTextButton(obj, arg8, arg9)
end, n, nil, arg3)

return obj
end

index2._New = function(arg, arg2, arg3, arg4)
local options = arg4.Options or {}
local default = arg4.Default

if not (default ~= nil and (not (arg4.Options ~= nil or arg4.GetOptions == nil) or table.find(options, default) ~= nil)) then
default = options[1]
end

local onChanged = arg4.OnChanged

local function fn52()
end

if onChanged ~= nil then
fn52 = function(arg5)
onChanged(arg5)
end
end

return (fn51(arg, arg2, arg3, arg4, false, default, fn52))
end

index2._NewMulti = function(arg, arg2, arg3, arg4)
local onChanged = arg4.OnChanged

local function fn52()
end

if onChanged ~= nil then
fn52 = function(arg5)
onChanged(arg5)
end
end

return (fn51(arg, arg2, arg3, arg4, v86[34], fn36(arg4.Default), fn52))
end

local function fn52(arg, arg2)
for k in arg, nil, nil do
if not arg2[k] then
return false
end
end

for k in arg2, nil, nil do
if not arg[k] then
return false
end
end

return true
end

index2.Set = function(I,W,N)if I.Multi then local P= fn36 (W);local a=I.Value;if type(a)=="table"and( fn52 (P,a))then return;end;I.Value=P; fn43 (I,N==true); fn40 (I);I.ValueChanged:Fire(I.Value);if not N then I._onChanged(I.Value);I.Changed:Fire(I.Value);end;return;end;local P=if type(W)=="string"and(not I._isOptionsPublished or I._indexByName[W]~=nil)then W else nil;local a=I._isOptionsPublished and W~=nil and P==nil;if P==I.Value and not a then return;end;W=I.Value;I.Value=P;a=I._panel;if a~=nil and(a.Popup:IsOpen())then local e=N==true;local c=type(W)=="string"and I._indexByName[W]or nil;if c~=nil and a.Rows[c]~=nil then  fn42 (I,a.Rows[c],false,e);end;c=P~=nil and I._indexByName[P]or nil;if c~=nil and a.Rows[c]~=nil then  fn42 (I,a.Rows[c],true,e);end;end; fn40 (I);I.ValueChanged:Fire(I.Value);if not N then I._onChanged(I.Value);I.Changed:Fire(I.Value);end;end

index2.SetOptions = function(arg, arg2)
local tbl18 = arg2 or {}
local options = arg.Options
local isOptionsPublished = arg._isOptionsPublished
arg._isOptionsPublished = true

if isOptionsPublished and #tbl18 == #options then
local flag19 = true

for k, v123 in tbl18, nil, nil do
if options[k] ~= v123 then
flag19 = v86[153]
break
end
end

if flag19 then
return
end
end

local value = arg.Value
arg.Options = table.clone(tbl18)
fn37(arg)
fn48(arg)

if arg.Multi then
fn43(arg, true)
fn40(arg)
arg.ValueChanged:Fire(arg.Value)
return
end

local value2 = arg.Value

if type(value2) ~= "string" or arg._indexByName[value2] == nil then
arg.Value = nil
end

fn43(arg, true)
fn40(arg)
arg.ValueChanged:Fire(arg.Value)

if value ~= arg.Value then
arg._onChanged(arg.Value)
arg.Changed:Fire(arg.Value)
end
end

index2.Add = function(arg, arg2)
local v123 = v86[165]
if type(arg2) ~= v123 or arg._indexByName[arg2] ~= nil then
return
end
local v124 = table.clone(arg.Options)
table.insert(v124, arg2)
arg:SetOptions(v124)
end

index2.Remove = function(arg, arg2)
local v123 = arg._indexByName[arg2]
if v123 == nil then
return
end
local v124 = table.clone(arg.Options)
table.remove(v124, v123)
arg:SetOptions(v124)
end

index2.SetOpen = function(arg, arg2)
local v123 = fn50(arg)

if v123 ~= nil then
v123.Popup:SetOpen(arg2)
end
end

index2.SetLabel = function(arg, arg2)
arg.Row:SetLabel(arg2)
return arg
end

index2.SetTooltip = function(arg, arg2)
arg.Row:SetTooltip(arg2)
return arg
end

index2.SetVisible = function(arg, arg2)
arg.Row:SetVisible(arg2)
end

index2.OnChanged = function(arg, arg2)
arg._trove:Connect(arg.Changed, arg2)
return arg
end

index2.Connect = function(arg, arg2, arg3)
arg._trove:Connect(arg2, arg3)
return arg
end

index2.Destroy = function(arg)
arg._trove:Destroy()
end

return index2
end

tbl17.H = function()
local h = tbl17.cache.H

if not h then
h = { c = fn35() }
tbl17.cache.H = h
end

return h.c
end
end
do -- I
local function fn35()
tbl17.r()
local v115 = tbl17.s()
tbl17.B()
local v116 = tbl17.w()
local color = Color3.fromRGB(v86[108], 255, 255)
local udim2 = UDim2.fromOffset(14, 14)
local udim22 = UDim2.fromOffset(18, 18)

return {
buildTrack = function(parent, arg, arg2)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.fromScale(0, 0.5)
frame.Size = UDim2.new(1, -arg2 - 11, 0, 2)
frame.BorderSizePixel = 0
frame.BackgroundColor3 = color
frame.Parent = parent
local uiGradient = Instance.new("UIGradient")
arg.Batch:BindGradient(uiGradient, { "GradientDark", v86[187] })
uiGradient.Parent = frame
local uiStroke = Instance.new("UIStroke")
arg.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(v86[63], 0)
uiCorner.Parent = frame
local instance = Instance.new(v86[128])
instance.AnchorPoint = Vector2.new(0.5, 0.5)
instance.Position = UDim2.fromScale(0.5, 0.5)
instance.Size = UDim2.new(1, v86[186], 0, 44)
instance.BackgroundTransparency = 1
instance.BorderSizePixel = v86[186]
instance.Active = true
instance.ZIndex = 0
instance.Parent = frame
return frame, instance
end,
buildThumb = function(parent)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(v86[186], 0.5)
frame.Size = udim2
frame.BorderSizePixel = v86[186]
frame.BackgroundColor3 = color
frame.ZIndex = 2
frame.Parent = parent
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = frame
return frame
end,
setThumbPressed = function(arg, arg2, arg3)
arg:Tween(arg2, { Size = arg3 and udim22 or udim2 })
end,
valueAt = function(arg, arg2, arg3, arg4)
return (arg4 - arg3) * (arg2 - arg.AbsolutePosition.X) / arg.AbsoluteSize.X + arg3
end,
newTouchBubble = function(arg, arg2)
local v117 = nil
local v118 = nil

local function fn36()
local v119 = v117
local v120 = v118
if v119 ~= nil and v120 ~= nil then
return v119, v120
end
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(v86[101], 0.5)
frame.Size = UDim2.fromOffset(42, 28)
frame.BorderSizePixel = 0
frame.Visible = false
frame.ZIndex = 20
arg2.Batch:Bind(frame, v86[5], "Background")
arg2.Trove:Add(frame)
frame.Parent = arg:GetOverlayLayer()
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 5)
uiCorner.Parent = frame
local uiStroke = Instance.new("UIStroke")
arg2.Batch:Bind(uiStroke, "Color", "Outline")
uiStroke.Parent = frame
local instance = Instance.new(v86[135])
instance.FontFace = v115.SemiBold
instance.BackgroundTransparency = 1
instance.Size = UDim2.fromScale(1, 1)
instance.BorderSizePixel = v86[186]
instance.TextSize = 14
instance.ZIndex = 21
arg2.Batch:Bind(instance, "TextColor3", "TextColor")
instance.Parent = frame
v117 = frame
v118 = instance
return frame, instance
end

return {
Show = function(arg3, text)
local v119, v120 = fn36()
v120.Text = text
v119.Size = UDim2.fromOffset(math.max(42, #text * 8 + 16), v86[25])
local n = arg3.AbsolutePosition + arg3.AbsoluteSize / 2
local v121 = v116.absoluteToLayerOffset(arg:GetOverlayLayer(), n)
v119.Position = UDim2.fromOffset(v121.X, v121.Y - 40)
v119.Visible = v86[34]
end,
Hide = function()
if v117 ~= nil then
v117.Visible = false
end
end,
}
end,
}
end

tbl17.I = function()
local i = tbl17.cache.I

if not i then
i = { c = fn35() }
tbl17.cache.I = i
end

return i.c
end
end
do -- J
local function fn35()
local v115 = tbl17.g()
tbl17.k()
tbl17.r()
local v116 = tbl17.s()
local v117 = tbl17.v()
local v118 = tbl17.x()
tbl17.B()
local v119 = tbl17.I()
local v120 = tbl17.w()
local index2 = {}
index2.__index = index2

local function fn36(arg, arg2, arg3)
local min = arg.Min
local max = arg.Max
local n = math.clamp(v120.round(arg2, arg.Step), min, max)
local n33 = math.clamp(v120.round(arg3, arg.Step), arg.Min, arg.Max)

if not (n33 < n) then
local v121 = n33
n33 = n
n = v121
end

return n33, n
end

local function fn37(arg, arg2)
if arg.Max == arg.Min then
return v86[186]
end
return (arg2 - arg.Min) / (arg.Max - arg.Min)
end

local function fn38(arg, arg2)
local v121 = fn37(arg, arg.Value.Min)
local v122 = fn37(arg, arg.Value.Max)
arg2.MinThumb.Position = UDim2.fromScale(v121, v86[101])
arg2.MaxThumb.Position = UDim2.fromScale(v122, v86[101])
local udim2 = UDim2.fromScale(v121, 0)
local udim22 = UDim2.fromScale(v122 - v121, v86[63])

if arg._isDragging then
arg2.Accent.Position = udim2
arg2.Accent.Size = udim22
else
arg._menu:Tween(arg2.Accent, { Position = udim2, Size = udim22 }, arg._menu:DragTweenInfo())
end

local v123 = tostring
local max = arg.Value.Max
arg2.ValueLabel.Text = ("%s - %s"):format(tostring(arg.Value.Min), v123(max))
end

local function fn39(arg, parent, arg2, arg3)
local menu = arg._menu
local controlHeight = v117.get().Row.ControlHeight
local v121, v122 = v119.buildTrack(parent, arg2, arg3)
local frame = Instance.new("Frame")
frame.Position = UDim2.new(0, 0, 0, v86[186])
frame.Size = UDim2
