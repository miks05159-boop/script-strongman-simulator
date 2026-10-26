--[[====================================================================
  Strongman Simulator — Main (v3.3) + Optimizer
  --------------------------------------------------------------------
  Фичи:
    • Vibe-режимы: 2021 туман / 2022 / Обычный / Хэллоуин / Лоу (без теней)
    • Оптимизатор предметов (БЕЗ потери веса):
        - выключает тени у частей предмета (главный жор GPU)
        - CanQuery/CanTouch off только у невидимых ExtraWeight
        - глушит партиклы/бимы/трейлы и повторные 3D-звуки
        - масса, Massless и CustomPhysicalProperties НЕ трогаются
    • Тихая продажа (Quiet Sell, БЕЗ влияния на баланс):
        - штатная настройка ParticleAmountMultiplier = 0 (только локально)
        - у ItemPickups гасятся партиклы, биллборды, тени и звуки
        - глушатся PickupCoinSound / Coins_Gained
    • Unload + автосохранение состояния (StrongmanSimulator_main.json).

  Автор: Makxyha
  Место: placeId 6766156863
====================================================================]]

if getgenv and getgenv().__Strongman_Unload then
	pcall(getgenv().__Strongman_Unload)
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local plr = Players.LocalPlayer

local PLACE_ID = 6766156863
local GUI_NAME = "StrongmanMainUI"
local CONFIG_FILE = "StrongmanSimulator_main.json"

if game.PlaceId ~= PLACE_ID then
	warn("Strongman Main: скрипт только для Strongman Simulator (placeId " .. PLACE_ID .. ")")
	return
end

local cfg = {
	pos = { x = 20, y = 240 },
	vibeMode = "2021",
	lang = "ru",
	opt = false,
	quiet = true,
	uiVersion = 2,
}

pcall(function()
	if isfile and isfile(CONFIG_FILE) then
		local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
		if type(data) == "table" then
			if type(data.pos) == "table" and tonumber(data.pos.x) and tonumber(data.pos.y) then
				cfg.pos = { x = tonumber(data.pos.x), y = tonumber(data.pos.y) }
			end
			if type(data.vibeMode) == "string" then
				cfg.vibeMode = data.vibeMode
			end
			if type(data.lang) == "string" and (data.lang == "ru" or data.lang == "en") then
				cfg.lang = data.lang
			end
			if type(data.opt) == "boolean" then
				cfg.opt = data.opt
			end
			if type(data.quiet) == "boolean" then
				cfg.quiet = data.quiet
			end
			cfg.uiVersion = tonumber(data.uiVersion) or 0
		end
	end
end)

local function saveConfig()
	pcall(function()
		if writefile then
			writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
		end
	end)
end

-- Старый конфиг без версии: переключаем на понятный русский интерфейс один раз.
if cfg.uiVersion ~= 2 then
	cfg.uiVersion = 2
	cfg.lang = "ru"
	saveConfig()
end

--===================== ТЕКСТ ================================
local STR = {
	ru = {
		ready = "Готово",
		mode = "Режим",
		unload = "ВЫГРУЗИТЬ СКРИПТ",
		hide = "СКРЫТЬ",
		vibeSection = "ВНЕШНИЙ ВИД",
		vibeHint = "Свет, туман и эффекты. «Лоу» — максимум FPS.",
		vibe2021 = "Туман 2021",
		vibe2022 = "2022",
		vibeDefault = "Обычный",
		vibeHalloween = "Хэллоуин",
		vibeLow = "Лоу (без теней)",
		optimizer = "ОПТИМИЗАТОР ПРЕДМЕТОВ",
		optHint = "Гасит тени и лишние рейкасты. Вес предметов НЕ меняется.",
		optOn = "Оптимизация предметов: ВКЛ",
		optOff = "Оптимизация предметов: ВЫКЛ",
		quiet = "ОПТИМИЗАЦИЯ ПРОДАЖИ",
		quietHint = "Без летающих монет, партиклов и звуков. Начисления те же.",
		quietOn = "Тихая продажа: ВКЛ",
		quietOff = "Тихая продажа: ВЫКЛ",
		tabVibe = "ВАЙБ",
		tabItems = "ПРЕДМЕТЫ",
		tabSell = "ПРОДАЖА",
		on = "ВКЛ",
		off = "ВЫКЛ",
		itemsShort = "Предметы",
		sellShort = "Продажа",
		footer = "v3.4  •  Strongman  •  by Makxyha",
	},
	en = {
		ready = "Ready",
		mode = "Mode",
		unload = "UNLOAD SCRIPT",
		hide = "HIDE",
		vibeSection = "APPEARANCE",
		vibeHint = "Lighting, fog and effects. “Low” = max FPS.",
		vibe2021 = "Fog 2021",
		vibe2022 = "2022",
		vibeDefault = "Default",
		vibeHalloween = "Halloween",
		vibeLow = "Low (no shadows)",
		optimizer = "ITEM OPTIMIZER",
		optHint = "Kills shadows and extra raycasts. Item weight is NOT changed.",
		optOn = "Item optimizer: ON",
		optOff = "Item optimizer: OFF",
		quiet = "SELL OPTIMIZER",
		quietHint = "No coin particles, sfx or sounds. Rewards are the same.",
		quietOn = "Quiet sell: ON",
		quietOff = "Quiet sell: OFF",
		tabVibe = "VIBE",
		tabItems = "ITEMS",
		tabSell = "SELL",
		on = "ON",
		off = "OFF",
		itemsShort = "Items",
		sellShort = "Sell",
		footer = "v3.4  •  Strongman  •  by Makxyha",
	},
}

local function T(key)
	local lang = STR[cfg.lang] or STR.ru
	return lang[key] or (STR.ru[key] or tostring(key))
end

--===================== VIBE ==================================
local function ensureAtm()
	return Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
end

local function ensureCC()
	return Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect", Lighting)
end

local function ensureSR()
	return Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect", Lighting)
end

local hadAtm = Lighting:FindFirstChildOfClass("Atmosphere")
local hadCC = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local hadSR = Lighting:FindFirstChildOfClass("SunRaysEffect")
local atm = ensureAtm()
local cc = ensureCC()
local sr = ensureSR()

