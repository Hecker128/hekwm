; This program is free software: you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation, either version 3 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with
; this program. If not, see <https://www.gnu.org/licenses/>.

#requires AutoHotkey v2.0
#warn all
#singleinstance force
#notrayicon
A_MaxHotkeysPerInterval := 200


global Manual_colemak_remaps_enable := true
global Sticky_rshift_enable := false
global Arrowkeys_mouse_remap_enable := false
global Fast_backspace_enable := false
global Window_management_enable := true

global Sticky_rshift_active := false

; Stores the index of the active workspace, starting at 1.
global Active_workspace_index

; Stores information about all workspaces.
global Workspaces

; Gui object for the shell-hook window.
; Needs to be global so it doesn't get assassinated by GC.
global Shell_hook_gui

global Hekwm_src_path := "C:\Users\naem\Documents\AutoHotkey"
global Workspace_wallpapers_path := Hekwm_src_path . "\assets\wallpapers"

class Workspace
{
	hwnds := Array()
	minimized_hwnds := Array()
	unminimized_hwnds := Array()
	is_active := false

	; Store the amount of unminimized windows this workspace's window
	; positioning is configured for. Used to re-position the windows when
	; this changes but the windows can't be re-positioned automatically.
	n_unminimized_hwnds_recognized := 0

	; By default, set the wallpaper path to the path to this user's current
	; wallpaper.
	wallpaper := a_appdata . "\Microsoft\Windows\Themes\TranscodedWallpaper"


	;
	; The instance creation function.
	; Empty for now.
	;
	call()
	{}


	activate()
	{
		; Show all windows on this workspace.
		loop (this.unminimized_hwnds.length) {
			dllcall("User32.dll\PostMessageW",
				"Ptr", this.unminimized_hwnds[a_index],
				"UInt", 0x0112, "Ptr", 0xF120, "Ptr", 0)
		}
		
		; Set the wallpaper to the wallpaper of this workspace.
		; We won't check for errors here because it's just a wallpaper,
		; not really that important.
		dllcall("SystemParametersInfo", "UInt", 0x14, "UInt", 0,
			"Str", this.wallpaper, "UInt", 1)
	
		; Reposition this workspace's windows if needed.
		if (this.n_unminimized_hwnds_recognized != this.unminimized_hwnds.length)
			this.reposition_windows()
		
		this.is_active := true
	}


	deactivate()
	{
		; Minimize all windows on this workspace.
		loop (this.unminimized_hwnds.length) {
			dllcall("User32.dll\PostMessageW",
				"Ptr", this.unminimized_hwnds[a_index],
				"UInt", 0x0112, "Ptr", 0xF020, "Ptr", 0)
		}
		
		this.is_active := false
	}


	;
	; Re-positions all windows in this workspace based on the current amount
	; of un-minimized windows in this workspace.
	; May not be called if this workspace isn't active.
	;
	reposition_windows()
	{
		; Check to avoid divide-by-zero if there are no un-minimized
		; windows on this workspace.
		if (this.unminimized_hwnds.length == 0)
			return

		win_width_x := integer(
			A_screenwidth / this.unminimized_hwnds.length)

		loop (this.unminimized_hwnds.length) {
			start_x := (a_index - 1) * win_width_x

			win := {hwnd: this.unminimized_hwnds[a_index]}
			try {
				winmove(start_x, 0, win_width_x,
					A_screenheight, win)
			} catch {
				this.unregister_window_unminimized(
					this.unminimized_hwnds[a_index])
				return
			}
		}

		n_unminimized_hwnds_recognized := this.unminimized_hwnds.length
	}


	;
	; Registers an un-minimized window (@hwnd) and, if this workspace is
	; active, repositions its windows.
	;
	register_window_unminimized(hwnd)
	{
		this.hwnds.push(hwnd)
		this.unminimized_hwnds.push(hwnd)

		if (this.is_active)
			this.reposition_windows()
	}


