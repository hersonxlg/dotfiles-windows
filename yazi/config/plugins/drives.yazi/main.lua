return {
	entry = function(self, job)
		local cands = {}

		if ya.target_family() == "windows" then
			-- ----------------------------------------------------
			-- WINDOWS: Buscar letras de disco (C:, D:, etc.)
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
								on = drive:sub(1, 1):lower(),
								path = drive .. "\\",
							})
						end
					end
				end
			end

		else
			-- ----------------------------------------------------
			-- LINUX: Filtrar ÚNICAMENTE unidades USB / externas
			-- ----------------------------------------------------
			local child = Command("lsblk")
				:arg("-P") -- Formato de pares KEY="VALUE"
				:arg("-n")
				:arg("-o")
				:arg("MOUNTPOINT,LABEL,NAME,TRAN,RM")
				:stdout(Command.PIPED)
				:stderr(Command.PIPED)
				:spawn()

			if child then
				local output = child:wait_with_output()
				if output and output.status.success then
					local key_pool = "123456789abcdefghijklmnopqrstuvwxyz"
					local key_idx = 1

					for line in output.stdout:gmatch("[^\r\n]+") do
						-- Extraer variables de lsblk
						local mount = line:match('MOUNTPOINT="(.-)"')
						local label = line:match('LABEL="(.-)"')
						local name = line:match('NAME="(.-)"')
						local tran = line:match('TRAN="(.-)"')
						local rm = line:match('RM="(.-)"')

						-- 1. Debe tener un punto de montaje válido (excluir swap)
						if mount and mount ~= "" and mount ~= "[SWAP]" then
							local is_media_path = mount:find("^/media/") or mount:find("^/run/media/")
							local is_usb = (tran and tran:lower() == "usb") or rm == "1"

							-- 2. Filtrar solo si es un USB/extraíble o está en /run/media/
							if (is_usb or is_media_path) and mount ~= "/" and mount ~= "/boot/efi" then
								local shortcut = key_pool:sub(key_idx, key_idx)
								if shortcut == "" then shortcut = "?" end

								local display_name = (label and label ~= "") and (label .. " (" .. mount .. ")") or mount

								table.insert(cands, {
									desc = display_name,
									on = shortcut,
									path = mount,
								})

								key_idx = key_idx + 1
							end
						end
					end
				end
			end
		end

		-- Si no hay USBs conectados
		if #cands == 0 then
			ya.notify({
				title = "Drives",
				content = "No hay unidades USB/externas montadas.",
				level = "warn",
				timeout = 2,
			})
			return
		end

		-- Desplegar el menú nativo de Yazi
		local idx = ya.which({ cands = cands })
		if idx then
			ya.emit("cd", { cands[idx].path })
		end
	end,
}
