--!strict
-- Music + SFX (DESIGN 8). Ids come from Config.Audio; 0 = silent. Settings toggles mute groups.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Candy = require(script.Parent.Candy)

local A = Config.Audio
local Sound = {}

local music = Instance.new("SoundGroup")
music.Name = "Music"
music.Volume = A.MusicVolume
music.Parent = SoundService
local sfx = Instance.new("SoundGroup")
sfx.Name = "SFX"
sfx.Volume = A.SfxVolume
sfx.Parent = SoundService

local cache: { [string]: Sound } = {}
local recent: { [string]: { number } } = {}

local function make(slot: string, id: number, group: SoundGroup): Sound?
	if id == 0 then
		return nil
	end
	local cached = cache[slot]
	if cached then
		return cached
	end
	local s = Instance.new("Sound")
	s.Name = slot
	s.SoundId = "rbxassetid://" .. id
	s.SoundGroup = group
	s.Parent = SoundService
	cache[slot] = s
	return s
end

-- play an SFX slot; limit = max plays per `window` seconds
function Sound.play(slot: string, pitch: number?, limit: number?, window: number?)
	local s = make(slot, A.Sfx[slot] or 0, sfx)
	if not s then
		return
	end
	if limit then
		local now = os.clock()
		local list: { number } = recent[slot] or {}
		local keep: { number } = {}
		for _, t in list do
			if now - t < (window or 0.2) then
				table.insert(keep, t)
			end
		end
		if #keep >= limit then
			recent[slot] = keep
			return
		end
		table.insert(keep, now)
		recent[slot] = keep
	end
	local c = s:Clone()
	c.PlaybackSpeed = pitch or 1
	c.Parent = SoundService
	c:Play()
	c.Ended:Once(function()
		c:Destroy()
	end)
end

-- looping sound for the charge stretch; returns the instance (or nil)
function Sound.loop(slot: string): Sound?
	local s = make(slot, A.Sfx[slot] or 0, sfx)
	if s then
		s.Looped = true
	end
	return s
end

local current: Sound? = nil
function Sound.music(slot: string)
	local s = make("music_" .. slot, A.Music[slot] or 0, music)
	if s == current then
		return
	end
	local old = current
	current = s
	local TweenService = game:GetService("TweenService")
	if old then
		local t = TweenService:Create(old, TweenInfo.new(A.Crossfade), { Volume = 0 })
		t.Completed:Once(function()
			old:Stop()
		end)
		t:Play()
	end
	if s then
		s.Looped = true
		s.Volume = 0
		s:Play()
		TweenService:Create(s, TweenInfo.new(A.Crossfade), { Volume = 1 }):Play()
	end
end

-- a one-shot from the Music table (the Re-Squish sting), on the music group
function Sound.sting(slot: string)
	local s = make("music_" .. slot, A.Music[slot] or 0, music)
	if s then
		s.Looped = false
		s.Volume = 1
		s:Play()
	end
end

function Sound.setEnabled(musicOn: boolean, sfxOn: boolean)
	music.Volume = if musicOn then A.MusicVolume else 0
	sfx.Volume = if sfxOn then A.SfxVolume else 0
end

function Sound.start()
	Candy.click = function()
		Sound.play("ui_click", 1, 4, 0.2)
	end
	Sound.music("main_theme")
	local amb = make("ambient", A.Sfx.ambient, sfx)
	if amb then
		amb.Looped = true
		amb.Volume = 0.12 / A.SfxVolume
		amb:Play()
	end
end

return Sound