	;
	; Un-registers an un-minimized window (@hwnd) and, if this workspace is
	; active, repositions its windows.
	;
	unregister_window_unminimized(hwnd)
	{
		this.hwnds.removeat(array_index_of(this.hwnds, hwnd))
		this.unminimized_hwnds.removeat(
			array_index_of(this.unminimized_hwnds, hwnd))

		if (this.is_active) {
			if (winexist({hwnd: hwnd})) {
				dllcall("User32.dll\PostMessageW",
					"Ptr", hwnd, "UInt", 0x0112,
					"Ptr", 0xF020, "Ptr", 0)
			}
			this.reposition_windows()
		}
	}


	;
	; Un-minimizes this workspace's last minimized window.
	; May not be called if this workspace isn't active.
	;
	unminimize_last()
	{
		; If this workspace has no minimized windows, return.
		if (this.minimized_hwnds.Length == 0)
			return

		hwnd_unmin := this.minimized_hwnds.Pop()

		; Un-minimize the window.
		dllcall("User32.dll\PostMessageW", "Ptr", hwnd_unmin, "UInt", 0x0112,
			"Ptr", 0xF120, "Ptr", 0)

		this.unminimized_hwnds.Push(hwnd_unmin)

		this.reposition_windows()
	}
}


; 8 backspaces for when you wanna backspace fast without deleting entire words.
#hotif (Fast_backspace_enable)
	<^>!a::backspace
	<^>!r::backspace
	<^>!s::backspace
	<^>!t::backspace
	<^>!n::backspace
	<^>!e::backspace
	<^>!i::backspace
	<^>!o::backspace
#hotif

; Reverse colon and semicolon, but keep the original 'AltGr+(;)' to 'ö' mapping.
#hotif (!Sticky_rshift_active)
	`;:::
#hotif
+`;::`;
<^>!`;::ö
<^>!+`;::Ö

; Map AltGr+Shift+` to the section symbol.
<^>!+vkC0::sendevent("§")

; Arrowkeys
#h::Left
#j::Down
#k::Up
#l::Right

; Jump between, select and delete words
#b::sendevent("^{left}")
#e::sendevent("^{right}")
#+b::sendevent("^+{left}")
#+e::sendevent("^+{right}")
#^b::sendevent("^+{left}{delete}")
#^e::sendevent("^+{right}{delete}")

; Scroll
#+h::sendevent("{wheelright}")
#+j::sendevent("{wheeldown}")
#+k::sendevent("{wheelup}")
#+l::sendevent("{wheelleft}")

; PgUp/PgDn
#^k::PgUp
#^j::PgDn

; End/Home
#+4::End
#+6::Home

; Undo
#u::sendevent("^z")

; Switch workspace
#1::switch_workspace(1)
#2::switch_workspace(2)
#3::switch_workspace(3)

; Move workspace
#+1::move_focused_window_to_workspace(1)
#+2::move_focused_window_to_workspace(2)
#+3::move_focused_window_to_workspace(3)

; Launch programs
#<^>!s::run("C:\Users\naem\AppData\Local\Programs\Vieb\Vieb.exe")
#<^>!t::run("wezterm-gui.exe")
#<^>!e::run("wezterm.exe start -- nvim C:\Users\naem", , "Hide")
#<^>!+e::run("explorer.exe C:\Users\naem")

; Kill active window
#w::
{
	if (!(wingetprocesspath("A") = A_windir . "\explorer.exe"
	      && wingetclass("A") = "Progman"))
		winkill("A")
}

; Minimize/unminimize windows
#m::minimize_focused_window()
#+m::Workspaces[Active_workspace_index].unminimize_last()

; Debug stuff
#Esc::rebuild_self()
#+Esc::exitapp()

; Force-reposition windows
#r::Workspaces[Active_workspace_index].reposition_windows()

; Toggle manual-colemak-remaps mode
#+F1::global Manual_colemak_remaps_enable := !Manual_colemak_remaps_enable

; Toggle sticky-rshift mode
#+F2::global Sticky_rshift_enable := !Sticky_rshift_enable

#+F3::global Arrowkeys_mouse_remap_enable := !Arrowkeys_mouse_remap_enable

#+F4::global Fast_backspace_enable := !Fast_backspace_enable

#+F5::global Window_management_enable := !Window_management_enable


