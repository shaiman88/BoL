--[[ Chancey's Script Updater
--UPDATEURL=
--HASH=54D5D2BC8913BB9BF38973CB5D55EBCA
--UPDATE=False
Don't remove any of these lines or script may become corrupted]]
if myHero.charName ~= "Janna" then return end

require 'VPrediction'

local version = "1.5"
local qready, wready, eready, rready
local qready2 = false
local VP = nil
local blockAA = false
local ADC, lowGuy
local sq = false
local exhaust, exhaustready
local checkVersion = true
local VPVersion
local isUlting = false
local ultTime -- check just in case

function OnLoad()
	JAConfig = scriptConfig("Janna Almighty - "..version.."", "jannaconfig")

	JAConfig:addSubMenu("Combo Settings", "combosettings")
	JAConfig:addSubMenu("Draw Settings", "drawsettings")

	JAConfig.drawsettings:addParam("enabledraw", "Draw Circle Ranges", SCRIPT_PARAM_ONOFF, true)
	JAConfig.drawsettings:addParam("q", "Draw Q", SCRIPT_PARAM_ONOFF, true)
	JAConfig.drawsettings:addParam("w", "Draw W", SCRIPT_PARAM_ONOFF, true)
	JAConfig.drawsettings:addParam("e", "Draw E", SCRIPT_PARAM_ONOFF, true)

	JAConfig.combosettings:addParam("comboActive", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
	JAConfig.combosettings:addParam("movetomouse", "Move to mouse", SCRIPT_PARAM_ONOFF, true)
	JAConfig.combosettings:permaShow("comboActive")

	JAConfig:addParam("sac", "Using SAC/MMA", SCRIPT_PARAM_ONOFF, true)
	JAConfig:addParam("autoshield", "Auto Shield", SCRIPT_PARAM_ONOFF, true)
	JAConfig:addParam("autoq", "Auto Q Ults & Other shit", SCRIPT_PARAM_ONOFF, true)

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY,1100,DAMAGE_MAGIC)
	ts.name = "Janna"
	ts.targetSelected = true
	JAConfig.combosettings:addTS(ts)
	
	VP = VPrediction()

	if myHero:GetSpellData(SUMMONER_1).name:find("SummonerExhaust") then exhaust = SUMMONER_1
	elseif myHero:GetSpellData(SUMMONER_2).name:find("SummonerExhaust") then exhaust = SUMMONER_2 end

	print("<font color='#EDD84C'>Janna</font><font color='#FFFFFF'> Almighty loaded!</font>")
end


function OnTick()
	ts:update()
	qready = (myHero:CanUseSpell(_Q) == READY) and not qready2
	wready = (myHero:CanUseSpell(_W) == READY)
	eready = (myHero:CanUseSpell(_E) == READY)
	rready = (myHero:CanUseSpell(_R) == READY)
	exhaustready = (exhaust ~= nil and myHero:CanUseSpell(exhaust) == READY)


	if checkVersion then
		if VP.version ~= nil then
			VPVersion = VP.version
			VPVersion = string.gsub(VPVersion, "Version: ", "")
			VPVersion = tonumber(VPVersion)
			if VPVersion < 2.401 then
				print("<font color='#EDD84C'>Janna Almighty: You need to update VPrediction to the latest version!</font><")
				print("<font color='#EDD84C'>Janna Almighty: You need to update VPrediction to the latest version!</font><")
				print("<font color='#EDD84C'>Janna Almighty: You need to update VPrediction to the latest version!</font><")
			end
			checkVersion = false
		end
	end

	if not qready and not wready then blockAA = false else blockAA = true end


	if sq and (myHero:CanUseSpell(_Q) == READY) and not isUlting then
		--CastSpell(_Q)
		Packet("S_CAST", {spellId = _Q, toX = myHero.x, toY = myHero.z, fromX = myHero.x, fromY = myHero.z, targetNetworkId = myHero.networkID}):send()
		sq = false
	end

	if myHero:GetSpellData(_Q).currentCd ~= 0 then qready2 = false end

	if ultTime ~= nil then
		if os.clock() > ultTime + 3.1 then
			ultTime = nil
			isUlting = false
		end
	end

	if isUlting and _G.AutoCarry and _G.AutoCarry.MyHero then
		_G.AutoCarry.MyHero:AttacksEnabled(false)
		_G.AutoCarry.MyHero:MovementEnabled(false)
	else 
		_G.AutoCarry.MyHero:AttacksEnabled(true) 
		_G.AutoCarry.MyHero:MovementEnabled(true)
	end

	Combo()
	AutoShield()
end

function Combo()
	if not JAConfig.sac and JAConfig.combosettings.movetomouse and not isUlting and JAConfig.combosettings.comboActive then
		myHero:MoveTo(mousePos.x, mousePos.z)
	end
	if ts.target ~= nil and JAConfig.combosettings.comboActive and ValidTarget(ts.target) and not isUlting then
		if wready and ValidTarget(ts.target, 600) then
			CastSpellP(_W, ts.target)
		end
		if qready then 
			--                                                           (unit, delay, radius, range, speed, from)
			CastPosition, HitChance, Position = VP:GetLineAOECastPosition(ts.target, 1.5, 200, 1100)
			if CastPosition ~= nil then CastSpell(_Q, CastPosition.x, CastPosition.z) end
		end 
		if qready2 then
			CastSpell(_Q)
		end
	end
end

local mostDamage = 0
local lowestHealth = math.huge
function AutoShield()
	if JAConfig.autoshield and JAConfig.combosettings.comboActive and eready and not isUlting then
		--Find really low health guy
		for i=1, heroManager.iCount do
			local ally = heroManager:getHero(i)
			if ally.health < lowestHealth and ally.team ~= TEAM_ENEMY and GetDistance(myHero, ally) < 800 and eready then
				lowGuy = ally
				lowestHealth = ally.health
			end
		end
		if eready and lowGuy ~= nil and GetDistance(myHero, ally) < 800 and lowGuy ~= myHero and lowGuy.maxHealth * .16 >= lowGuy.health then 
			CastSpellP(_E, lowGuy) 
		end

		--Omg is the low health person me?
		if myHero.maxHealth * .05 >= myHero.health and eready then
			CastSpellP(_E, myHero)
		end

		--Find ADC
		for i=1, heroManager.iCount do
			local ally = heroManager:getHero(i)
			if ally.totalDamage > mostDamage and ally.team ~= TEAM_ENEMY and GetDistance(myHero, ally) < 800 and eready then
				ADC = ally
				mostDamage = ally.totalDamage
			end
		end
		if eready and ADC ~= nil and GetDistance(myHero, ally) < 800 and ADC ~= myHero then 
			CastSpellP(_E, ADC) 
		end
	end
end

function CastSpellP(spell, target)
	if target ~= nil then 
		if spell == _E and GetDistance(myHero, target) < 800 and not myHero.dead then
			Packet("S_CAST", {spellId = spell, targetNetworkId = target.networkID}):send() 
		elseif spell ~= _E then
			Packet("S_CAST", {spellId = spell, targetNetworkId = target.networkID}):send() 
		else
		end
	end
end

function OnDraw()
	if JAConfig.drawsettings.enabledraw then
		if JAConfig.drawsettings.q then
			DrawCircle(myHero.x, myHero.y, myHero.z, 1100, ARGB(255,36,0,255))
		end
		if JAConfig.drawsettings.w then
			DrawCircle(myHero.x, myHero.y, myHero.z, 600, ARGB(255,36,0,255))
		end
		if JAConfig.drawsettings.e then
			DrawCircle(myHero.x, myHero.y, myHero.z, 800, ARGB(255,36,0,255))
		end
	end
end


function OnProcessSpell(unit, spellProc)
	--print("Spell: "..spellProc.name.." , "..unit.charName)
	--if spellProc.target ~= nil then print("Target: "..spellProc.target.charName) end
	if JAConfig.autoq and (spellProc.name == "MissFortuneBulletTime" or spellProc.name == "KatarinaR" or spellProc.name == "AbsoluteZero" or spellProc.name == "AlZaharNetherGrasp" or spellProc.name == "RocketJump" or spellProc.name == "KhazixE" or spellProc.name == "khazixelong" or spellProc.name == "LeonaZenithBlade") and unit.team ~= myHero.team and qready then
		if GetDistance(myHero, unit) < 1100 and myHero.canMove then
			if qready then 
				CastPosition, HitChance, Position = VP:GetLineAOECastPosition(unit, 1.5, 200, 1100)
				if CastPosition ~= nil then 
					CastSpell(_Q, CastPosition.x, CastPosition.z)
					sq = true
				end
			elseif not qready and exhaustready and not spellProc.name ~= "LeonaZenithBlade" and not spellProc.name == "RocketJump" then
				CastSpell(exhaust, unit)
			end
		end
	elseif (spellProc.name == "infiniteduresschannel" or spellProc.name == "KatarinaR" or spellProc.name == "AlZaharNetherGrasp" or spellProc.name == "LeonaZenithBlade") and unit.team ~= myHero.team and eready then
		if ValidTarget(unit, 800) and myHero.canMove then
			if eready and spellProc.target ~= nil then
				if GetDistance(myHero, spellProc.target) < 800 then
					CastSpellP(_E, spellProc.target)
				end
			end
		end
	end
	if unit.isMe and spellProc.name == "ReapTheWhirlwind" then
		isUlting = true
		ultTime = os.clock()
	end
end

function OnCreateObj(object)
	--if not string.find(object.name, "Odin") then print(object.name) end

end

function OnGainBuff(unit, buff)
	if unit.isMe and buff.name == "HowlingGale" then
		qready2 = true
	end
	if unit.isMe and buff.name == "ReapTheWhirlwind" then
		isUlting = true
	end
	if unit.team ~= myHero.team and (buff.name == "valkyriesound") and qready and JAConfig.autoq then
		CastPosition, HitChance, Position = VP:GetLineAOECastPosition(unit, 1.5, 200, 1100)
		if CastPosition ~= nil then 
			CastSpell(_Q, CastPosition.x, CastPosition.z)
			sq = true
		end
	end
	if unit.team == myHero.team and buff.name == "leonazenithbladeroot" and GetDistance(myHero, unit) < 800 and eready then
		CastSpellP(_E, unit.target)
	end
	--print("Buff: "..buff.name.." , "..unit.charName)
end

function OnLoseBuff(unit, buff)
	if unit.isMe and buff.name == "HowlingGale" then
		qready2 = false
	end
	if unit.isMe and buff.name == "ReapTheWhirlwind" then
		isUlting = false
	end
	--print("Lost Buff: "..buff.name.." , "..unit.charName)
end
