--!strict
-- Progress events (fling, perfect, triple, merge, squeeze, catch, zone, …) fired by the gameplay
-- modules and heard by Quests and Badges. No dependencies, so nothing cycles.
-- Events and payloads:
--   fling, perfect, triple, squeeze, resquish, rain    (amount)
--   merge (size)  · rare (rarity index) · catch (rarity index, glitter) · zone (zone)
--   slots (slot count) · dex (species caught)
local Progress = {}
type Handler = (Player, ...any) -> ()
local handlers: { [string]: { Handler } } = {}

function Progress.on(event: string, fn: Handler)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
	end
	table.insert(list, fn)
end

function Progress.emit(player: Player, event: string, ...: any)
	local list = handlers[event]
	if not list then
		return
	end
	for _, fn in list do
		task.spawn(fn, player, ...)
	end
end

return Progress