local original = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	ShadowSoftness = Lighting.ShadowSoftness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	Exposure = Lighting.ExposureCompensation,
	GlobalShadows = Lighting.GlobalShadows,
	atmDensity = hadAtm and atm.Density or 0,
	atmOffset = hadAtm and atm.Offset or 0,
	atmHaze = hadAtm and atm.Haze or 0,
	atmColor = hadAtm and atm.Color or Color3.fromRGB(199, 199, 199),
	atmDecay = hadAtm and atm.Decay or Color3.fromRGB(106, 112, 125),
	ccContrast = hadCC and cc.Contrast or 0,
	ccSaturation = hadCC and cc.Saturation or 0,
	ccTint = hadCC and cc.TintColor or Color3.fromRGB(255, 255, 255),
	srIntensity = hadSR and sr.Intensity or 0,
	srSpread = hadSR and sr.Spread or 0,
}

local FOG_2021 = {
	ClockTime = 15.5,
	Brightness = 2.5,
	ShadowSoftness = 0.35,
	Ambient = Color3.fromRGB(90, 100, 115),
	OutdoorAmbient = Color3.fromRGB(110, 125, 145),
	FogColor = Color3.fromRGB(190, 198, 210),
	FogStart = 0,
	FogEnd = 1500,
	Exposure = 0.1,
	atmDensity = 0.3,
	atmOffset = 0.25,
	atmHaze = 2.5,
	atmColor = Color3.fromRGB(220, 225, 235),
	atmDecay = Color3.fromRGB(180, 195, 210),
	ccContrast = 0.05,
	ccSaturation = 0.12,
	ccTint = Color3.fromRGB(255, 248, 235),
	srIntensity = 0.05,
	srSpread = 0.9,
}

local FOG_2022 = {
	ClockTime = 14.5,
	Brightness = 2.2,
	ShadowSoftness = 0.2,
	Ambient = Color3.fromRGB(60, 65, 70),
	OutdoorAmbient = Color3.fromRGB(75, 80, 85),
	FogStart = 0,
	FogEnd = 100000,
	Exposure = -0.05,
	atmDensity = 0,
	atmOffset = 0,
	atmHaze = 0,
	ccContrast = 0.08,
	ccSaturation = 0.25,
	ccTint = Color3.fromRGB(255, 255, 255),
	srIntensity = 0,
}

local FOG_HALLOWEEN = {
	ClockTime = 19.6,
	Brightness = 1.2,
	ShadowSoftness = 0.15,
	Ambient = Color3.fromRGB(78, 68, 100),
	OutdoorAmbient = Color3.fromRGB(105, 92, 130),
	FogColor = Color3.fromRGB(58, 44, 80),
	FogStart = 90,
	FogEnd = 1200,
	Exposure = -0.08,
	atmDensity = 0.25,
	atmOffset = 0.2,
	atmHaze = 0.1,
	atmColor = Color3.fromRGB(170, 150, 200),
	atmDecay = Color3.fromRGB(60, 50, 90),
	ccContrast = 0.1,
	ccSaturation = 0.3,
	ccTint = Color3.fromRGB(255, 244, 232),
	srIntensity = 0.12,
	srSpread = 0.9,
}

-- Производительный «вайб»: без глобальных теней, тумана и пост-эффектов.
local FOG_LOW = {
	ClockTime = 14.0,
	Brightness = 1.7,
	ShadowSoftness = 0,
	Ambient = Color3.fromRGB(95, 95, 100),
	OutdoorAmbient = Color3.fromRGB(105, 105, 112),
	FogColor = Color3.fromRGB(190, 198, 210),
	FogStart = 0,
	FogEnd = 900,
	Exposure = 0,
	atmDensity = 0,
	atmOffset = 0,
	atmHaze = 0,
	atmColor = Color3.fromRGB(220, 225, 235),
	atmDecay = Color3.fromRGB(180, 195, 210),
	ccContrast = 0.03,
	ccSaturation = 0.05,
	ccTint = Color3.fromRGB(255, 255, 255),
	srIntensity = 0,
	srSpread = 0.5,
	globalShadows = false,
}

local function applyPreset(p)
	Lighting.ClockTime = p.ClockTime
	Lighting.Brightness = p.Brightness
	Lighting.ShadowSoftness = p.ShadowSoftness
	Lighting.Ambient = p.Ambient
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	if p.FogColor then
		Lighting.FogColor = p.FogColor
	end
	Lighting.FogStart = p.FogStart
	Lighting.FogEnd = p.FogEnd
	Lighting.ExposureCompensation = p.Exposure

	if p.globalShadows ~= nil then
		pcall(function()
			Lighting.GlobalShadows = p.globalShadows
		end)
	else
		pcall(function()
			Lighting.GlobalShadows = original.GlobalShadows
		end)
	end

	local atmNow = ensureAtm()
	atmNow.Density = p.atmDensity
	atmNow.Offset = p.atmOffset
	atmNow.Haze = p.atmHaze
	if p.atmColor then
		atmNow.Color = p.atmColor
	end
	if p.atmDecay then
		atmNow.Decay = p.atmDecay
	end

	local ccNow = ensureCC()
	ccNow.Contrast = p.ccContrast
	ccNow.Saturation = p.ccSaturation
	ccNow.TintColor = p.ccTint

	local srNow = ensureSR()
	srNow.Intensity = p.srIntensity
	srNow.Spread = p.srSpread or srNow.Spread
end

local function setStyle2021()
	applyPreset(FOG_2021)
end

local function setStyle2022()
	applyPreset(FOG_2022)
	Lighting.FogColor = original.FogColor
end

local function setStyleHalloween()
	applyPreset(FOG_HALLOWEEN)
end

local function setStyleLow()
	applyPreset(FOG_LOW)
end

