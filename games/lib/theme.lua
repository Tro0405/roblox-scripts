--[[
	TvFruit — Shared UI Theme & Window Library
	Mọi script game nạp file này để có GUI THỐNG NHẤT (cùng khung, sidebar, orb, màu cyan).
	Dùng:
	  local Lib = loadstring(game:HttpGet(".../games/lib/theme.lua", true))()
	  local win = Lib:Window({Title="Tên Game", Icon="📺"})
	  local page = win:Tab("Home","🏠")
	  win:Show("Home")
	Đổi màu chủ đạo: sửa Lib.Colors.Accent ở dưới -> tất cả game đổi theo.
]]

local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local HOST=(gethui and gethui()) or game:GetService("CoreGui")

local Lib={}
Lib.Colors={
	Accent  =Color3.fromRGB(6,206,227),   -- XANH CYAN (màu chủ đạo)
	Bg      =Color3.fromRGB(15,18,22),
	Bg2     =Color3.fromRGB(23,27,33),
	Bg3     =Color3.fromRGB(34,39,47),
	Text    =Color3.fromRGB(235,238,242),
	TextDim =Color3.fromRGB(165,172,182),
	Danger  =Color3.fromRGB(170,55,55),
	Good    =Color3.fromRGB(50,150,90),
}
local C=Lib.Colors

function Lib.Corner(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 6); return c end

-- nhãn nhanh: L(parent,x,y,text,size,color,wrapH)
function Lib.L(parent,x,y,t,size,col,wrapH)
	local l=Instance.new("TextLabel",parent); l.BackgroundTransparency=1; l.Position=UDim2.new(0,x,0,y)
	l.Size=UDim2.new(1,-x-14,0,wrapH or (size+6)); l.Font=Enum.Font.GothamMedium; l.TextSize=size or 12
	l.TextColor3=col or C.Text; l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=t
	if wrapH then l.TextWrapped=true; l.TextYAlignment=Enum.TextYAlignment.Top end
	return l
end

-- nút: Btn(parent,{Pos,Size,Text,Color,TextColor,TextSize,Radius})
function Lib.Btn(parent,p)
	local b=Instance.new("TextButton",parent); b.BorderSizePixel=0; b.AutoButtonColor=true
	b.BackgroundColor3=p.Color or C.Bg3; b.Position=p.Pos or UDim2.new(0,0,0,0); b.Size=p.Size or UDim2.new(0,100,0,30)
	b.Font=Enum.Font.GothamBold; b.TextSize=p.TextSize or 13; b.TextColor3=p.TextColor or C.Text; b.Text=p.Text or ""
	Lib.Corner(b,p.Radius or 6); return b
end

function Lib.Scroll(parent,pos,size)
	local s=Instance.new("ScrollingFrame",parent); s.Position=pos; s.Size=size; s.BackgroundColor3=C.Bg; s.BorderSizePixel=0
	s.ScrollBarThickness=5; s.ScrollBarImageColor3=C.Accent; s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.CanvasSize=UDim2.new(0,0,0,0); Lib.Corner(s,6)
	local l=Instance.new("UIListLayout",s); l.Padding=UDim.new(0,3)
	local p=Instance.new("UIPadding",s); p.PaddingTop=UDim.new(0,4); p.PaddingLeft=UDim.new(0,4); p.PaddingRight=UDim.new(0,4)
	return s
end

local function dragify(handle,target,onClick)
	local dragging,moved,ds,sp=false,false
	handle.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;moved=false;ds=i.Position;sp=target.Position end end)
	handle.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false; if not moved and onClick then onClick() end end end)
	UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-ds; if math.abs(d.X)>4 or math.abs(d.Y)>4 then moved=true end; target.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end

-- nhãn section nhỏ (chữ accent)
function Lib.Section(parent,y,text)
	local l=Instance.new("TextLabel",parent); l.Position=UDim2.new(0,16,0,y); l.Size=UDim2.new(1,-32,0,16); l.BackgroundTransparency=1; l.Font=Enum.Font.GothamBold; l.TextSize=10; l.TextColor3=C.Accent; l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); return l
end

-- thẻ nền bo góc
function Lib.Card(parent,y,h)
	local f=Instance.new("Frame",parent); f.Position=UDim2.new(0,12,0,y); f.Size=UDim2.new(1,-24,0,h); f.BackgroundColor3=C.Bg3; f.BorderSizePixel=0; Lib.Corner(f,8); return f
end