;
; Should be run immediately when this script is started, to initialize stuff.
;
init()
{
	persistent()
	setkeydelay(-1)

	; Create the workspaces.
	global Workspaces
	Workspaces := [Workspace(), Workspace(), Workspace()]

	hwnds_all := wingetlist()

	; Assign all currently existing windows (except for the Windows taskbar) to
	; workspace 1.
	loop (hwnds_all.Length) {
		wnd_obj := {hwnd: hwnds_all[a_index]}

		if (should_ignore_window(wnd_obj))
			continue
		
		Workspaces[1].hwnds.push(hwnds_all[a_index])

		if (dllcall("User32.dll\IsIconic", "Ptr", hwnds_all[a_index]))
			Workspaces[1].minimized_hwnds.push(hwnds_all[a_index])
		else
			Workspaces[1].unminimized_hwnds.push(hwnds_all[a_index])
	}

	Workspaces[1].wallpaper := Workspace_wallpapers_path . "\0.png"
	Workspaces[2].wallpaper := Workspace_wallpapers_path . "\1.png"
	Workspaces[3].wallpaper := Workspace_wallpapers_path . "\2.png"

	Workspaces[1].activate()
	Workspaces[1].reposition_windows()

	global Active_workspace_index
	Active_workspace_index := 1

	; Set up shell_event_callback as a shell hook.
	global Shell_hook_gui
	Shell_hook_gui := Gui()
	shell_hook_hwnd := Shell_hook_gui.hwnd
	dllcall("RegisterShellHookWindow", "ptr", shell_hook_hwnd)
	shell_hook_msg_id := dllcall("RegisterWindowMessage",
		"Str", "SHELLHOOK", "UInt")
	onmessage(shell_hook_msg_id, shell_event_callback)
}


;
; Returns the index of @item in @arr, or 0 if it's not present.
;
array_index_of(arr, item)
{
	loop (arr.Length) {
		if (arr[a_index] == item)
			return a_index
	}

	return 0
}


;
; Callback for shell events.
;
shell_event_callback(w_param, l_param, *)
{
	global Window_management_enable
	if (!Window_management_enable)
		return

	switch (w_param) {
	; HSHELL_WINDOWCREATED
	case 1:
	if (!should_ignore_window(l_param))
		Workspaces[Active_workspace_index]
			.register_window_unminimized(l_param)

	; HSHELL_WINDOWDESTROYED
	case 2:
	unregister_window_global(l_param)	
	}
}


