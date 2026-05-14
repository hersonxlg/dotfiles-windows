local ls = require("luasnip")
local parse = ls.parser.parse_snippet

return {
  -- 1. Estructura Base Clásica
  parse("basecpp", "#include <iostream>\n\nint main() {\n    $1\n    return 0;\n}"),

  -- 2. Estructura Base para Programación Competitiva (Fast I/O)
  parse("basefast", "#include <bits/stdc++.h>\nusing namespace std;\n\nvoid solve() {\n    $1\n}\n\nint main() {\n    ios_base::sync_with_stdio(false);\n    cin.tie(NULL);\n    int t = 1;\n    // cin >> t;\n    while (t--) {\n        solve();\n    }\n    return 0;\n}"),

  -- 3. Bucle For Dinámico (Con espejo dinámico de variables)
  parse("fori", "for (int ${1:i} = 0; $1 < ${2:n}; ++$1) {\n    $0\n}"),

  -- 4. Bucle For-Each (Rango) moderno
  parse("fore", "for (const auto& ${1:x} : ${2:contenedor}) {\n    $0\n}"),

  -- 5. Plantilla rápida para una Función
  parse("func", "${1:void} ${2:nombreFuncion}($3) {\n    $0\n}"),

  -- 6. Estructura Condicional If-Else completo
  parse("ifelse", "if ($1) {\n    $2\n} else {\n    $0\n}"),

  -- 7. Impresión rápida en consola con salto de línea
  parse("cout", "std::cout << ${1:\"texto\"} << std::endl;$0"),
}