local function restoreOriginal()
	Lighting.ClockTime = original.ClockTime
	Lighting.Brightness = original.Brightness
	Lighting.ShadowSoftness = original.ShadowSoftness
	Lighting.Ambient = original.Ambient
	Lighting.OutdoorAmbient = original.OutdoorAmbient
	Lighting.FogColor = original.FogColor
	Lighting.FogStart = original.FogStart
	Lighting.FogEnd = original.FogEnd
	Lighting.ExposureCompensation = original.Exposure
	pcall(function()
		Lighting.GlobalShadows = original.GlobalShadows
	end)

	local atmNow = ensureAtm()
	atmNow.Density = original.atmDensity
	atmNow.Offset = original.atmOffset
	atmNow.Haze = original.atmHaze
	atmNow.Color = original.atmColor
	atmNow.Decay = original.atmDecay

	local ccNow = ensureCC()
	ccNow.Contrast = original.ccContrast
	ccNow.Saturation = original.ccSaturation
	ccNow.TintColor = original.ccTint

	local srNow = ensureSR()
	srNow.Intensity = original.srIntensity
	srNow.Spread = original.srSpread
end

local VIBE_MODES = {
	["2021"] = setStyle2021,
	["2022"] = setStyle2022,
	["default"] = restoreOriginal,
	["halloween"] = setStyleHalloween,
	["low"] = setStyleLow,
}

local VIBE_PRESETS = {
	["2021"] = FOG_2021,
	["2022"] = FOG_2022,
	["halloween"] = FOG_HALLOWEEN,
	["low"] = FOG_LOW,
}

--===================== VIBE ШРИФТЫ (VIBE) ===================
local OLD_FONT = Enum.Font.SourceSansBold
local vibeConnections = {}
local hooked = setmetatable({}, { __mode = "k" })

local function hookOverhead(label)
	if hooked[label] then
		return
	end
	hooked[label] = true
	label.Font = OLD_FONT
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	table.insert(vibeConnections, label:GetPropertyChangedSignal("Font"):Connect(function()
		if label.Parent and label.Font ~= OLD_FONT then
			label.Font = OLD_FONT
		end
	end))
end

local function watchCharacter(char)
	if not char then
		return
	end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("TextLabel") then
			hookOverhead(obj)
		end
	end
	table.insert(vibeConnections, char.DescendantAdded:Connect(function(obj)
		if obj:IsA("TextLabel") then
			hookOverhead(obj)
		end
	end))
end

for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		watchCharacter(p.Character)
	end
	table.insert(vibeConnections, p.CharacterAdded:Connect(watchCharacter))
end
table.insert(vibeConnections, Players.PlayerAdded:Connect(function(p)
	if p.Character then
		watchCharacter(p.Character)
	end
	table.insert(vibeConnections, p.CharacterAdded:Connect(watchCharacter))
end))
watchCharacter(plr.Character)

--===================== ОПТИМИЗАТОР ПРЕДМЕТОВ =================
-- ВАЖНО: масса предмета не меняется. ExtraWeight остаются на месте,
-- Massless и CustomPhysicalProperties не трогаются. Убираем только
-- рендер/рейкаст/звук — то, что реально жрёт клиент.
local OPT = {
	enabled = false,
	seen = setmetatable({}, { __mode = "k" }),
	sweepAcc = 0,
}

-- Оригиналы храним в атрибутах инстанса, а не в памяти:
-- так откат работает даже после перезагрузки скрипта.
local function saveOrig(inst, prop, attr)
	if inst:GetAttribute(attr) == nil then
		local v = inst[prop]
		if typeof(v) == "EnumItem" then
			inst:SetAttribute(attr, v.Name)
		else
			inst:SetAttribute(attr, v)
		end
	end
end

local function restoreOrig(inst, prop, attr)
	local v = inst:GetAttribute(attr)
	if v ~= nil then
		inst[prop] = v
		inst:SetAttribute(attr, nil)
	end
end

local function optimizePart(p)
	saveOrig(p, "CastShadow", "__optCastShadow")
	p.CastShadow = false

	if p.Name == "ExtraWeight" then
		-- невидимые гири: они не должны попадать в рейкасты/тач-события
		saveOrig(p, "CanQuery", "__optCanQuery")
		saveOrig(p, "CanTouch", "__optCanTouch")
		p.CanQuery = false
		p.CanTouch = false
	end

end

local function optimizeOne(d)
	if d:IsA("BasePart") then
		optimizePart(d)
	elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
		saveOrig(d, "Enabled", "__optEnabled")
		d.Enabled = false
	elseif d:IsA("Sound") then
		-- звук перетаскивания на каждом предмете: 100 штук = 100 звуков
		if d.Playing then
			d:Stop()
		end
		d.Volume = 0
	elseif d:IsA("RopeConstraint") then
		-- верёвка нужна только физике, рисуемую линию гасим
		d.Visible = false
	elseif d:IsA("Animator") then
		for _, track in ipairs(d:GetPlayingAnimationTracks()) do
			pcall(function()
				track:Stop(0)
			end)
		end
		if not d:GetAttribute("__optAnimHook") then
			d:SetAttribute("__optAnimHook", true)
			table.insert(vibeConnections, d.AnimationPlayed:Connect(function(track)
				if OPT.enabled then
					pcall(function()
						track:Stop(0)
					end)
				end
			end))
		end
	elseif d:IsA("Decal") and d.Name:find("Blueprint") then
		d:Destroy()
	end
end

local function restoreOne(d)
	if d:IsA("BasePart") then
		pcall(function()
			restoreOrig(d, "CastShadow", "__optCastShadow")
			restoreOrig(d, "CanQuery", "__optCanQuery")
			restoreOrig(d, "CanTouch", "__optCanTouch")
		end)
	elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
		pcall(function()
			restoreOrig(d, "Enabled", "__optEnabled")
		end)
	end
end

local function optimizeTree(root)
	if OPT.seen[root] then
		return
	end
	OPT.seen[root] = true
	optimizeOne(root)
	for _, d in ipairs(root:GetDescendants()) do
		optimizeOne(d)
	end
end

local function getOwnFolder()
	local pd = workspace:FindFirstChild("PlayerDraggables")
	if not pd then
		return nil
	end
	return pd:FindFirstChild(tostring(plr.UserId))
end

local function sweep()
	local folder = getOwnFolder()
	if not folder then
		return
	end
	for _, item in ipairs(folder:GetChildren()) do
		optimizeTree(item)
	end
end