;
; Returns true if wnd_obj should be ignored (that is, not be passed to
; register_window_<x> functions.
;
should_ignore_window(wnd_obj)
{
	proc_path := wingetprocesspath(wnd_obj)
	wnd_class := wingetclass(wnd_obj)

	return (proc_path = A_windir . "\explorer.exe"
	     	&& (wnd_class = "Progman" || ; Desktop window (?).
		    wnd_class = "XamlExplorerHostIslandWindow_WASDK" ||
		    wnd_class = "ApplicationFrameWindow" ||
		    wnd_class = "OperationStatusWindow" ||
		    wnd_class = "Shell_TrayWnd")) || ; Taskbar window.

	       (proc_path = "C:\Program Files (x86)\Windows Media Player\wmplayer.exe"
		&& wnd_class = "IME") ||

	       ((proc_path) = "C:\Windows\System32\ApplicationFrameHost.exe"
		&& wnd_class = "ApplicationFrameWindow") ||

	       ((proc_path) = "C:\Windows\SystemApps\ShellExperienceHost_cw5n1h2txyewy\ShellExperienceHost.exe"
		&& wnd_class = "Windows.UI.Core.CoreWindow") ||

	       ((proc_path) = "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\SearchHost.exe"
		&& wnd_class = "Windows.UI.Core.CoreWindow") ||

	       ((proc_path) = "C:\Windows\ImmersiveControlPanel\SystemSettings.exe"
		&& wnd_class = "Windows.UI.Core.CoreWindow") ||

	       (substr(proc_path, 1, 56) = "C:\Program Files\WindowsApps\Microsoft.XboxGamingOverlay"
		&& wnd_class = "Windows.UI.Core.CoreWindow")
}


;
; @index_new - The index of the workspace to switch to, starting from 1.
;
switch_workspace(index_new)
{
	global Active_workspace_index

	Workspaces[Active_workspace_index].deactivate()
	Workspaces[index_new].activate()

	Active_workspace_index := index_new
}


;
; Unregisters the window @hwnd from all workspaces.
; If @hwnd is not present in any workspaces, this function does nothing.
;
unregister_window_global(hwnd)
{
	loop (3) {
		index_norm := array_index_of(Workspaces[a_index].hwnds, hwnd)

		if (index_norm == 0)
			continue

		Workspaces[a_index].hwnds.removeat(index_norm)

		index_minim := array_index_of(
			Workspaces[a_index].minimized_hwnds, hwnd)
		index_unmin := array_index_of(
			Workspaces[a_index].unminimized_hwnds, hwnd)

		if (index_minim != 0) {
			Workspaces[a_index].minimized_hwnds.removeat(
				index_minim)
		} else {
			Workspaces[a_index].unminimized_hwnds.removeat(
				index_unmin)
			Workspaces[a_index].reposition_windows()
		}

		return
        }
}


minimize_focused_window()
{
	hwnd_minimize := get_active_window_movable_minimizable()

	if (hwnd_minimize == 0)
		return

	; Minimize the currently focused window.
	dllcall("User32.dll\PostMessageW",
		"Ptr", hwnd_minimize, "UInt", 0x0112,
		"Ptr", 0xF020, "Ptr", 0)

	; Inform the active workspace that this window has been minimized.
	Workspaces[Active_workspace_index].minimized_hwnds.push(hwnd_minimize)
	Workspaces[Active_workspace_index].unminimized_hwnds.removeat(
		array_index_of(Workspaces[Active_workspace_index]
					.unminimized_hwnds, hwnd_minimize))
	Workspaces[Active_workspace_index].reposition_windows()
}


;
; Returns the active window if it's movable and minimizable (in the active
; workspace and not minimized).
;
get_active_window_movable_minimizable()
{
	; Get a handle to the currently focused window, if present.
	hwnd := winexist("A")

	; The currently focused window should be in the active workspace as an
	; un-minimized hwnd.
	index := array_index_of(Workspaces[Active_workspace_index]
					.unminimized_hwnds, hwnd)
	
	; If no window is currently focused or the currently focused window is
	; not in the current workspace (somehow), return.
	if ((hwnd == 0) || (index == 0))
		return 0

	return hwnd
}


;
; Tries to move the currently focused window, if present, to workspace index @n.
;
move_focused_window_to_workspace(n)
{
	hwnd_move := get_active_window_movable_minimizable()

	if (hwnd_move == 0)
		return

	; Move the window from the active workspace to workspace index @n.
	Workspaces[Active_workspace_index].unregister_window_unminimized(
		hwnd_move)
	Workspaces[n].register_window_unminimized(hwnd_move)
}


;
; Tries to rebuild HEKWM itself and, if the build is successful, run the new
; executable. If the build is unsuccessful, re-run the old executable.
; For this to work, the script must already be compiled and AutoHotKey must be
; installed system-wide along with ahk2exe.
; If the above requirements are not met, this function throws an error.
;
rebuild_self()
{
	if (!A_iscompiled)
		throw Error("HEKWM must be compiled to rebuild self")

	ahk_install_dir := regread("HKLM\SOFTWARE\AutoHotkey", "InstallDir", "")

	if (!ahk_install_dir)
		throw Error("AHK must be installed system-wide to rebuild self")

	run(Hekwm_src_path . "\scripts\rebuild_self.bat " . Hekwm_src_path)
	exitapp()
}


#F1::unregister_at_active_workspace(1)
#F2::unregister_at_active_workspace(2)
#F3::unregister_at_active_workspace(3)
#F4::unregister_at_active_workspace(4)
#F5::unregister_at_active_workspace(5)
#F6::unregister_at_active_workspace(6)
#F7::unregister_at_active_workspace(7)
#F8::unregister_at_active_workspace(8)

