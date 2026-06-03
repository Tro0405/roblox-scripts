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
