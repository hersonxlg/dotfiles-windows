local is_dir = ya.sync(function()
	local h = cx.active.current.hovered
	return h ~= nil and h.cha.is_dir
end)

return {
	entry = function()
		if is_dir() then
			ya.emit("enter", {})
		else
			ya.emit("open", {})
		end
	end,
}
