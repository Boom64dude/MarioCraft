// MarioCraft Launcher: one button to play.
//
// Play: brings Prism's MarioCraft instance up to date (setup-prism.ps1), starts Minecraft through
// Prism Launcher with the account signed in there (so your skin is yours; Minecraft stays hidden,
// SM64 draws everything), then starts SM64. Minecraft quits by itself when SM64 closes.
//
// Build (MSYS2 MINGW64):  bash launcher/build.sh
// Lives in the mariocraft folder, next to sm64coopdx\ and launcher\.

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <stdbool.h>
#include <stdio.h>
#include <wchar.h>

#define ID_PLAY    101
#define ID_ACCOUNT 102
#define ID_STATUS  103
#define WM_SETUP_DONE (WM_APP + 1)

static wchar_t sRoot[MAX_PATH];  // the mariocraft folder (where this exe is)
static HWND sWindow, sStatus, sPlay, sAccount;
static HFONT sFont, sTitleFont;

static void path_in_root(wchar_t *out, const wchar_t *rel) {
    swprintf(out, MAX_PATH, L"%ls\\%ls", sRoot, rel);
}

static void set_status(const wchar_t *text) {
    SetWindowTextW(sStatus, text);
}

static bool process_running(const wchar_t *exe) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) {
        return false;
    }
    PROCESSENTRY32W e;
    memset(&e, 0, sizeof(e));
    e.dwSize = sizeof(e);
    bool found = false;
    for (BOOL more = Process32FirstW(snap, &e); more && !found; more = Process32NextW(snap, &e)) {
        found = _wcsicmp(e.szExeFile, exe) == 0;
    }
    CloseHandle(snap);
    return found;
}

// The MarioCraft mod holds this mutex while its Minecraft runs (SkyLink.announceRunning).
static bool minecraft_running(void) {
    HANDLE m = OpenMutexW(SYNCHRONIZE, FALSE, L"Local\\MarioCraft_v1_minecraft");
    if (m != NULL) {
        CloseHandle(m);
        return true;
    }
    return false;
}

// Which Prism setup-prism.ps1 picked (it writes launcher\prism-path.txt).
static bool prism_path(wchar_t *out) {
    wchar_t file[MAX_PATH];
    path_in_root(file, L"launcher\\prism-path.txt");
    FILE *f = _wfopen(file, L"r");
    if (f == NULL) {
        return false;
    }
    char line[MAX_PATH] = { 0 };
    bool ok = fgets(line, sizeof(line), f) != NULL;
    fclose(f);
    if (!ok) {
        return false;
    }
    line[strcspn(line, "\r\n")] = '\0';
    MultiByteToWideChar(CP_ACP, 0, line, -1, out, MAX_PATH);
    return GetFileAttributesW(out) != INVALID_FILE_ATTRIBUTES;
}

static bool start(const wchar_t *exe, const wchar_t *args, const wchar_t *dir) {
    return (INT_PTR) ShellExecuteW(NULL, L"open", exe, args, dir, SW_SHOWNORMAL) > 32;
}

// Runs setup-prism.ps1 without a window; its output goes to launcher\setup.log. Off the UI thread.
static DWORD WINAPI setup_thread(LPVOID param) {
    (void) param;
    wchar_t script[MAX_PATH], log[MAX_PATH], cmd[MAX_PATH * 3];
    path_in_root(script, L"launcher\\setup-prism.ps1");
    path_in_root(log, L"launcher\\setup.log");
    swprintf(cmd, MAX_PATH * 3,
             L"cmd.exe /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%ls\" > \"%ls\" 2>&1", script, log);
    STARTUPINFOW si;
    memset(&si, 0, sizeof(si));
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi;
    DWORD code = 1;
    if (CreateProcessW(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, sRoot, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 10 * 60 * 1000);
        GetExitCodeProcess(pi.hProcess, &code);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }
    PostMessageW(sWindow, WM_SETUP_DONE, (WPARAM) code, 0);
    return 0;
}

static void show_setup_problem(void) {
    wchar_t log[MAX_PATH];
    path_in_root(log, L"launcher\\setup.log");
    char text[2048] = { 0 };
    FILE *f = _wfopen(log, L"rb");
    if (f != NULL) {
        size_t n = fread(text, 1, sizeof(text) - 1, f);
        text[n] = '\0';
        fclose(f);
    }
    wchar_t wtext[2048], msg[2400];
    MultiByteToWideChar(CP_ACP, 0, text, -1, wtext, 2048);
    swprintf(msg, 2400, L"Minecraft's side couldn't be set up:\n\n%ls\n(All of it is in launcher\\setup.log.)", wtext);
    MessageBoxW(sWindow, msg, L"MarioCraft", MB_ICONWARNING);
}

static void play_after_setup(DWORD code) {
    EnableWindow(sPlay, TRUE);
    EnableWindow(sAccount, TRUE);
    if (code != 0) {
        set_status(L"Setup didn't work. See the message.");
        show_setup_problem();
        return;
    }
    wchar_t sm64[MAX_PATH], sm64Dir[MAX_PATH], prism[MAX_PATH];
    path_in_root(sm64, L"sm64coopdx\\build\\us_pc\\sm64coopdx.exe");
    path_in_root(sm64Dir, L"sm64coopdx\\build\\us_pc");
    if (GetFileAttributesW(sm64) == INVALID_FILE_ATTRIBUTES) {
        set_status(L"SM64 isn't built yet.");
        MessageBoxW(sWindow, L"SM64 isn't built yet (sm64coopdx\\build\\us_pc\\sm64coopdx.exe).\n\n"
                             L"Build it with install.bat in the MarioCraft folder (see README.md).",
                    L"MarioCraft", MB_ICONWARNING);
        return;
    }
    if (!minecraft_running()) {
        if (!prism_path(prism)) {
            set_status(L"Prism Launcher wasn't found.");
            MessageBoxW(sWindow, L"Prism Launcher wasn't found. Install it from prismlauncher.org and sign in once.", L"MarioCraft", MB_ICONWARNING);
            return;
        }
        if (!start(prism, L"--launch MarioCraft", NULL)) {
            set_status(L"Couldn't start Prism Launcher.");
            return;
        }
    }
    if (!process_running(L"sm64coopdx.exe") && !start(sm64, L"", sm64Dir)) {
        set_status(L"Couldn't start SM64.");
        return;
    }
    set_status(L"Starting... Minecraft loads in the background (the first time, Prism may ask you to sign in).");
    SetTimer(sWindow, 1, 4000, NULL);  // then get out of the way
}

