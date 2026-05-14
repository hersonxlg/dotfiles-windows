local ls = require("luasnip")
local parse = ls.parser.parse_snippet

return {
  -- Snippet inteligente para Canvas con tipado automático JSDoc
  parse("canvas2d", "/** @type {HTMLCanvasElement} */\nconst ${1:canvas} = document.getElementById(\"${1:canvas}\");\n\n/** @type {CanvasRenderingContext2D} */\nconst ${2:ctx} = ${1:canvas}.getContext(\"2d\");\n$0"),
}
