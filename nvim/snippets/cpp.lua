local ls = require("luasnip")

local s = ls.snippet
local i = ls.insert_node
local rep = require("luasnip.extras").rep
local fmt = require("luasnip.extras.fmt").fmt

return {

    -- =========================================================
    -- Standard C++
    -- =========================================================

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

    -- =========================================================
    -- Arduino / ESP32
    -- =========================================================

    -- 8. Plantilla de conexión WiFi para ESP32
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

    -- =========================================================
    -- OneButton
    -- =========================================================

    -- 9. Plantilla avanzada para OneButton
    s(
        "onebtn",
        fmt([[
#include <Arduino.h>
#include <OneButton.h>

// ======================
// Button Configuration
// ======================

// GPIO where the button is connected.
// Recommended for ESP32: 4, 5, 18, 19, 21, 22, 23.
constexpr uint8_t BUTTON_PIN = {};

// Button wiring:
// GPIO ---- BUTTON ---- GND
//
// activeLow = true:
//   The button is considered pressed when the pin goes LOW.
//
// inputPullup = true:
//   Enables the internal pull-up resistor.
constexpr bool BUTTON_ACTIVE_LOW = true;
constexpr bool BUTTON_ENABLE_PULLUP = true;

// ======================
// Timing Configuration
// ======================

constexpr uint16_t DEBOUNCE_MS = 50;
constexpr uint16_t CLICK_MS = 200;
constexpr uint16_t LONG_PRESS_MS = 400;
constexpr uint16_t LONG_PRESS_INTERVAL_MS = 100;
constexpr uint16_t IDLE_MS = 1000;

// ======================
// OneButton Instance
// ======================

// Classic and simple constructor form.
// This version is very practical for Arduino and ESP32.
OneButton button(BUTTON_PIN, BUTTON_ACTIVE_LOW, BUTTON_ENABLE_PULLUP);

// ======================
// Button Callbacks
// ======================

void onPress() {{
    Serial.println("[EVENT] Button Pressed");
}}

void onClick() {{
    Serial.println("[EVENT] Single Click");
}}

void onDoubleClick() {{
    Serial.println("[EVENT] Double Click");
}}

void onLongPressStart() {{
    Serial.println("[EVENT] Long Press Start");
}}

void onLongPressStop() {{
    Serial.println("[EVENT] Long Press Stop");
}}

void onDuringLongPress() {{
    Serial.print("[EVENT] Holding Button: ");
    Serial.print(button.getPressedMs());
    Serial.println(" ms");
}}

// ======================
// Button Initialization
// ======================

void setupButton() {{

    // Timing configuration.
    button.setDebounceMs(DEBOUNCE_MS);
    button.setClickMs(CLICK_MS);
    button.setPressMs(LONG_PRESS_MS);
    button.setLongPressIntervalMs(LONG_PRESS_INTERVAL_MS);
    button.setIdleMs(IDLE_MS);

    // Callback assignment.
    button.attachPress(onPress);
    button.attachClick(onClick);
    button.attachDoubleClick(onDoubleClick);
    button.attachLongPressStart(onLongPressStart);
    button.attachLongPressStop(onLongPressStop);
    button.attachDuringLongPress(onDuringLongPress);
}}

// ======================
// Setup
// ======================

void setup() {{
    Serial.begin(115200);

    Serial.println();
    Serial.println("OneButton Example Started");

    setupButton();
}}

// ======================
// Main Loop
// ======================

void loop() {{

    // IMPORTANT:
    // tick() must run continuously so the internal state machine
    // can detect clicks, double clicks, long presses, and repeats.
    button.tick();

    {}
}}
]], {
            i(1, "4"),
            i(0)
        })
    ),
}
