local runner = require("pio.runner")

local M = {}

function M.ensure_main_cpp(project_path, baud_rate)
    local src_dir = project_path .. "/src"
    vim.fn.mkdir(src_dir, "p")
    local files = vim.fn.readdir(src_dir)

    if #files == 0 then
        local cpp_content = string.format(
            [[
#include <Arduino.h>

void setup() {
    Serial.begin(%d);
    while (!Serial) { delay(10); }
    Serial.println("Proyecto PlatformIO inicializado correctamente.");
}

void loop() {
    Serial.println("Ejecutando...");
    delay(2000);
}
]],
            baud_rate or 115200
        )

        local f = io.open(src_dir .. "/main.cpp", "w")
        if f then
            f:write(cpp_content)
            f:close()
        end
    end
end

function M.generate_compile_commands(project_path, cb)
    runner.run_cmd_with_terminal("pio", { "run", "-t", "compiledb" }, { cwd = project_path }, cb)
end

return M
