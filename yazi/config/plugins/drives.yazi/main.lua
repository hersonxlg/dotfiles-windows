return {
	entry = function(self, job)
		local cands = {}

		if ya.target_family() == "windows" then
			-- ----------------------------------------------------
			-- LÓGICA PARA WINDOWS (Letras de unidad C:, D:, etc.)
			-- ----------------------------------------------------
			local child = Command("cmd")
				:arg("/c")
				:arg("for %d in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do @if exist %d:\\ echo %d:")
				:stdout(Command.PIPED)
				:stderr(Command.PIPED)
				:spawn()

			if child then
				local output = child:wait_with_output()
				if output and output.status.success then
					for line in output.stdout:gmatch("[^\r\n]+") do
						local drive = line:match("^%s*(%a:)%s*$")
						if drive then
							drive = drive:upper()
							table.insert(cands, {
								desc = "Unidad " .. drive,
								on = drive:sub(1, 1):lower(), -- Tecla de atajo (c, d, e...)
								path = drive .. "\\",
							})
						end
					end
				end
			end

		else
			-- ----------------------------------------------------
			-- LÓGICA PARA LINUX / MACOS (Puntos de montaje)
			-- ----------------------------------------------------
			-- Agregamos la raíz y carpetas habituales de montaje
			local default_paths = {
				{ desc = "Raíz del sistema (/)", on = "/", path = "/" },
				{ desc = "Directorio Personal (~)", on = "~", path = os.getenv("HOME") or "/" },
				{ desc = "Discos Montados (/mnt)", on = "m", path = "/mnt" },
				{ desc = "Medios Extraíbles (/media)", on = "e", path = "/media" },
				{ desc = "Volúmenes macOS (/Volumes)", on = "v", path = "/Volumes" },
			}

			for _, item in ipairs(default_paths) do
				-- Solo agrega las rutas que realmente existan en el sistema
				local cha = fs.cha(Url(item.path), false)
				if cha ~= nil then
					table.insert(cands, item)
				end
			end
		end

		if #cands == 0 then return end

		-- Desplegar el menú nativo de Yazi (Which-Key)
		local idx = ya.which({ cands = cands })
		if idx then
			ya.emit("cd", { cands[idx].path })
		end
	end,
}
