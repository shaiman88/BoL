if myHero.charName ~= "Leona" then return end

require 'VPrediction'
require 'SOW'


local version = "2.5"
local qready, wready, eready, rready
local targetUlted = false
local targetRooted = false
local ascslot, ascready, lckslot, lckready
local myHitBox = 0


function OnLoad()
	JBConfig = scriptConfig("Leona (Bitch) - "..version.."", "leonaconfig") 

	JBConfig:addSubMenu("Combo Settings", "combosettings")
	JBConfig:addSubMenu("Auto Ult", "autoult")
	JBConfig:addSubMenu("Draw Settings", "drawsettings")
	JBConfig:addSubMenu("Orbwalker", "orbwalker")
	JBConfig:addSubMenu("Miscellaneous", "misc")

	JBConfig.drawsettings:addParam("enabledraw", "Draw Circle Ranges", SCRIPT_PARAM_ONOFF, true)
	JBConfig.drawsettings:addParam("w", "Draw W", SCRIPT_PARAM_ONOFF, true)
	JBConfig.drawsettings:addParam("e", "Draw E", SCRIPT_PARAM_ONOFF, true)
	JBConfig.drawsettings:addParam("r", "Draw R", SCRIPT_PARAM_ONOFF, true)
	JBConfig.drawsettings:addParam("tstarget", "Draw Circle around target", SCRIPT_PARAM_ONOFF, true)

	JBConfig.combosettings:addParam("comboActive", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
	JBConfig.combosettings:addParam("useUlt", "Use Ult", SCRIPT_PARAM_ONOFF, true)
	JBConfig.combosettings:permaShow("comboActive")

	JBConfig.autoult:addParam("enabled", "Enable", SCRIPT_PARAM_ONOFF, true)
	JBConfig.autoult:addParam("numberofenemies", "least # of enemies to auto ult", SCRIPT_PARAM_SLICE, 3, 1, 5, 0)

	JBConfig.misc:addParam("div", "High hitchance = less casting", SCRIPT_PARAM_INFO, "")
	JBConfig.misc:addParam("hitchance", "E Hitchance", SCRIPT_PARAM_LIST, 1, { "Low Hitchance", "High Hitchance", "Target too slowed/too close", "Target inmmobile", "Target dashing or blinking"})
	JBConfig.misc:addParam("q", "Use Q", SCRIPT_PARAM_LIST, 4, { "Before AA", "After AA", "After windup of last AA", "OnProcessSpell"})

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY,1200,DAMAGE_MAGIC)
	ts.name = "Leona"
	ts.targetSelected = true
	JBConfig.combosettings:addTS(ts)
	VP = VPrediction()
	lSOW = SOW(VP)
	lSOW:LoadToMenu(JBConfig.orbwalker)
	lSOW:EnableAttacks()

	myHitBox = VP:GetHitBox(myHero)


	DelayAction(function() print("<font color='#E38400'>Leona</font><font color='#FFFFFF'> the Annoying <font color='#E38400'>Bitch</font><font color='#FFFFFF'> loaded!</font>") end, 1)
end


