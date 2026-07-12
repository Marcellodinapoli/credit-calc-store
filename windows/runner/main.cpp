#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

Win32Window::Point DefaultWindowOrigin(const Win32Window::Size& size) {
  constexpr unsigned int margin = 10;

  RECT work_area{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

  const POINT probe = {
      work_area.right - 1,
      static_cast<LONG>(work_area.top + margin),
  };
  HMONITOR monitor = MonitorFromPoint(probe, MONITOR_DEFAULTTONEAREST);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale = dpi / 96.0;

  const auto work_right = static_cast<unsigned int>(work_area.right / scale);
  const auto x = work_right > size.width + margin
                     ? work_right - size.width - margin
                     : margin;

  return Win32Window::Point(x, margin);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Larghezza tipo Calcolatrice Windows, ~20% più ampia della base 322×660.
  Win32Window::Size size(386, 792);
  Win32Window::Point origin = DefaultWindowOrigin(size);
  std::wstring window_title = L"CreditCalc v";
#ifdef FLUTTER_VERSION
  {
    const std::string version = FLUTTER_VERSION;
    window_title.append(version.begin(), version.end());
  }
#else
  window_title += L"1.0.0";
#endif
  if (!window.Create(window_title.c_str(), origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