-- Toggle dạng pill (dùng chung): o={y,icon,title,sub,color,default,callback}
function Lib.Toggle(parent,o)
	local color=o.color or C.Accent
	local row=Lib.Card(parent,o.y,54)
	local ib=Instance.new("Frame",row); ib.Position=UDim2.new(0,10,0.5,-17); ib.Size=UDim2.new(0,34,0,34); ib.BackgroundColor3=color; ib.BorderSizePixel=0; Lib.Corner(ib,7)
	local il=Instance.new("TextLabel",ib); il.Size=UDim2.new(1,0,1,0); il.BackgroundTransparency=1; il.Text=o.icon or "•"; il.Font=Enum.Font.GothamBold; il.TextSize=16; il.TextColor3=Color3.new(1,1,1)
	local t=Instance.new("TextLabel",row); t.Position=UDim2.new(0,54,0,9); t.Size=UDim2.new(1,-116,0,18); t.BackgroundTransparency=1; t.Text=o.title or ""; t.Font=Enum.Font.GothamBold; t.TextSize=13; t.TextColor3=C.Text; t.TextXAlignment=Enum.TextXAlignment.Left
	local s=Instance.new("TextLabel",row); s.Position=UDim2.new(0,54,0,30); s.Size=UDim2.new(1,-116,0,14); s.BackgroundTransparency=1; s.Text=o.sub or ""; s.Font=Enum.Font.Gotham; s.TextSize=10; s.TextColor3=C.TextDim; s.TextXAlignment=Enum.TextXAlignment.Left
	local pill=Instance.new("Frame",row); pill.Position=UDim2.new(1,-54,0.5,-11); pill.Size=UDim2.new(0,44,0,22); pill.BackgroundColor3=Color3.fromRGB(60,60,70); pill.BorderSizePixel=0; Lib.Corner(pill,11)
	local dot=Instance.new("Frame",pill); dot.Position=UDim2.new(0,3,0.5,-8); dot.Size=UDim2.new(0,16,0,16); dot.BackgroundColor3=Color3.new(1,1,1); dot.BorderSizePixel=0; Lib.Corner(dot,8)
	local state=o.default or false
	local function render(anim)
		local pc=state and color or Color3.fromRGB(60,60,70)
		local dp=state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
		if anim then TweenService:Create(pill,TweenInfo.new(0.18),{BackgroundColor3=pc}):Play(); TweenService:Create(dot,TweenInfo.new(0.18),{Position=dp}):Play()
		else pill.BackgroundColor3=pc; dot.Position=dp end
	end
	render(false)
	local btn=Instance.new("TextButton",row); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
	btn.MouseButton1Click:Connect(function() state=not state; render(true); if o.callback then o.callback(state) end end)
	return row
end

-- Slider: o={y,label,min,max,default,callback}
function Lib.Slider(parent,o)
	local card=Lib.Card(parent,o.y,60)
	local lbl=Instance.new("TextLabel",card); lbl.Position=UDim2.new(0,10,0,8); lbl.Size=UDim2.new(0.6,0,0,18); lbl.BackgroundTransparency=1; lbl.Text=o.label or ""; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextColor3=C.Text; lbl.TextXAlignment=Enum.TextXAlignment.Left
	local val=Instance.new("TextLabel",card); val.Position=UDim2.new(0.6,0,0,8); val.Size=UDim2.new(0.4,-10,0,18); val.BackgroundTransparency=1; val.Text=tostring(o.default); val.Font=Enum.Font.GothamBold; val.TextSize=13; val.TextColor3=C.Accent; val.TextXAlignment=Enum.TextXAlignment.Right
	local track=Instance.new("Frame",card); track.Position=UDim2.new(0,10,0,42); track.Size=UDim2.new(1,-20,0,6); track.BackgroundColor3=Color3.fromRGB(50,55,62); track.BorderSizePixel=0; Lib.Corner(track,3)
	local pct0=(o.default-o.min)/(o.max-o.min)
	local fill=Instance.new("Frame",track); fill.Size=UDim2.new(pct0,0,1,0); fill.BackgroundColor3=C.Accent; fill.BorderSizePixel=0; Lib.Corner(fill,3)
	local thumb=Instance.new("Frame",track); thumb.Position=UDim2.new(pct0,-8,0.5,-8); thumb.Size=UDim2.new(0,16,0,16); thumb.BackgroundColor3=Color3.new(1,1,1); thumb.ZIndex=3; thumb.BorderSizePixel=0; Lib.Corner(thumb,8)
	local dragging=false
	local function upd(absX)
		local pct=math.clamp((absX-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
		fill.Size=UDim2.new(pct,0,1,0); thumb.Position=UDim2.new(pct,-8,0.5,-8)
		local v=math.floor(o.min+pct*(o.max-o.min)); val.Text=tostring(v); if o.callback then o.callback(v) end
	end
	track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; upd(i.Position.X) end end)
	thumb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
	UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i.Position.X) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
	return card
