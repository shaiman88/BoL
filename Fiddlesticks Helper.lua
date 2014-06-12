if myHero.charName ~= "FiddleSticks" then return end

require 'SourceLib'

local version = '2.1'
local QRange = 600 -- (actually 575)
local WRange = 570 -- (actually 575)
local ERange = 775 -- (actually 750)
local EBounceRange = 445 -- (actually 450)
local qready, wready, eready
local isRecalling = false
local ultActive = false
local Draining = false
local edamage
local BlockMovement = false



function OnLoad()
	PrintChat("Feez's Fiddlesticks Helper [VIP]")
	
	-- Menu--
	FHConfig = scriptConfig("Fiddlesticks Helper [VIP]", "fidhelper")

	FHConfig:addSubMenu("Combo Settings", "combosettings")
	FHConfig:addSubMenu("Harass Settings", "harasssettings")
	FHConfig:addSubMenu("Draw Settings", "drawsettings")
	FHConfig:addSubMenu("Item Settings", "itemsettings")
	FHConfig:addSubMenu("KS Settings", "kssettings")

	FHConfig.drawsettings:addParam("enabledraw", "Enable Draw", SCRIPT_PARAM_ONOFF, true)
	FHConfig.drawsettings:addParam("qdraw", "Draw Q Range", SCRIPT_PARAM_ONOFF, true)
	FHConfig.drawsettings:addParam("wdraw", "Draw W Range", SCRIPT_PARAM_ONOFF, true)
	FHConfig.drawsettings:addParam("edraw", "Draw E Range", SCRIPT_PARAM_ONOFF, true)
	FHConfig.drawsettings:addParam("rdraw", "Draw R Range", SCRIPT_PARAM_ONOFF, true)

	FHConfig.combosettings:addParam("comboActive", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)

	FHConfig.harasssettings:addParam("harassActive", "Harass", SCRIPT_PARAM_ONKEYDOWN, false, GetKey("T"))
	FHConfig.harasssettings:addParam("movetomouse", "Move to mouse", SCRIPT_PARAM_ONOFF, true)

	FHConfig.itemsettings:addParam("dfg", "Use DFG/BFT on ult", SCRIPT_PARAM_ONOFF, false)

	FHConfig.kssettings:addParam("autoKS", "Auto KS with E", SCRIPT_PARAM_ONOFF, true)
	
	FHConfig:addParam("SAC", "Using SAC or MMA", SCRIPT_PARAM_ONOFF, false)

	PacketHandler:HookOutgoingPacket(Packet.headers.S_MOVE, CancelMovement)

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY,750,DAMAGE_MAGIC)
	ts.name = "FiddleSticks"
	ts.targetSelected = true
	FHConfig.combosettings:addTS(ts)
	FHConfig.combosettings.comboActive = false


end

function OnDraw()
	if FHConfig.drawsettings.enabledraw then
		if FHConfig.drawsettings.qdraw then
			DrawCircle2(myHero.x, myHero.y, myHero.z, QRange, ARGB(255,36,0,255))
		end
		if FHConfig.drawsettings.wdraw then
			DrawCircle2(myHero.x, myHero.y, myHero.z, WRange, ARGB(255,216,0,255))
		end
		if FHConfig.drawsettings.edraw then
			DrawCircle2(myHero.x, myHero.y, myHero.z, ERange, ARGB(255,66,0,66))
		end
		if FHConfig.drawsettings.rdraw then
			DrawCircle2(myHero.x, myHero.y, myHero.z, 800, ARGB(255,211,44,44))
		end
	end
end



function OnTick()
	ts:update()
	qready = (myHero:CanUseSpell(_Q) == READY)
	wready = (myHero:CanUseSpell(_W) == READY)
	eready = (myHero:CanUseSpell(_E) == READY)
	edamage = myHero:GetSpellData(_E).level ~= nil and math.floor(((((((myHero:GetSpellData(_E).level-1) * 20) + 65) + .45 * myHero.ap))))
	dfgslot = GetInventorySlotItem(3128)
	dfgready = (dfgslot ~= nil and myHero:CanUseSpell(dfgslot) == READY)
	bftslot = GetInventorySlotItem(3188)
	bftready = (bftslot ~= nil and myHero:CanUseSpell(bftslot) == READY)

	if (IsKeyDown(GetKey("W")) or IsKeyDown(GetKey("w"))) and wready then Draining = true end

	if ultActive and ts.target ~= nil then
		if (dfgready or bftready) and FHConfig.itemsettings.dfg and ValidTarget(ts.target, 750) then
			if dfgready then CastExploit(dfgslot, ts.target) end
			if bftready then CastExploit(bftslot, ts.target) end
		end
		if qready then
			CastExploit(_Q, ts.target)
		end
	end

	if Draining and _G.AutoCarry and _G.AutoCarry.MyHero then
		_G.AutoCarry.MyHero:AttacksEnabled(false)
		_G.AutoCarry.MyHero:MovementEnabled(false)
	elseif _G.AutoCarry and _G.AutoCarry.MyHero then
		_G.AutoCarry.MyHero:AttacksEnabled(true) 
		_G.AutoCarry.MyHero:MovementEnabled(true)
	end

	Combo()
	Harass()
	AutoKS()
end


function CancelMovement(p)
	if Draining and FHConfig.combosettings.comboActive then
		local packet = Packet(p)
		p:Block()
	end
end

function AutoKS()
	if FHConfig.kssettings.autoKS and ts.target ~= nil then
		if eready and ValidTarget(ts.target, 750) then
			if myHero:CalcMagicDamage(ts.target, edamage) > ts.target.health then
				CastExploit(_E, ts.target)
			end
		end
	end
end

function Harass()
	if FHConfig.harasssettings.harassActive then
		if FHConfig.harasssettings.movetomouse then
			myHero:MoveTo(mousePos.x, mousePos.z)
		end
		if ts.target ~= nil then
			if eready and ValidTarget(ts.target, 750) then
				CastExploit(_E, ts.target)
			end
		end
	end
end



function Combo()
	if FHConfig.combosettings.comboActive and ts.target ~= nil  and not Draining then
		if qready and ValidTarget(ts.target, 570) then 
			CastExploit(_Q, ts.target)
		end

		if wready and not Draining and ValidTarget(ts.target, 570) then
			CastExploit(_W, ts.target)
		end

		if eready and ValidTarget(ts.target, 750) then
			CastExploit(_E, ts.target)
		end
	end
end




function OnProcessSpell(object, spellProc)
	if object.isMe and spellProc.name == "Drain" then
		Draining = true
	end
end


function CastExploit(spell, target)
	if target ~= nil and ts.target ~= nil then 
		Packet("S_CAST", {spellId = spell, targetNetworkId = target.networkID}):send()
		--Packet("S_CAST", {spellId = spell, toX = target.x, toY = target.z, targetNetworkId = target.networkID}):send()
	else
		CastSpell(spell, target)
	end
end


--Detect if recalling or not
function OnGainBuff(unit, buff)
	if unit.isMe and buff.name == "Recall" or buff.name == "RecallImproved" then
		isRecalling = true
	end
	if unit.isMe and buff.name == "fearmonger_marker" then
		Draining = true
	end
	if unit.isMe and buff.name == "Crowstorm" then
		ultActive = true
	end
end

function OnLoseBuff(unit, buff)
	if unit.isMe and buff.name == "Recall" or buff.name == "RecallImproved" then
		isRecalling = false
	end
	if unit.isMe and buff.name == "fearmonger_marker" then
		Draining = false
	end
	if unit.isMe and buff.name == "Crowstorm" then
		ultActive = false
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