local function revertOptimizer()
	local folder = getOwnFolder()
	if folder then
		for _, item in ipairs(folder:GetChildren()) do
			restoreOne(item)
			for _, d in ipairs(item:GetDescendants()) do
				restoreOne(d)
			end
		end
	end
	table.clear(OPT.seen)
end

local function setOptimizer(state, save)
	state = state and true or false
	if OPT.enabled == state then
		return
	end
	OPT.enabled = state
	if state then
		table.clear(OPT.seen)
		sweep()
	else
		revertOptimizer()
	end
	if save ~= false then
		cfg.opt = state
		saveConfig()
	end
end

-- ловим новые предметы сразу, не ждём тик
local pdService = workspace:WaitForChild("PlayerDraggables", 10)
if pdService then
	table.insert(vibeConnections, pdService.DescendantAdded:Connect(function(d)
		if not OPT.enabled then
			return
		end
		local ownFolder = d:FindFirstAncestor(tostring(plr.UserId))
		if ownFolder and ownFolder.Parent == pdService then
			optimizeTree(d)
		end
	end))
end

table.insert(vibeConnections, RunService.Heartbeat:Connect(function(dt)
	if not OPT.enabled then
		return
	end
	OPT.sweepAcc = OPT.sweepAcc + dt
	if OPT.sweepAcc < 1.5 then
		return
	end
	OPT.sweepAcc = 0
	sweep()
end))

--===================== ТИХАЯ ПРОДАЖА =========================
-- Оптимизация ТОЛЬКО визуала при продаже предметов:
--  • штатная настройка игры ParticleAmountMultiplier = 0 (без летающих монет)
--  • у моделей ItemPickups гасим партиклы/биллборды/звуки и тени
--  • глушим PickupCoinSound / Coins_Gained
-- Баланс, начисления и тайминги НЕ меняются.
local QUIET = {
	enabled = false,
	seen = setmetatable({}, { __mode = "k" }),
	origParticle = nil,
}

local DataStoreSvc
local PersistentSettings
pcall(function()
	DataStoreSvc = require(workspace.Lib.Data.TGSDataStore)
end)
pcall(function()
	PersistentSettings = require(workspace.Lib.TGSPersistentSettings)
end)

local function readParticleMultiplier()
	if DataStoreSvc and DataStoreSvc.PlayerData and DataStoreSvc.PlayerData.PlayerSettings then
		local v = DataStoreSvc.PlayerData.PlayerSettings.ParticleAmountMultiplier
		if type(v) == "number" then
			return v
		end
	end
	return 1
end

-- Меняем частицы ТОЛЬКО локально: пишем в клиентский кэш настроек и
-- дёргаем штатный SettingChangedEvent, чтобы ParticleOverlay перечитал значение.
-- На сервер ничего не отправляется, баланс не затрагивается.
local function writeParticleMultiplier(v)
	if DataStoreSvc and DataStoreSvc.PlayerData and DataStoreSvc.PlayerData.PlayerSettings then
		DataStoreSvc.PlayerData.PlayerSettings.ParticleAmountMultiplier = v
	end
	if PersistentSettings and PersistentSettings.SettingChangedEvent then
		pcall(function()
			PersistentSettings.SettingChangedEvent:Fire("ParticleAmountMultiplier", v)
		end)
	end
	-- Главное: шлём штатный ремоут настроек игры. Сервер обновит настройку
	-- и синхронизирует её во ВСЕ клиентские копии модулей — тогда реальный
	-- ParticleOverlay тоже видит 0 и не спавнит монеты при продаже.
	if PersistentSettings and PersistentSettings.SetSettingRemote then
		pcall(function()
			PersistentSettings.SetSettingRemote:FireServer("ParticleAmountMultiplier", v)
		end)
	end
	-- require в executor'е может дать свою копию модуля, поэтому
	-- дополнительно дёргаем все BindableEvent'ы, которые висят на
	-- самом ModuleScript — среди них есть и «живой» инстанс игры.
	local mod = workspace:FindFirstChild("TGSPersistentSettings")
	if mod then
		for _, c in ipairs(mod:GetChildren()) do
			if c:IsA("BindableEvent") then
				pcall(function()
					c:Fire("ParticleAmountMultiplier", v)
				end)
			end
		end
	end
end

local function muteSound(snd)
	task.defer(function()
		pcall(function()
			snd.Volume = 0
			snd:Stop()
			snd:Destroy()
		end)
	end)
end

local function quietPickup(model)
	if QUIET.seen[model] then
		return
	end
	QUIET.seen[model] = true

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanTouch = false
			d.CanQuery = false
			-- монеты двигаются через PivotTo, физика им не нужна
			d.Anchored = true
			d.Massless = true
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = false
		elseif d:IsA("BillboardGui") then
			pcall(function()
				d.Enabled = false
			end)
		elseif d:IsA("Sound") then
			muteSound(d)
		end
	end

	local primary = model.PrimaryPart
	if primary then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= primary then
				d:Destroy()
			end
		end
	end
end

local function hookPickupsFolder(folder)
	table.insert(vibeConnections, folder.ChildAdded:Connect(function(m)
		if QUIET.enabled then
			quietPickup(m)
		end
	end))
	table.insert(vibeConnections, folder.DescendantAdded:Connect(function(d)
		if not QUIET.enabled then
			return
		end
		if d:IsA("Sound") then
			muteSound(d)
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = false
		elseif d:IsA("BillboardGui") then
			pcall(function()
				d.Enabled = false
			end)
		end
	end))
	for _, m in ipairs(folder:GetChildren()) do
		if QUIET.enabled then
			quietPickup(m)
		end
	end
end

local function hookCharacterSounds(char)
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	if not root then
		return
	end
	table.insert(vibeConnections, root.DescendantAdded:Connect(function(d)
		if not QUIET.enabled then
			return
		end
		if d:IsA("Sound") then
			local n = d.Name:lower()
			if n:find("pickupcoin") or n:find("coins_gained") or n:find("coinsgained") then
				muteSound(d)
			end
		elseif d:IsA("BillboardGui") and d.Name == "FloatingCombatText" then
			-- всплывающие "+N" над головой: при массовой продаже их сотни
			task.delay(0.05, function()
				pcall(function()
					d:Destroy()
				end)
			end)
		end
	end))
end

