local ls = require("luasnip")
local parse = ls.parser.parse_snippet

return {
  -- 1. Estructura Base Clásica para C
  parse("basec", "#include <stdio.h>\n#include <stdlib.h>\n\nint main() {\n    $1\n    return 0;\n}"),

  -- 2. Bucle For Dinámico (C99/Moderno con espejo de variables)
  parse("fori", "for (int ${1:i} = 0; $1 < ${2:n}; ++$1) {\n    $0\n}"),

  -- 3. Impresión en pantalla rápida (printf)
  parse("printf", "printf(\"${1:%s}\\n\", ${2:variable});$0"),

  -- 4. Lectura de datos rápida (scanf)
  parse("scanf", "scanf(\"${1:%d}\", &${2:variable});$0"),

  -- 5. Estructura Condicional If-Else completo
  parse("ifelse", "if ($1) {\n    $2\n} else {\n    $0\n}"),

  -- 6. Plantilla rápida para una Función en C
  parse("func", "${1:void} ${2:nombreFuncion}($3) {\n    $0\n}"),

  -- 7. Definición de una Estructura (struct) clásica
  parse("struct", "typedef struct {\n    $1\n} ${2:NombreEstructura};$0"),
}