#<^>!F1::identify_at_active_workspace(1)
#<^>!F2::identify_at_active_workspace(2)
#<^>!F3::identify_at_active_workspace(3)
#<^>!F4::identify_at_active_workspace(4)
#<^>!F5::identify_at_active_workspace(5)
#<^>!F6::identify_at_active_workspace(6)
#<^>!F7::identify_at_active_workspace(7)


;
; Debug function for identifying windows (eg to exclude them from this wm).
;
identify_at_active_workspace(window_index)
{
	win := Workspaces[Active_workspace_index]
			.unminimized_hwnds[window_index]

	msgbox(wingetprocesspath(win) . "`n" . wingetclass(win))
}


;
; For when I don't want invisible windows in my face.
;
unregister_at_active_workspace(window_index)
{
	if (Workspaces[Active_workspace_index].unminimized_hwnds.length >=
		window_index)
	{
		Workspaces[Active_workspace_index
			].unregister_window_unminimized(
				Workspaces[Active_workspace_index
					].unminimized_hwnds[window_index])
	}
}


#hotif (Manual_colemak_remaps_enable)
	CapsLock::Esc
	=::CapsLock
	-::=
	+0::) ; Fix some weird bug (no idea why it's a thing)
#hotif


#hotif (Sticky_rshift_enable)
	RShift::global Sticky_rshift_active := !Sticky_rshift_active
#hotif


sticky_rshift_on_key(key)
{
	sendevent(key)
	global Sticky_rshift_active := false
}


; Shitty code warning
#hotif (Sticky_rshift_enable && Sticky_rshift_active)
	a::sticky_rshift_on_key("+a")
	b::sticky_rshift_on_key("+b")
	c::sticky_rshift_on_key("+c")
	d::sticky_rshift_on_key("+d")
	e::sticky_rshift_on_key("+e")
	f::sticky_rshift_on_key("+f")
	g::sticky_rshift_on_key("+g")
	h::sticky_rshift_on_key("+h")
	i::sticky_rshift_on_key("+i")
	j::sticky_rshift_on_key("+j")
	k::sticky_rshift_on_key("+k")
	l::sticky_rshift_on_key("+l")
	m::sticky_rshift_on_key("+m")
	n::sticky_rshift_on_key("+n")
	o::sticky_rshift_on_key("+o")
	p::sticky_rshift_on_key("+p")
	q::sticky_rshift_on_key("+q")
	r::sticky_rshift_on_key("+r")
	s::sticky_rshift_on_key("+s")
	t::sticky_rshift_on_key("+t")
	u::sticky_rshift_on_key("+u")
	v::sticky_rshift_on_key("+v")
	w::sticky_rshift_on_key("+w")
	x::sticky_rshift_on_key("+x")
	y::sticky_rshift_on_key("+y")
	z::sticky_rshift_on_key("+z")
	1::sticky_rshift_on_key("+1")
	2::sticky_rshift_on_key("+2")
	3::sticky_rshift_on_key("+3")
	4::sticky_rshift_on_key("+4")
	5::sticky_rshift_on_key("+5")
	6::sticky_rshift_on_key("+6")
	7::sticky_rshift_on_key("+7")
	8::sticky_rshift_on_key("+8")
	9::sticky_rshift_on_key("+9")
	0::sticky_rshift_on_key("+0")
	.::sticky_rshift_on_key("+.")
	,::sticky_rshift_on_key("+,")
	-::sticky_rshift_on_key("+-")
	=::sticky_rshift_on_key("+=")
	/::sticky_rshift_on_key("+/")
	\::sticky_rshift_on_key("+\")
	[::sticky_rshift_on_key("+[")
	]::sticky_rshift_on_key("+]")
	`;::sticky_rshift_on_key(";")
#hotif

#hotif (Arrowkeys_mouse_remap_enable)
	Left::MouseMove(-20, 0, 0, "R")
	Right::MouseMove(20, 0, 0, "R")
	Up::MouseMove(0, -20, 0, "R")
	Down::MouseMove(0, 20, 0, "R")
	+Left::MouseMove(-120, 0, 0, "R")
	+Right::MouseMove(120, 0, 0, "R")
	+Up::MouseMove(0, -120, 0, "R")
	+Down::MouseMove(0, 120, 0, "R")
#hotif


; Entry-point.
init()
