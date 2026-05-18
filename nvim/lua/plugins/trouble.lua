return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = "Trouble",
	keys = {
		-- Abre/cierra la lista global de diagnósticos del proyecto.
		-- Muestra errores, warnings, hints e información de todos los buffers.
		{
			"<leader>xx",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "Trouble: errores del proyecto",
		},

		-- Abre/cierra solo los diagnósticos del buffer actual.
		-- Útil cuando quieres concentrarte en el archivo que estás editando.
		{
			"<leader>xX",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Trouble: errores del buffer actual",
		},

		-- Abre/cierra la lista quickfix dentro de Trouble.
		-- Sirve para ver resultados de búsquedas, compilación, LSP, etc.
		{
			"<leader>xq",
			"<cmd>Trouble qflist toggle<cr>",
			desc = "Trouble: lista quickfix",
		},

		-- Abre/cierra la location list dentro de Trouble.
		-- Es parecida a quickfix, pero queda asociada a una ventana concreta.
		{
			"<leader>xl",
			"<cmd>Trouble loclist toggle<cr>",
			desc = "Trouble: lista location",
		},

		-- Muestra los símbolos del archivo actual en un panel lateral.
		-- Muy útil para ver funciones, clases, métodos y estructuras del documento.
		{
			"<leader>cs",
			"<cmd>Trouble symbols toggle focus=false win.position=right<cr>",
			desc = "Trouble: símbolos del archivo",
		},

		-- Abre la vista LSP de Trouble.
		-- Suele servir para navegar entre referencias, definiciones, implementaciones,
		-- tipos y llamadas, según lo que el servidor LSP entregue.
		{
			"<leader>cl",
			"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
			desc = "Trouble: vista LSP",
		},
	},
	opts = {},
}