static void on_play(void) {
    EnableWindow(sPlay, FALSE);
    EnableWindow(sAccount, FALSE);
    set_status(L"Getting Minecraft's side ready...");
    HANDLE t = CreateThread(NULL, 0, setup_thread, NULL, 0, NULL);
    if (t != NULL) {
        CloseHandle(t);
    } else {
        play_after_setup(1);
    }
}

static void on_account(void) {
    wchar_t prism[MAX_PATH];
    if (!prism_path(prism)) {
        // Not set up yet: setup-prism.ps1 finds Prism; until then try where its installer puts it.
        wchar_t local[MAX_PATH];
        ExpandEnvironmentStringsW(L"%LOCALAPPDATA%\\Programs\\PrismLauncher\\prismlauncher.exe", local, MAX_PATH);
        wcscpy(prism, local);
    }
    if (!start(prism, L"", NULL)) {
        MessageBoxW(sWindow, L"Prism Launcher wasn't found. Install it from prismlauncher.org.", L"MarioCraft", MB_ICONWARNING);
        return;
    }
    set_status(L"In Prism: Accounts (top right) to sign in or switch. Your skin comes from that account.");
}

static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_COMMAND:
            if (LOWORD(wp) == ID_PLAY) on_play();
            if (LOWORD(wp) == ID_ACCOUNT) on_account();
            return 0;
        case WM_SETUP_DONE:
            play_after_setup((DWORD) wp);
            return 0;
        case WM_TIMER:
            KillTimer(hwnd, 1);
            DestroyWindow(hwnd);
            return 0;
        case WM_CTLCOLORSTATIC: {
            HDC dc = (HDC) wp;
            SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, RGB(235, 235, 235));
            return (LRESULT) GetStockObject(NULL_BRUSH);
        }
        case WM_ERASEBKGND: {
            RECT r;
            GetClientRect(hwnd, &r);
            HBRUSH b = CreateSolidBrush(RGB(32, 36, 44));
            FillRect((HDC) wp, &r, b);
            DeleteObject(b);
            return 1;
        }
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, LPWSTR cmdLine, int show) {
    (void) prev;
    (void) cmdLine;
    GetModuleFileNameW(NULL, sRoot, MAX_PATH);
    wchar_t *slash = wcsrchr(sRoot, L'\\');
    if (slash != NULL) {
        *slash = L'\0';
    }
    WNDCLASSW wc = { 0 };
    wc.lpfnWndProc = window_proc;
    wc.hInstance = inst;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wc.lpszClassName = L"MarioCraftLauncher";
    RegisterClassW(&wc);

    RECT r = { 0, 0, 460, 210 };
    DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
    AdjustWindowRect(&r, style, FALSE);
    sWindow = CreateWindowW(wc.lpszClassName, L"MarioCraft", style, CW_USEDEFAULT, CW_USEDEFAULT,
                            r.right - r.left, r.bottom - r.top, NULL, NULL, inst, NULL);

    sFont = CreateFontW(-15, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    sTitleFont = CreateFontW(-30, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    HWND title = CreateWindowW(L"STATIC", L"MarioCraft", WS_CHILD | WS_VISIBLE, 24, 18, 400, 40, sWindow, NULL, inst, NULL);
    HWND sub = CreateWindowW(L"STATIC", L"Super Mario 64, played as Steve.", WS_CHILD | WS_VISIBLE, 26, 58, 400, 22, sWindow, NULL, inst, NULL);
    sPlay = CreateWindowW(L"BUTTON", L"Play", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON, 24, 96, 140, 40, sWindow, (HMENU) ID_PLAY, inst, NULL);
    sAccount = CreateWindowW(L"BUTTON", L"Minecraft account...", WS_CHILD | WS_VISIBLE | WS_TABSTOP, 176, 96, 170, 40, sWindow, (HMENU) ID_ACCOUNT, inst, NULL);
    sStatus = CreateWindowW(L"STATIC", L"Your skin comes from the account signed in to Prism Launcher.", WS_CHILD | WS_VISIBLE,
                            24, 150, 412, 44, sWindow, (HMENU) ID_STATUS, inst, NULL);
    SendMessageW(title, WM_SETFONT, (WPARAM) sTitleFont, TRUE);
    HWND normal[] = { sub, sPlay, sAccount, sStatus };
    for (int i = 0; i < 4; i++) {
        SendMessageW(normal[i], WM_SETFONT, (WPARAM) sFont, TRUE);
    }

    ShowWindow(sWindow, show);
    UpdateWindow(sWindow);
    SetFocus(sPlay);

    MSG m;
    while (GetMessageW(&m, NULL, 0, 0) > 0) {
        if (!IsDialogMessageW(sWindow, &m)) {
            TranslateMessage(&m);
            DispatchMessageW(&m);
        }
    }
    DeleteObject(sFont);
    DeleteObject(sTitleFont);
    return 0;
}
