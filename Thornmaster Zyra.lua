if myHero.charName ~= "Zyra" then return end

require 'VPrediction'
require 'SOW'
--require 'Prodiction'

local version = "1.2"
local qready, wready, eready, rready
local dfgslot, bftslot, fqcslot = nil, nil, nil
local dfgready, bftready, fqcready = false, false , false
local seedCount
local lastE, eWindUp, eAnimation
local lastQ, qWindUp, qAnimation, qObject
local rObject
local sPos = {}
local ePos = {}
local seeds = {}
local eSeqCount = 0
local eqLine, eqCircle
local rPos
local passiveMode = false


function OnLoad()
	ZConfig = scriptConfig("Zyra - "..version.."", "zyraconfig")
	ZConfig:addSubMenu("Combo Settings", "combosettings")
	ZConfig:addSubMenu("Ult Settings", "ultsettings")
	ZConfig:addSubMenu("Orbwalker", "orbwalker")
	ZConfig:addSubMenu("Draw Settings", "drawsettings")

	ZConfig:addParam("forcecombo", "Force Combo", SCRIPT_PARAM_ONKEYTOGGLE, false, GetKey("J"))
	ZConfig:addParam("info", "^Don't check if target too far", SCRIPT_PARAM_INFO, "")

	ZConfig.ultsettings:addParam("key", "Auto ult key", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("N"))
	ZConfig.ultsettings:addParam("toggled", "Toggle (don't need key)", SCRIPT_PARAM_ONOFF, false)
	ZConfig.ultsettings:addParam("autoUltvalue", "least # of enemies to auto ult", SCRIPT_PARAM_SLICE, 2, 1, 5, 0)

	ZConfig.drawsettings:addParam("enabledraw", "Draw Circle Ranges", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("div", "-------------------------------------------------", SCRIPT_PARAM_INFO, "")
	ZConfig.drawsettings:addParam("aa", "Draw AA", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("aaColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("q", "Draw Q", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("qColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("w", "Draw W", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("wColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("e", "Draw E", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("eColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("r", "Draw R Spot", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("rColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("passive", "Draw Passive Range (when dead)", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("passiveColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("target", "Draw target", SCRIPT_PARAM_ONOFF, true)
	ZConfig.drawsettings:addParam("targetColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})
	ZConfig.drawsettings:addParam("seeds", "Draw seeds", SCRIPT_PARAM_ONOFF, false)
	ZConfig.drawsettings:addParam("seedsColor", "Color:", SCRIPT_PARAM_COLOR, {100,30,184,22})

	ZConfig.combosettings:addParam("comboActive", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
	ZConfig.combosettings:addParam("movetomouse", "Move to mouse", SCRIPT_PARAM_ONOFF, true)

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY,1150,DAMAGE_MAGIC)
	ts.name = "Zyra"
	ts.targetSelected = true
	ZConfig.combosettings:addTS(ts)
	VP = VPrediction()
	--Prod = ProdictManager.GetInstance()
	--ProdQ = Prod:AddProdictionObject(_Q, 800, 1400, .25, 440)
	zSOW = SOW(VP)
	zSOW:LoadToMenu(ZConfig.orbwalker)
	zSOW:EnableAttacks()
	DelayAction(function() print("<font color='#1FCF00'>Zyra</font> <font color='#FFFFFF'>loaded.</font>") end, 1)
end


function DrawCircleNextLvl(x, y, z, radius, width, color, chordlength)
	radius = radius or 300
	quality = math.max(8,math.floor(180/math.deg((math.asin((chordlength/(2*radius)))))))
	quality = 2 * math.pi / quality
	radius = radius*.92
	local points = {}
	for theta = 0, 2 * math.pi + quality, quality do
		local c = WorldToScreen(D3DXVECTOR3(x + radius * math.cos(theta), y, z - radius * math.sin(theta)))
		points[#points + 1] = D3DXVECTOR2(c.x, c.y)
	end
	DrawLines2(points, width or 1, color or 4294967295)
end

function DrawCircle2(x, y, z, radius, color)
	local vPos1 = Vector(x, y, z)
	local vPos2 = Vector(cameraPos.x, cameraPos.y, cameraPos.z)
	local tPos = vPos1 - (vPos1 - vPos2):normalized() * radius
	local sPos = WorldToScreen(D3DXVECTOR3(tPos.x, tPos.y, tPos.z))
	if OnScreen({ x = sPos.x, y = sPos.y }, { x = sPos.x, y = sPos.y })  then
		DrawCircleNextLvl(x, y, z, radius, 1, color, 75)	
	end
end

--http://botoflegends.com/forum/topic/19669-for-devs-isfacing/
function isFacing(source, target, lineLength)
	if source.visionPos ~= nil then
		local sourceVector = Vector(source.visionPos.x, source.visionPos.z)
		local sourcePos = Vector(source.x, source.z)
		sourceVector = (sourceVector-sourcePos):normalized()
		sourceVector = sourcePos + (sourceVector*(GetDistance(target, source)))
		return GetDistanceSqr(target, {x = sourceVector.x, z = sourceVector.y}) <= (lineLength and lineLength^2 or 90000)
	end
end

function OnDraw()
	if ZConfig.drawsettings.enabledraw then
		--[[
		if ts.target ~= nil then
			local texttoDraw = tostring(GetDistance(ts.target.visionPos, myHero.visionPos))
			local texttoDraw2 = tostring(GetDistanceSqr(ts.target.visionPos, myHero.visionPos))
			DrawText("Distance: "..texttoDraw, 20, 100, 100, ARGB(255,30,184,22))
			DrawText("Distance Sqr: "..texttoDraw2, 20, 100, 120, ARGB(255,30,184,22))
		end
		]]
		if ZConfig.drawsettings.aa then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 610, ARGB(ZConfig.drawsettings.aaColor[1], ZConfig.drawsettings.aaColor[2], ZConfig.drawsettings.aaColor[3], ZConfig.drawsettings.aaColor[4]))
		end
		if ZConfig.drawsettings.q then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 800, ARGB(ZConfig.drawsettings.qColor[1], ZConfig.drawsettings.qColor[2], ZConfig.drawsettings.qColor[3], ZConfig.drawsettings.qColor[4]))
		end
		if ZConfig.drawsettings.w then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 850, ARGB(ZConfig.drawsettings.wColor[1], ZConfig.drawsettings.wColor[2], ZConfig.drawsettings.wColor[3], ZConfig.drawsettings.wColor[4]))
		end
		if ZConfig.drawsettings.e then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 1150, ARGB(ZConfig.drawsettings.eColor[1], ZConfig.drawsettings.eColor[2], ZConfig.drawsettings.eColor[3], ZConfig.drawsettings.eColor[4]))
		end
		if ZConfig.drawsettings.target and ts.target ~= nil then
			DrawCircle2(ts.target.x, ts.target.y, ts.target.z, 100, ARGB(ZConfig.drawsettings.targetColor[1], ZConfig.drawsettings.targetColor[2], ZConfig.drawsettings.targetColor[3], ZConfig.drawsettings.targetColor[4]))
		end
		if rPos ~= nil and ZConfig.drawsettings.r then
			DrawCircle2(rPos.x, myHero.y, rPos.z, 500, ARGB(ZConfig.drawsettings.rColor[1], ZConfig.drawsettings.rColor[2], ZConfig.drawsettings.rColor[3], ZConfig.drawsettings.rColor[4]))
		end
		if passiveMode and ZConfig.drawsettings.passive then 
			DrawCircle2(myHero.x, myHero.y, myHero.z, 1473, ARGB(ZConfig.drawsettings.passiveColor[1], ZConfig.drawsettings.passiveColor[2], ZConfig.drawsettings.passiveColor[3], ZConfig.drawsettings.passiveColor[4]))
		end

		if ZConfig.drawsettings.seeds then
			for seed, object in pairs(seeds) do
				if object ~= nil then
					DrawCircle2(object.x, object.y, object.z, 200, ARGB(100,30,184,22))
				end
			end
		end
	end
end

function OnTick()
	ts:update()
	zSOW:EnableAttacks()
	if ts.target ~= nil then zSOW:ForceTarget(ts.target) end
	qready = (myHero:CanUseSpell(_Q) == READY)
	wready = (myHero:CanUseSpell(_W) == READY)
	eready = (myHero:CanUseSpell(_E) == READY)
	rready = (myHero:CanUseSpell(_R) == READY)
	dfgslot = GetInventorySlotItem(3128)
	dfgready = (dfgslot ~= nil and myHero:CanUseSpell(dfgslot) == READY)
	bftslot = GetInventorySlotItem(3188)
	bftready = (bftslot ~= nil and myHero:CanUseSpell(bftslot) == READY)
	fqcslot = GetInventorySlotItem(3092)
	fqcready = (fqcslot ~= nil and myHero:CanUseSpell(fqcslot) == READY)

	for seed, object in pairs(seeds) do
		if (object == nil) or (not object.valid) or (not object.visible) or (not object.bTargetable) or object.dead then
			seed = nil
		elseif object.maxHealth == 6 then
			seeds[seed].isUpgraded = true
			if object.attackSpeed == 1.5 then seeds[seed].isUlted = true end
		end
	end

	if myHero.health == 0 and not myHero.dead then passiveMode = true else passiveMode = false end

	if passiveMode then
		zSOW:DisableAttacks()
		ts.mode = TARGET_LOW_HP_PRIORITY
		ts.range = 1473
		ts:update()
	else
		zSOW:EnableAttacks()
		ts.mode = TARGET_LESS_CAST_PRIORITY
		ts.range = 1150
		ts:update()
	end

	if eAnimation ~= nil and ePos ~= nil and ts.target ~= nil then
		if os.clock() < eAnimation and wready then -- +.3
			zSOW:DisableAttacks()
			local directionVector = (Vector(ePos)-Vector(myHero.visionPos)):normalized()
			local castVector
			if GetDistanceSqr(sPos, ts.target.visionPos) > 722500 then
				castVector = Vector(sPos) + (directionVector * 850)
			else
				castVector = Vector(sPos) + (directionVector * GetDistance(sPos, ts.target.visionPos))
			end
			
			CastSpell(_W, castVector.x, castVector.z)
			if fqcready then CastSpell(fqcslot, ts.target) end
			zSOW:EnableAttacks()
		elseif os.clock() > eAnimation then
			ePos = {}
			sPos = {}
			lastE = nil
			eWindUp = nil
			eAnimation = nil
		end
	end
	if qObject ~= nil and wready and ts.target ~= nil and not (eAnimation ~= nil and ePos ~= nil and ts.target ~= nil) then
		CastSpell(_W, qObject.x, qObject.z)
		if fqcready then CastSpell(fqcslot, ts.target) end
	end

	if rready and ts.target ~= nil then 
		local hitChance, numEnemies
		rPos, hitChance, numEnemies = VP:GetCircularAOECastPosition(ts.target, .50, 500, 700, 20, myHero) 
		if ZConfig.ultsettings.key or ZConfig.ultsettings.toggled then
			if numEnemies >= ZConfig.ultsettings.autoUltvalue then
				CastSpell(_R, rPos.x, rPos.z)
			end
		end
	else
		rPos = nil
	end

	Combo()
end


function Combo()
	if zSOW:CanMove() and ZConfig.combosettings.comboActive then myHero:MoveTo(mousePos.x, mousePos.z) end
	if ts.target ~= nil and ZConfig.combosettings.comboActive and not passiveMode then
		local ewasready = eready
		if eready and qready and (dfgready or bftready) then if dfgready then CastSpell(dfgslot, ts.target) else CastSpell(bftslot, ts.target) end end
		if eready and not isFacing(ts.target, myHero, 400) and GetDistanceSqr(myHero.visionPos, ts.target.visionPos) >= 965952 and not ZConfig.forcecombo and ts.target.canMove and not VP:isSlowed(ts.target, .25, 1150, myHero) then
		else
			if qready and eready then DelayAction(CastQ, .25 + ((GetDistance(ts.target)/(1150)))) end
			if eready then
				CastE(ts.target)
			end
		end
		if not ewasready then CastQ(ts.target) end
	elseif ts.target ~= nil and ZConfig.combosettings.comboActive and passiveMode then
		PassiveCast(ts.target)
	end
end

function PassiveCast(target)
	if passiveMode then                                            --(unit, delay, radius, range, speed, from)
		CastPosition, HitChance, Position = VP:GetLineAOECastPosition(target, .5, 70, 1473, 1200, myHero)
		CastSpell(_Q, CastPosition.x, CastPosition.z)
	end
end
function CastQ(target)
	if not target and ts.target ~= nil then target = ts.target end
	if not target then return end
	local enemyCount = 0
	local points = {}
	for i=1, heroManager.iCount do
		local enemy = heroManager:getHero(i)
		if enemy.team == TEAM_ENEMY and ValidTarget(enemy, 800) then
			enemyCount = enemyCount + 1
		end
	end
	if enemyCount == 1 then
		CastPosition, HitChance, Position = VP:GetCircularCastPosition(target, .25, 220, 800, 1400, myHero)
		table.insert(points, Position)
		for seed, object in pairs(seeds) do
			if object ~= nil and GetDistanceSqr(ts.target.visionPos, object) <= 193600 and not object.isUpgraded then table.insert(points, seeds[seed]) end
		end

		local mec = MEC(points)
		local finalCastPos = mec:Compute()
		if finalCastPos ~= nil then
			CastSpell(_Q, finalCastPos.center.x, finalCastPos.center.z)
		end
	end

	CastPosition, HitChance, Position = VP:GetCircularAOECastPosition(target, .25, 220, 800, 1400, myHero)
	CastSpell(_Q, CastPosition.x, CastPosition.z)
end

function CastE(target)                                      --(unit, delay, radius, range, speed, from)
	CastPosition, HitChance, Position = VP:GetLineAOECastPosition(target, .25, 70, 1150, 1150, myHero, false)
	if HitChance >= 2 then
		CastSpell(_E, CastPosition.x, CastPosition.z)
	end
end
                                                                   --unit, delay, radius, range, speed, from, collision)
function CastR(target)
	CastPosition, HitChance, Position = VP:GetCircularAOECastPosition(target, .50, 500, 700, 20, myHero)
	CastSpell(_R, CastPosition.x, CastPosition.z)
end


function OnCreateObj(object)
	--if not string.find(object.name, "Odin") then print(object.name) end
	if string.find(string.lower(object.name), "zyra_qfissure") and GetDistanceSqr(myHero.visionPos, object) < 1000000 then 
		qObject = object
	end
	if string.find(string.lower(object.name), "zyra_ult_cas") then 
		rObject = object
	end
	if object.name == "Seed" and GetDistanceSqr(myHero.visionPos, object) <= 722500 and object.team ~= TEAM_ENEMY then
		seeds[#seeds+1] = object
	end
end


function OnDeleteObj(object)
	if object == qObject then qObject = nil end
	if object == rObject then rObject = nil end
end


function OnProcessSpell(unit, spell)
	--print("Unit: "..unit.charName.. " , Spell: "..spell.name.." , Delay: "..spell.windUpTime.." , Animation Time: "..spell.animationTime)
	if unit.isMe and spell.name == "ZyraGraspingRoots" then
		lastE = os.clock()
		eWindUp = os.clock() + spell.windUpTime
		eAnimation = os.clock() + spell.animationTime
		sPos.x, sPos.y, sPos.z = spell.startPos.x, spell.startPos.y, spell.startPos.z
		ePos.x, ePos.y, ePos.z = spell.endPos.x, spell.endPos.y, spell.endPos.z
	end
	if unit.isMe and spell.name == "ZryaQFissure" then
		lastQ = os.clock()
		qWindUp = os.clock() + spell.windUpTime
		qAnimation = os.clock() + spell.animationTime
	end
end