function OnTick()
	ts:update()
	qready = (myHero:CanUseSpell(_Q) == READY)
	wready = (myHero:CanUseSpell(_W) == READY)
	eready = (myHero:CanUseSpell(_E) == READY)
	rready = (myHero:CanUseSpell(_R) == READY)

	if rready and eready then 
		ts.range = 1200 
		ts:update()
	elseif eready then
		ts.range = 875 
		ts:update()
	else
		ts.range = 300--myHero.range + myHitBox
		ts:update()
	end

	if ts.target ~= nil then lSOW:ForceTarget(ts.target) end

	ascslot = GetInventorySlotItem(3069)
	ascready = (ascslot ~= nil and myHero:CanUseSpell(ascslot) == READY)
	lckslot = GetInventorySlotItem(3190)
	lckready = (lckslot ~= nil and myHero:CanUseSpell(lckslot) == READY)

	if JBConfig.misc.q == 1 then
		if not lSOW.BeforeAttackCallbacks[CastQ] then
			lSOW:RegisterBeforeAttackCallback(CastQ)
			if lSOW.OnAttackCallbacks[CastQ] then lSOW.OnAttackCallbacks[CastQ] = nil end
			if lSOW.AfterAttackCallbacks[CastQ] then lSOW.AfterAttackCallbacks[CastQ] = nil end
		end
	elseif JBConfig.misc.q == 2 then
		if not lSOW.OnAttackCallbacks[CastQ] then
			lSOW:RegisterOnAttackCallback(CastQ)
			if lSOW.BeforeAttackCallbacks[CastQ] then lSOW.BeforeAttackCallbacks[CastQ] = nil end
			if lSOW.AfterAttackCallbacks[CastQ] then lSOW.AfterAttackCallbacks[CastQ] = nil end
		end
	elseif JBConfig.misc.q == 3 then
		if not lSOW.AfterAttackCallbacks[CastQ] then
			lSOW:RegisterAfterAttackCallback(CastQ)
			if lSOW.BeforeAttackCallbacks[CastQ] then lSOW.BeforeAttackCallbacks[CastQ] = nil end
			if lSOW.OnAttackCallbacks[CastQ] then lSOW.OnAttackCallbacks[CastQ] = nil end
		end
	elseif JBConfig.misc.q == 4 then
		if lSOW.BeforeAttackCallbacks[CastQ] then lSOW.BeforeAttackCallbacks[CastQ] = nil end
		if lSOW.OnAttackCallbacks[CastQ] then lSOW.OnAttackCallbacks[CastQ] = nil end
		if lSOW.AfterAttackCallbacks[CastQ] then lSOW.AfterAttackCallbacks[CastQ] = nil end
	end

	Combo()
	AutoStun() 
end

--http://botoflegends.com/forum/topic/19669-for-devs-isfacing/
function isFacing(source, target, lineLength)
	if not source.dead and source.visionPos ~= nil and not target.dead and target.visionPos ~= nil then
		local sourceVector = Vector(source.visionPos.x, source.visionPos.z)
		local sourcePos = Vector(source.x, source.z)
		sourceVector = (sourceVector-sourcePos):normalized()
		sourceVector = sourcePos + (sourceVector*(GetDistance(target, source)))
		return GetDistanceSqr(target, {x = sourceVector.x, z = sourceVector.y}) <= (lineLength and lineLength^2 or 90000)
	end
end

function CastQ() --for SOW
	if JBConfig.misc.q == 1 or JBConfig.misc.q == 2 then
		if ts.target ~= nil and ValidTarget(ts.target, 200) and ts.target.type == myHero.type then
			if qready and not (VP.TargetsImmobile[ts.target.networkID] and VP.TargetsImmobile[ts.target.networkID] > os.clock() + .25 + JBConfig.orbwalker.ExtraWindUpTime) then 
				CastSpell(_Q)
			end
		end
	elseif JBConfig.misc.q == 3 then
		if ts.target ~= nil and ValidTarget(ts.target, 200) and ts.target.type == myHero.type then
			if qready and not (VP.TargetsImmobile[ts.target.networkID] and VP.TargetsImmobile[ts.target.networkID] > os.clock() + GetLatency()/2000) then 
				CastSpell(_Q)
			end
		end
	end
end
	
function Combo()
	if ts.target ~= nil and JBConfig.combosettings.comboActive and ts.target.type == myHero.type then
		if ValidTarget(ts.target, 450) and wready and (targetRooted or not ts.target.canMove) then
			CastSpell(_W)
		end
		if myHero.visionPos ~= nil and ts.target.visionPos ~= nil and eready and not (not isFacing(ts.target, myHero, 400) and GetDistanceSqr(myHero.visionPos, ts.target.visionPos) >= 608400) then
			CastPosition, HitChance, Position = VP:GetLineCastPosition(ts.target, .25, 80, 875, 1225, myHero, false)
			if CastPosition ~= nil and HitChance >= JBConfig.misc.hitchance then 
				if ascready then CastSpell(ascslot) end
				if lckready then CastSpell(lckslot) end
				CastSpell(_E, CastPosition.x, CastPosition.z) 
			end
		end
		if rready and ValidTarget(ts.target, 1125) and (VP.TargetsImmobile[ts.target.networkID] and VP.TargetsImmobile[ts.target.networkID] > os.clock() + .75) and JBConfig.combosettings.useUlt then
			CastSpell(_R, ts.target.visionPos.x, ts.target.visionPos.z)
		end
	end