-- Летающие монеты к HUD: ParticleOverlay клонирует ImageLabel на каждый
-- прирост. При продаже 100 предметов это до ~1000 клонов + твины.
-- Режем их на корню: всё, что добавилось в ParticleOverlay после инициализации
-- и похоже на шаблон эффекта, уничтожаем.
local overlayWhitelist = setmetatable({}, { __mode = "k" })
local overlayHooked = false

local function shouldKillOverlayChild(c)
	if not c:IsA("GuiObject") then
		return false
	end
	if overlayWhitelist[c] then
		return false
	end
	return c.Name:find("Template") ~= nil
end

local function sweepOverlay()
	local pg = plr:FindFirstChild("PlayerGui")
	local po = pg and pg:FindFirstChild("ParticleOverlay")
	if not po then
		return
	end
	for _, c in ipairs(po:GetChildren()) do
		if shouldKillOverlayChild(c) then
			pcall(function()
				c:Destroy()
			end)
		end
	end
end

local function hookParticleOverlay()
	if overlayHooked then
		return
	end
	local pg = plr:FindFirstChild("PlayerGui")
	local po = pg and pg:FindFirstChild("ParticleOverlay")
	if not po then
		if pg then
			table.insert(vibeConnections, pg.ChildAdded:Connect(function(c)
				if c.Name == "ParticleOverlay" then
					hookParticleOverlay()
				end
			end))
		end
		return
	end
	overlayHooked = true
	for _, c in ipairs(po:GetChildren()) do
		overlayWhitelist[c] = true
	end
	table.insert(vibeConnections, po.ChildAdded:Connect(function(c)
		if not QUIET.enabled then
			return
		end
		if shouldKillOverlayChild(c) then
			task.delay(0.05, function()
				pcall(function()
					c:Destroy()
				end)
			end)
		end
	end))
end

hookParticleOverlay()

local function setupQuietHooks()
	local temp = workspace:WaitForChild("Temp", 10)
	if not temp then
		return
	end
	local folder = temp:FindFirstChild("ItemPickups")
	if folder then
		hookPickupsFolder(folder)
	else
		table.insert(vibeConnections, temp.ChildAdded:Connect(function(c)
			if c.Name == "ItemPickups" then
				hookPickupsFolder(c)
			end
		end))
	end
end

setupQuietHooks()

if plr.Character then
	hookCharacterSounds(plr.Character)
end
table.insert(vibeConnections, plr.CharacterAdded:Connect(hookCharacterSounds))

local function setQuietSell(state, save)
	state = state and true or false
	QUIET.enabled = state

	if state then
		local cur = readParticleMultiplier()
		QUIET.origParticle = cur
		if cur ~= 0 then
			pcall(function()
				writeParticleMultiplier(0)
			end)
		end
		local folder = workspace.Temp and workspace.Temp:FindFirstChild("ItemPickups")
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				quietPickup(m)
			end
		end
		sweepOverlay()
		local root = plr.Character and (plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character.PrimaryPart)
		if root then
			for _, d in ipairs(root:GetChildren()) do
				if d:IsA("BillboardGui") and d.Name == "FloatingCombatText" then
					pcall(function()
						d:Destroy()
					end)
				end
			end
		end
	else
		if QUIET.origParticle ~= nil then
			pcall(function()
				writeParticleMultiplier(QUIET.origParticle)
			end)
			QUIET.origParticle = nil
		end
	end

	if save ~= false then
		cfg.quiet = state
		saveConfig()
	end
end

--===================== GUI ==================================
local statusText = T("ready")

local parent = (gethui and gethui()) or plr:WaitForChild("PlayerGui")
local old = parent:FindFirstChild(GUI_NAME)
if old then
	old:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = GUI_NAME
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = parent

local function applyGuiFonts(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		if not obj:IsDescendantOf(workspace) and not obj:IsDescendantOf(screen) then
			obj.Font = Enum.Font.GothamBold
		end
	end
end
for _, v in ipairs(plr.PlayerGui:GetDescendants()) do
	applyGuiFonts(v)
end
table.insert(vibeConnections, plr.PlayerGui.DescendantAdded:Connect(applyGuiFonts))

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(360, 452)
panel.Position = UDim2.fromOffset(cfg.pos.x, cfg.pos.y)
panel.BackgroundColor3 = Color3.fromRGB(12, 10, 16)
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = screen

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 17, 32)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 7, 12)),
})
panelGradient.Rotation = 90
panelGradient.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 70, 140)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = panel

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.new(1, -28, 0, 3)
accent.Position = UDim2.fromOffset(14, 8)
accent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
accent.BorderSizePixel = 0
accent.Parent = panel

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local accentGradient = Instance.new("UIGradient")
accentGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(168, 85, 247)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 72, 153)),
})
accentGradient.Parent = accent

local ACCENT_A = Color3.fromRGB(168, 85, 247)
local ACCENT_MID = Color3.fromRGB(203, 80, 240)
local ACCENT_B = Color3.fromRGB(236, 72, 153)
local TEXT_MAIN = Color3.fromRGB(245, 240, 250)
local TEXT_DIM = Color3.fromRGB(172, 158, 188)
local CARD_BG = Color3.fromRGB(18, 15, 23)
local CARD_STROKE = Color3.fromRGB(52, 40, 68)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.fromOffset(210, 24)
title.Position = UDim2.fromOffset(14, 14)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 19
title.TextColor3 = TEXT_MAIN
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "STRONGMAN"
title.Active = true
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.fromOffset(220, 12)
subtitle.Position = UDim2.fromOffset(14, 37)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.TextSize = 9
subtitle.TextColor3 = Color3.fromRGB(200, 150, 245)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "MAIN PANEL  •  HALLOWEEN EDITION"
subtitle.Active = true
subtitle.Parent = panel

local info = Instance.new("TextLabel")
info.Name = "Info"
info.Size = UDim2.new(1, -28, 0, 12)
info.Position = UDim2.fromOffset(14, 50)
info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham
info.TextSize = 9
info.TextColor3 = TEXT_DIM
info.TextXAlignment = Enum.TextXAlignment.Left
info.Text = statusText
info.Parent = panel

local btnStyles = {}

