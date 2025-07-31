// keypress_simulator_windows_plugin.cpp

#include "keypress_simulator_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <psapi.h>
#include <string.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <vector>

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace keypress_simulator_windows {

// Forward declarations for window‐finding helpers.
struct FindWindowData {
  std::string targetProcessName;
  std::string targetWindowTitle;
  HWND foundWindow;
};
BOOL CALLBACK EnumWindowsCallback(HWND hwnd, LPARAM lParam);
HWND FindTargetWindow(const std::string& processName,
                      const std::string& windowTitle);

// static
void KeypressSimulatorWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "dev.leanflutter.plugins/keypress_simulator",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<KeypressSimulatorWindowsPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

KeypressSimulatorWindowsPlugin::KeypressSimulatorWindowsPlugin() {}
KeypressSimulatorWindowsPlugin::~KeypressSimulatorWindowsPlugin() {}

void KeypressSimulatorWindowsPlugin::SimulateKeyPress(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const EncodableMap& args =
      std::get<EncodableMap>(*method_call.arguments());

  // 1) Read parameters from Dart.
  UINT keyCode = std::get<int>(args.at(EncodableValue("keyCode")));
  bool keyDown =
      std::get<bool>(args.at(EncodableValue("keyDown")));

  // Collect modifiers list.
  EncodableList encMods =
      std::get<EncodableList>(args.at(EncodableValue("modifiers")));
  std::vector<std::string> modifiers;
  for (const auto& v : encMods) {
    modifiers.push_back(std::get<std::string>(v));
  }

  // 2) If needed, find and focus a known target window.
  std::vector<std::string> compatibleApps = {
      "MyWhooshHD.exe", "indieVelo.exe", "biketerra.exe"};
  HWND targetWindow = NULL;
  for (auto& proc : compatibleApps) {
    targetWindow = FindTargetWindow(proc, "");
    if (targetWindow) {
      if (GetForegroundWindow() != targetWindow) {
        SetForegroundWindow(targetWindow);
        Sleep(50);
      }
      break;
    }
  }

  // 3) Build INPUT array using SCANCODE injection.
  INPUT inputs[6] = {};  // Max 4 modifiers + 1 key = 5, buffer to 6.
  int eventCount = 0;

  // Helper: map VK_* to scancode, zero wVk
  auto fillEvent = [&](WORD vk, bool down) {
    inputs[eventCount].type = INPUT_KEYBOARD;
    inputs[eventCount].ki.wVk = 0;
    inputs[eventCount].ki.wScan =
        MapVirtualKey(vk, MAPVK_VK_TO_VSC);
    inputs[eventCount].ki.dwFlags =
        KEYEVENTF_SCANCODE | (down ? 0 : KEYEVENTF_KEYUP);
    eventCount++;
  };

  // 3a) Modifiers first.
  for (auto& m : modifiers) {
    if (m == "shiftModifier") {
      fillEvent(VK_SHIFT, keyDown);
    } else if (m == "controlModifier") {
      fillEvent(VK_CONTROL, keyDown);
    } else if (m == "altModifier") {
      fillEvent(VK_MENU, keyDown);
    } else if (m == "metaModifier") {
      fillEvent(VK_LWIN, keyDown);
    }
  }

  // 3b) Then the main key.
  fillEvent(static_cast<WORD>(keyCode), keyDown);

  // 4) Send only the filled events.
  SendInput(static_cast<UINT>(eventCount), inputs, sizeof(INPUT));

  result->Success(EncodableValue(true));
}

void KeypressSimulatorWindowsPlugin::SimulateMouseClick(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const EncodableMap& args =
      std::get<EncodableMap>(*method_call.arguments());
  double x = 0, y = 0;
  if (auto it = args.find(EncodableValue("x"));
      it != args.end() && std::holds_alternative<double>(it->second)) {
    x = std::get<double>(it->second);
  }
  if (auto it = args.find(EncodableValue("y"));
      it != args.end() && std::holds_alternative<double>(it->second)) {
    y = std::get<double>(it->second);
  }

  SetCursorPos(static_cast<int>(x), static_cast<int>(y));
  INPUT input = {};
  input.type = INPUT_MOUSE;

  input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
  SendInput(1, &input, sizeof(INPUT));
  input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
  SendInput(1, &input, sizeof(INPUT));

  result->Success(EncodableValue(true));
}

BOOL CALLBACK EnumWindowsCallback(HWND hwnd, LPARAM lParam) {
  auto* data = reinterpret_cast<FindWindowData*>(lParam);

  if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) return TRUE;

  char windowTitle[256];
  GetWindowTextA(hwnd, windowTitle, sizeof(windowTitle));

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (hProc) {
    char fullPath[MAX_PATH];
    DWORD size = sizeof(fullPath);
    if (QueryFullProcessImageNameA(hProc, 0, fullPath, &size)) {
      char* filename = strrchr(fullPath, '\\');
      const char* exeName = filename ? filename + 1 : fullPath;
      if (!_stricmp(exeName, data->targetProcessName.c_str())) {
        data->foundWindow = hwnd;
        CloseHandle(hProc);
        return FALSE;
      }
    }
    CloseHandle(hProc);
  }

  if (!data->targetWindowTitle.empty() &&
      !_stricmp(windowTitle, data->targetWindowTitle.c_str())) {
    data->foundWindow = hwnd;
    return FALSE;
  }

  return TRUE;
}

HWND FindTargetWindow(const std::string& processName,
                      const std::string& windowTitle) {
  FindWindowData data;
  data.targetProcessName = processName;
  data.targetWindowTitle = windowTitle;
  data.foundWindow = NULL;
  EnumWindows(EnumWindowsCallback,
              reinterpret_cast<LPARAM>(&data));
  return data.foundWindow;
}

void KeypressSimulatorWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
  if (method == "simulateKeyPress") {
    SimulateKeyPress(method_call, std::move(result));
  } else if (method == "simulateMouseClick") {
    SimulateMouseClick(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace keypress_simulator_windows
