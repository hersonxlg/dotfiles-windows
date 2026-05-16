local ls = require("luasnip")

local s = ls.snippet
local i = ls.insert_node
local rep = require("luasnip.extras").rep
local fmt = require("luasnip.extras.fmt").fmt

return {

    -- 1. Estructura Base Clásica
    s(
        "basecpp",
        fmt([[
#include <iostream>

int main() {{
    {}
    return 0;
}}
]], {
            i(1)
        })
    ),

    -- 2. Estructura Base para Programación Competitiva (Fast I/O)
    s(
        "basefast",
        fmt([[
#include <bits/stdc++.h>
using namespace std;

void solve() {{
    {}
}}

int main() {{
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    int t = 1;
    // cin >> t;

    while (t--) {{
        solve();
    }}

    return 0;
}}
]], {
            i(1)
        })
    ),

    -- 3. Bucle For Dinámico
    s(
        "fori",
        fmt([[
for (int {} = 0; {} < {}; ++{}) {{
    {}
}}
]], {
            i(1, "i"),
            rep(1),
            i(2, "n"),
            rep(1),
            i(0)
        })
    ),

    -- 4. Bucle For-Each moderno
    s(
        "fore",
        fmt([[
for (const auto& {} : {}) {{
    {}
}}
]], {
            i(1, "x"),
            i(2, "contenedor"),
            i(0)
        })
    ),

    -- 5. Plantilla rápida para una Función
    s(
        "func",
        fmt([[
{} {}({}) {{
    {}
}}
]], {
            i(1, "void"),
            i(2, "nombreFuncion"),
            i(3),
            i(0)
        })
    ),

    -- 6. If-Else completo
    s(
        "ifelse",
        fmt([[
if ({}) {{
    {}
}} else {{
    {}
}}
]], {
            i(1),
            i(2),
            i(0)
        })
    ),

    -- 7. cout rápido
    s(
        "cout",
        fmt([[
std::cout << {} << std::endl;{}
]], {
            i(1, "\"texto\""),
            i(0)
        })
    ),


    s(
        "espwifi",
        fmt([[
#include <Arduino.h>
#include <WiFi.h>

// ======================
// WiFi Configuration
// ======================

constexpr const char* WIFI_SSID = "{}";
constexpr const char* WIFI_PASSWORD = "{}";

// ======================
// WiFi Connection
// ======================

void connectToWiFi() {{
    Serial.print("Connecting to WiFi");

    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    uint32_t startAttemptTime = millis();

    while (WiFi.status() != WL_CONNECTED &&
           millis() - startAttemptTime < 10000) {{

        Serial.print(".");
        delay(500);
    }}

    if (WiFi.status() == WL_CONNECTED) {{
        Serial.println("\\nWiFi connected!");
        Serial.print("IP Address: ");
        Serial.println(WiFi.localIP());
    }} else {{
        Serial.println("\\nFailed to connect to WiFi.");
    }}
}}

// ======================
// Setup
// ======================

void setup() {{
    Serial.begin(115200);

    connectToWiFi();
}}

// ======================
// Main Loop
// ======================

void loop() {{

    // Auto reconnect
    if (WiFi.status() != WL_CONNECTED) {{
        Serial.println("WiFi lost. Reconnecting...");
        connectToWiFi();
    }}

    {}
}}
]], {
            i(1, "TuWiFi"),
            i(2, "TuPassword"),
            i(0)
        })
    ),
}