local function makeButton(parent, name, text, pos, size)
	local bg = Instance.new("Frame")
	bg.Name = name .. "Bg"
	bg.Size = size
	bg.Position = pos
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bg.BorderSizePixel = 0
	bg.ZIndex = 1
	bg.Parent = parent
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 29, 46)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 17, 30)),
	})
	grad.Parent = bg

	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(120, 95, 160)
	st.Thickness = 1.2
	st.Transparency = 0.45
	st.Parent = bg

	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = pos
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = TEXT_MAIN
	btn.Text = text
	btn.ZIndex = 2
	btn.Parent = parent

	btnStyles[btn] = { bg = bg, grad = grad, stroke = st }
	return btn
end

local function setButtonActive(btn, active)
	local e = btnStyles[btn]
	if not e then
		return
	end
	if active then
		e.grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, ACCENT_A),
			ColorSequenceKeypoint.new(0.55, ACCENT_MID),
			ColorSequenceKeypoint.new(1, ACCENT_B),
		})
		e.stroke.Color = Color3.fromRGB(240, 170, 255)
		e.stroke.Transparency = 0.1
		e.stroke.Thickness = 1.5
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		e.grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 29, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 17, 30)),
		})
		e.stroke.Color = Color3.fromRGB(120, 95, 160)
		e.stroke.Transparency = 0.45
		e.stroke.Thickness = 1.2
		btn.TextColor3 = Color3.fromRGB(232, 224, 242)
	end
end

local function applyButtonStyle(btn)
	setButtonActive(btn, false)
end