end

function AutoStun()
	if JBConfig.autoult.enabled and rready and eready and not JBConfig.combosettings.comboActive and ts.target ~= nil then --avoid bugsplat so Combo does not conflict
		spellPos, HitChance, nTargets = VP:GetCircularAOECastPosition(ts.target, .25, 300, 1200, 20)
		if (spellpos ~= nil and nTargets) and (nTargets >= JBConfig.autoult.numberofenemies) then
			CastSpell(_R, spellPos.x, spellPos.z)
		end
	end
end

local notAA = {
	['shyvanadoubleattackdragon'] = true,
	['shyvanadoubleattack'] = true,
	['monkeykingdoubleattack'] = true,
}


function OnProcessSpell(unit, spell)
	--if unit.isMe then print("Unit: "..unit.charName.. " , Spell: "..spell.name.." , Delay: "..spell.windUpTime.." , Animation Time: "..spell.animationTime) end
	if unit.team ~= myHero.team and unit.type == myHero.type and (not notAA[string.lower(spell.name)]) and spell.target == myHero and eready and not string.find(string.lower(unit.charName), "minion") then
		if wready then CastSpell(_W) end
	end

	if unit.isMe and string.find(string.lower(spell.name), "attack") and ts.target ~= nil then
		if qready and JBConfig.misc.q == 4 and spell.target.type == myHero.type and not (VP.TargetsImmobile[ts.target.networkID] and VP.TargetsImmobile[ts.target.networkID] > os.clock() + .237) then CastSpell(_Q) end
	end
end


function CastR(target)
	if target ~= nil and eready and rready then
		spellPos, HitChance, nTargets = VP:GetCircularAOECastPosition(target, .25, 300, 1200, 20)
		if spellPos ~= nil and HitChance >= 2 and JBConfig.combosettings.useUlt then
	        CastSpell(_R, spellPos.x, spellPos.z)
	    end
	end
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

function OnDraw()
	if JBConfig.drawsettings.enabledraw then
		if JBConfig.drawsettings.w then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 450, ARGB(255,36,0,255))
		end
		if JBConfig.drawsettings.e then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 875, ARGB(255,36,0,255))
		end
		if JBConfig.drawsettings.r then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 1200, ARGB(255,36,0,255))
		end
		if JBConfig.drawsettings.tstarget and ts.target ~= nil then
			DrawCircle2(ts.target.x, ts.target.y, ts.target.z, 70, ARGB(255, 255, 0, 0))
		end
		--[[
		if ts.target ~= nil then
			local textToDraw 
			if (VP.TargetsImmobile[ts.target.networkID] and VP.TargetsImmobile[ts.target.networkID] >= os.clock()) then textToDraw = "Immobile" else textToDraw = "Not Immobile" end
			DrawText(textToDraw, 50, 100, 100, ARGB(100,30,184,22))
		end
		]]
	end
end


function OnGainBuff(unit, buff)
	if unit == ts.target and buff.name == "leonasolarflareslow" then
		targetUlted = true
	end
	if unit == ts.target and buff.name == "leonazenithbladeroot" then
		targetRooted = true
		if wready then CastSpell(_W) end
	end
end

function OnLoseBuff(unit, buff)
	if unit == ts.target and buff.name == "leonasolarflareslow" then
		targetUlted = false
	end
	if unit == ts.target and buff.name == "leonazenithbladeroot" then
		targetRooted = false
	end
end