end

-- Tạo cửa sổ chuẩn: top bar + sidebar + content + orb thu nhỏ
function Lib:Window(opts)
	opts=opts or {}
	local icon=opts.Icon or "📺"
	local gui=Instance.new("ScreenGui"); gui.Name=opts.Name or "TvFruitGUI"; gui.ResetOnSpawn=false; gui.Parent=HOST

	local orb=Instance.new("TextButton",gui); orb.Size=UDim2.new(0,58,0,58); orb.Position=UDim2.new(0,18,0.45,0); orb.BackgroundColor3=C.Bg2; orb.AutoButtonColor=false; orb.Text=icon; orb.TextSize=30; orb.Font=Enum.Font.GothamBold; orb.TextColor3=C.Accent; orb.Visible=false
	Lib.Corner(orb,29); local ostk=Instance.new("UIStroke",orb); ostk.Color=C.Accent; ostk.Thickness=2

	local win=Instance.new("Frame",gui); win.Size=opts.Size or UDim2.new(0,620,0,430); win.Position=UDim2.new(0.5,-310,0.5,-215); win.BackgroundColor3=C.Bg; win.BorderSizePixel=0; Lib.Corner(win,10)
	local wstk=Instance.new("UIStroke",win); wstk.Color=C.Accent; wstk.Thickness=1; wstk.Transparency=0.45

	local top=Instance.new("Frame",win); top.Size=UDim2.new(1,0,0,36); top.BackgroundColor3=C.Bg2; top.BorderSizePixel=0; Lib.Corner(top,10)
	local titl=Instance.new("TextLabel",top); titl.Size=UDim2.new(1,-90,1,0); titl.Position=UDim2.new(0,14,0,0); titl.BackgroundTransparency=1; titl.Font=Enum.Font.GothamBold; titl.TextSize=14; titl.TextColor3=C.Accent; titl.TextXAlignment=Enum.TextXAlignment.Left; titl.Text=icon.."  TvFruit  |  "..(opts.Title or "")
	local minB=Lib.Btn(top,{Pos=UDim2.new(1,-72,0.5,-12),Size=UDim2.new(0,32,0,24),Text="–",Color=C.Bg3,Radius=5})
	local clsB=Lib.Btn(top,{Pos=UDim2.new(1,-36,0.5,-12),Size=UDim2.new(0,32,0,24),Text="✕",Color=C.Danger,Radius=5})

	local side=Instance.new("Frame",win); side.Size=UDim2.new(0,138,1,-46); side.Position=UDim2.new(0,8,0,42); side.BackgroundColor3=C.Bg2; side.BorderSizePixel=0; Lib.Corner(side,8)
	local slay=Instance.new("UIListLayout",side); slay.Padding=UDim.new(0,4); local spad=Instance.new("UIPadding",side); spad.PaddingTop=UDim.new(0,8); spad.PaddingLeft=UDim.new(0,8); spad.PaddingRight=UDim.new(0,8)

	local content=Instance.new("Frame",win); content.Size=UDim2.new(1,-160,1,-46); content.Position=UDim2.new(0,152,0,42); content.BackgroundColor3=C.Bg2; content.BorderSizePixel=0; Lib.Corner(content,8)

	local W={Gui=gui,Window=win,Content=content,_pages={},_nav={}}
	function W:Show(name)
		for n,pg in pairs(self._pages) do pg.Visible=(n==name) end
		for n,bt in pairs(self._nav) do bt.BackgroundColor3=(n==name) and C.Bg3 or C.Bg2; bt.TextColor3=(n==name) and C.Accent or C.TextDim end
	end
	function W:Tab(name,ic)
		local b=Instance.new("TextButton",side); b.Size=UDim2.new(1,0,0,34); b.BackgroundColor3=C.Bg2; b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=13; b.TextColor3=C.TextDim; b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  "..(ic or "•").."  "..name; Lib.Corner(b,6)
		self._nav[name]=b; b.MouseButton1Click:Connect(function() self:Show(name) end)
		local pg=Instance.new("Frame",content); pg.Size=UDim2.new(1,0,1,0); pg.BackgroundTransparency=1; pg.Visible=false; self._pages[name]=pg
		return pg
	end
	function W:OnClose(fn) self._onClose=fn end

	dragify(top,win)
	dragify(orb,orb,function() win.Visible=true; orb.Visible=false end)
	minB.MouseButton1Click:Connect(function() win.Visible=false; orb.Visible=true end)
	clsB.MouseButton1Click:Connect(function() if W._onClose then pcall(W._onClose) end; gui:Destroy() end)

	return W
end

return Lib