local function makeSectionLabel(parent, name, text, y)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(1, -32, 0, 14)
	lbl.Position = UDim2.fromOffset(16, y)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(210, 150, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

local function makeHintLabel(parent, name, text, y, height)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(1, -32, 0, height or 40)
	lbl.Position = UDim2.fromOffset(16, y)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.TextColor3 = TEXT_DIM
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

local langBtn = makeButton(panel, "LangBtn", cfg.lang == "ru" and "RU" or "EN", UDim2.new(1, -112, 0, 14), UDim2.fromOffset(38, 24))
langBtn.TextSize = 11

local toggleBtn = makeButton(panel, "ToggleBtn", T("hide"), UDim2.new(1, -70, 0, 14), UDim2.fromOffset(56, 24))
toggleBtn.TextSize = 10

local tabVibe = makeButton(panel, "TabVibe", T("tabVibe"), UDim2.fromOffset(14, 70), UDim2.fromOffset(105, 34))
local tabItems = makeButton(panel, "TabItems", T("tabItems"), UDim2.fromOffset(127, 70), UDim2.fromOffset(105, 34))
local tabSell = makeButton(panel, "TabSell", T("tabSell"), UDim2.fromOffset(240, 70), UDim2.fromOffset(105, 34))
for _, b in ipairs({ tabVibe, tabItems, tabSell }) do
	b.TextSize = 12
end

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.fromOffset(332, 248)
card.Position = UDim2.fromOffset(14, 114)
card.BackgroundColor3 = CARD_BG
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Parent = panel
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
local cardStroke = Instance.new("UIStroke", card)
cardStroke.Color = CARD_STROKE
cardStroke.Thickness = 1
cardStroke.Transparency = 0.3

local function newPage(name)
	local p = Instance.new("Frame")
	p.Name = name
	p.Size = UDim2.fromScale(1, 1)
	p.BackgroundTransparency = 1
	p.Parent = card
	return p
end

local vibePage = newPage("VibePage")
local itemsPage = newPage("ItemsPage")
local sellPage = newPage("SellPage")

local vibeLabel = makeSectionLabel(vibePage, "VibeLabel", T("vibeSection"), 16)
local vibeHint = makeHintLabel(vibePage, "VibeHint", T("vibeHint"), 34, 38)

local vibeBtn2021 = makeButton(vibePage, "Vibe2021", T("vibe2021"), UDim2.fromOffset(16, 80), UDim2.fromOffset(144, 34))
local vibeBtn2022 = makeButton(vibePage, "Vibe2022", T("vibe2022"), UDim2.fromOffset(172, 80), UDim2.fromOffset(144, 34))
local vibeBtnDefault = makeButton(vibePage, "VibeDefault", T("vibeDefault"), UDim2.fromOffset(16, 118), UDim2.fromOffset(144, 34))
local vibeBtnHalloween = makeButton(vibePage, "VibeHalloween", T("vibeHalloween"), UDim2.fromOffset(172, 118), UDim2.fromOffset(144, 34))
local vibeBtnLow = makeButton(vibePage, "VibeLow", T("vibeLow"), UDim2.fromOffset(16, 156), UDim2.new(1, -32, 0, 34))

local vibeInfo = Instance.new("TextLabel")
vibeInfo.Name = "VibeInfo"
vibeInfo.Size = UDim2.new(1, -32, 0, 12)
vibeInfo.Position = UDim2.fromOffset(16, 204)
vibeInfo.BackgroundTransparency = 1
vibeInfo.Font = Enum.Font.Gotham
vibeInfo.TextSize = 9
vibeInfo.TextColor3 = TEXT_DIM
vibeInfo.TextXAlignment = Enum.TextXAlignment.Left
vibeInfo.Text = ""
vibeInfo.Parent = vibePage

local optLabel = makeSectionLabel(itemsPage, "OptLabel", T("optimizer"), 16)
local optHint = makeHintLabel(itemsPage, "OptHint", T("optHint"), 34, 44)
local optBtn = makeButton(itemsPage, "OptBtn", T("optOff"), UDim2.fromOffset(16, 92), UDim2.new(1, -32, 0, 44))
optBtn.TextSize = 13

local quietLabel = makeSectionLabel(sellPage, "QuietLabel", T("quiet"), 16)
local quietHint = makeHintLabel(sellPage, "QuietHint", T("quietHint"), 34, 44)
local quietBtn = makeButton(sellPage, "QuietBtn", T("quietOff"), UDim2.fromOffset(16, 92), UDim2.new(1, -32, 0, 44))
quietBtn.TextSize = 13

local vibeButtons = {
	["2021"] = vibeBtn2021,
	["2022"] = vibeBtn2022,
	["default"] = vibeBtnDefault,
	["halloween"] = vibeBtnHalloween,
	["low"] = vibeBtnLow,
}

local currentVibe = "2021"
local currentTab = "vibe"

local tabs = { vibe = tabVibe, items = tabItems, sell = tabSell }
local pages = { vibe = vibePage, items = itemsPage, sell = sellPage }

local function setTab(name)
	currentTab = name
	for k, p in pairs(pages) do
		p.Visible = (k == name)
	end
	for k, b in pairs(tabs) do
		setButtonActive(b, k == name)
	end
end

local function refreshVibeButtons()
	for mode, btn in pairs(vibeButtons) do
		setButtonActive(btn, mode == currentVibe)
	end
end

local unloadBtn = makeButton(panel, "UnloadBtn", T("unload"), UDim2.fromOffset(14, 376), UDim2.new(1, -28, 0, 40))
unloadBtn.TextSize = 12

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.fromOffset(16, 428)
statusDot.BackgroundColor3 = Color3.fromRGB(90, 220, 150)
statusDot.BorderSizePixel = 0
statusDot.Parent = panel
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local footer = Instance.new("TextLabel")
footer.Name = "Footer"
footer.Size = UDim2.new(1, -46, 0, 14)
footer.Position = UDim2.fromOffset(30, 423)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 10
footer.TextColor3 = TEXT_DIM
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Text = T("footer")
footer.Parent = panel

local function refreshInfo()
	local vibeKey = "vibe" .. currentVibe:sub(1, 1):upper() .. currentVibe:sub(2)
	local text = T("mode") .. ": " .. T(vibeKey)
	info.Text = text
	if vibeInfo then
		vibeInfo.Text = text
	end
end

local function updateTexts()
	langBtn.Text = cfg.lang == "ru" and "RU" or "EN"
	toggleBtn.Text = T("hide")
	unloadBtn.Text = T("unload")
	tabVibe.Text = T("tabVibe")
	tabItems.Text = T("tabItems")
	tabSell.Text = T("tabSell")
	vibeLabel.Text = T("vibeSection")
	vibeHint.Text = T("vibeHint")
	vibeBtn2021.Text = T("vibe2021")
	vibeBtn2022.Text = T("vibe2022")
	vibeBtnDefault.Text = T("vibeDefault")
	vibeBtnHalloween.Text = T("vibeHalloween")
	vibeBtnLow.Text = T("vibeLow")
	optLabel.Text = T("optimizer")
	optHint.Text = T("optHint")
	optBtn.Text = OPT.enabled and T("optOn") or T("optOff")
	setButtonActive(optBtn, OPT.enabled)
	quietLabel.Text = T("quiet")
	quietHint.Text = T("quietHint")
	quietBtn.Text = QUIET.enabled and T("quietOn") or T("quietOff")
	setButtonActive(quietBtn, QUIET.enabled)
	footer.Text = T("itemsShort") .. ": " .. (OPT.enabled and T("on") or T("off"))
		.. "    •    " .. T("sellShort") .. ": " .. (QUIET.enabled and T("on") or T("off"))
	statusDot.BackgroundColor3 = (OPT.enabled and QUIET.enabled) and Color3.fromRGB(90, 220, 150) or Color3.fromRGB(235, 170, 80)
	refreshVibeButtons()
	refreshInfo()
	setTab(currentTab)
end

if getgenv then
	getgenv().__StrongmanOptimizer = function(state)
		setOptimizer(state)
		updateTexts()
	end
	getgenv().__StrongmanQuietSell = function(state)
		setQuietSell(state)
		updateTexts()
	end
end

local function applyVibe(mode, save)
	local m = VIBE_MODES[mode] and mode or "2021"
	VIBE_MODES[m]()
	currentVibe = m
	cfg.vibeMode = m
	refreshVibeButtons()
	refreshInfo()
	if save then
		saveConfig()
	end
end

local lastVibePulse = 0

local function vibeDrifted(p)
	if math.abs(Lighting.ClockTime - p.ClockTime) > 1.5 then
		return true
	end
	if math.abs(Lighting.Brightness - p.Brightness) > 0.4 then
		return true
	end
	if math.abs(Lighting.FogEnd - p.FogEnd) > math.max(400, p.FogEnd * 0.5) then
		return true
	end
	local atmNow = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmNow and math.abs(atmNow.Density - p.atmDensity) > 0.2 then
		return true
	end
	return false
end

local function pulseVibe()
	local preset = VIBE_PRESETS[currentVibe]
	if not preset then
		return
	end
	if os.clock() - lastVibePulse < 2 then
		return
	end
	lastVibePulse = os.clock()
	if vibeDrifted(preset) then
		VIBE_MODES[currentVibe]()
	end
end

table.insert(vibeConnections, Lighting.DescendantAdded:Connect(function(inst)
	if (inst:IsA("Atmosphere") or inst:IsA("PostEffect")) and currentVibe and currentVibe ~= "default" then
		task.defer(function()
			VIBE_MODES[currentVibe]()
		end)
	end
end))

local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = panel.Position
	end
end)
title.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		cfg.pos = { x = panel.Position.X.Offset, y = panel.Position.Y.Offset }
		saveConfig()
	end
end)
local inputConn = UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		panel.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
	end
end)

local idledConn = plr.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

local unloaded = false
local heartbeatConn = nil

local function unload()
	if unloaded then
		return
	end
	unloaded = true
	setOptimizer(false, false)
	setQuietSell(false, false)
	restoreOriginal()
	for _, c in ipairs(vibeConnections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(vibeConnections)
	if inputConn then
		pcall(function()
			inputConn:Disconnect()
		end)
	end
	if keyConn then
		pcall(function()
			keyConn:Disconnect()
		end)
	end
	if idledConn then
		pcall(function()
			idledConn:Disconnect()
		end)
	end
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	screen:Destroy()
	if getgenv then
		getgenv().__Strongman_Unload = nil
		getgenv().__StrongmanOptimizer = nil
		getgenv().__StrongmanQuietSell = nil
		getgenv().__StrongmanPerf = nil
	end
end

if getgenv then
	getgenv().__Strongman_Unload = unload
end

heartbeatConn = RunService.Heartbeat:Connect(function()
	pulseVibe()
end)

local hidden = false

local function setHidden(state)
	hidden = state
	panel.Visible = not state
end

toggleBtn.Activated:Connect(function()
	setHidden(true)
end)

local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		setHidden(true)
	elseif input.KeyCode == Enum.KeyCode.G then
		setHidden(false)
	end
end)

langBtn.Activated:Connect(function()
	cfg.lang = (cfg.lang == "ru") and "en" or "ru"
	updateTexts()
	saveConfig()
end)

tabVibe.Activated:Connect(function()
	setTab("vibe")
end)
tabItems.Activated:Connect(function()
	setTab("items")
end)
tabSell.Activated:Connect(function()
	setTab("sell")
end)

vibeBtn2021.Activated:Connect(function()
	applyVibe("2021", true)
end)
vibeBtn2022.Activated:Connect(function()
	applyVibe("2022", true)
end)
vibeBtnDefault.Activated:Connect(function()
	applyVibe("default", true)
end)
vibeBtnHalloween.Activated:Connect(function()
	applyVibe("halloween", true)
end)
vibeBtnLow.Activated:Connect(function()
	applyVibe("low", true)
end)

optBtn.Activated:Connect(function()
	setOptimizer(not OPT.enabled)
	updateTexts()
end)

quietBtn.Activated:Connect(function()
	setQuietSell(not QUIET.enabled)
	updateTexts()
end)

unloadBtn.Activated:Connect(unload)

--===================== ЗАМЕР ПРОИЗВОДИТЕЛЬНОСТИ =================
local PERF = {
	worstDt = 0,
	worstFps = 0,
	worstPickups = 0,
	worstOverlay = 0,
	worstItems = 0,
	worstPing = 0,
	worstAt = 0,
	spikes = {},
}

local function perfCountOverlay()
	local po = plr.PlayerGui and plr.PlayerGui:FindFirstChild("ParticleOverlay")
	local n = 0
	if po then
		for _, c in ipairs(po:GetChildren()) do
			if c:IsA("ImageLabel") and c.Name ~= "CandyCanesCurrencyTemplate" then
				n += 1
			end
		end
	end
	return n
end

table.insert(vibeConnections, RunService.Heartbeat:Connect(function(dt)
	if dt < 0.05 then
		return
	end
	local pd = workspace.Temp and workspace.Temp:FindFirstChild("ItemPickups")
	local pickups = pd and #pd:GetChildren() or 0
	local pickupParts = pd and #pd:GetDescendants() or 0
	local own = workspace.PlayerDraggables and workspace.PlayerDraggables:FindFirstChild(tostring(plr.UserId))
	local items = own and #own:GetChildren() or 0
	local itemParts = own and #own:GetDescendants() or 0
	table.insert(PERF.spikes, {
		dt = dt,
		pickups = pickups,
		pickupParts = pickupParts,
		items = items,
		itemParts = itemParts,
		overlay = perfCountOverlay(),
		ping = plr:GetNetworkPing(),
		at = os.time(),
	})
	while #PERF.spikes > 15 do
		table.remove(PERF.spikes, 1)
	end
end))

task.spawn(function()
	while not unloaded do
		local winMax, winSum, winFrames = 0, 0, 0
		local winOverlay, winPickups, winItems, winPing = 0, 0, 0, 0
		local t0 = os.clock()
		while os.clock() - t0 < 2 do
			local dt = RunService.Heartbeat:Wait()
			winFrames += 1
			winSum += dt
			if dt > winMax then
				winMax = dt
			end
			if winFrames % 10 == 0 then
				local pd = workspace.Temp and workspace.Temp:FindFirstChild("ItemPickups")
				local pc = pd and #pd:GetChildren() or 0
				if pc > winPickups then
					winPickups = pc
				end
				local po = plr.PlayerGui and plr.PlayerGui:FindFirstChild("ParticleOverlay")
				local oc = 0
				if po then
					for _, c in ipairs(po:GetChildren()) do
						if c:IsA("ImageLabel") and c.Name ~= "CandyCanesCurrencyTemplate" then
							oc += 1
						end
					end
				end
				if oc > winOverlay then
					winOverlay = oc
				end
				local ownFolder = workspace.PlayerDraggables and workspace.PlayerDraggables:FindFirstChild(tostring(plr.UserId))
				local ic = ownFolder and #ownFolder:GetChildren() or 0
				if ic > winItems then
					winItems = ic
				end
				local ping = plr:GetNetworkPing()
				if ping > winPing then
					winPing = ping
				end
			end
		end
		if winMax > PERF.worstDt then
			PERF.worstDt = winMax
			PERF.worstFps = 1 / math.max(winSum / math.max(1, winFrames), 1e-4)
			PERF.worstPickups = winPickups
			PERF.worstOverlay = winOverlay
			PERF.worstItems = winItems
			PERF.worstPing = winPing
			PERF.worstAt = os.time()
		end
	end
end)

if getgenv then
	getgenv().__StrongmanPerf = function(reset)
		local spikesCopy = {}
		for i, s in ipairs(PERF.spikes) do
			spikesCopy[i] = s
		end
		local snap = {
			worstDt = PERF.worstDt,
			worstFps = PERF.worstFps,
			pickupsAtWorst = PERF.worstPickups,
			overlayAtWorst = PERF.worstOverlay,
			itemsAtWorst = PERF.worstItems,
			pingAtWorst = PERF.worstPing,
			at = PERF.worstAt,
			spikes = spikesCopy,
		}
		if reset then
			PERF.worstDt = 0
			PERF.worstFps = 0
			PERF.worstPickups = 0
			PERF.worstOverlay = 0
			PERF.worstItems = 0
			PERF.worstPing = 0
			PERF.worstAt = 0
			table.clear(PERF.spikes)
		end
		return snap
	end
end

applyVibe(cfg.vibeMode or "2021", false)
if cfg.opt then
	setOptimizer(true)
end
if cfg.quiet then
	setQuietSell(true, false)
end
updateTexts()

print("[Strongman Main] loaded. Vibe: " .. currentVibe .. " | Lang: " .. cfg.lang .. " | Optimizer: " .. tostring(OPT.enabled) .. " | QuietSell: " .. tostring(QUIET.enabled))
