@echo off
rem Opens the Solarpunk Valkyrie project in the Godot 4.6 editor.
rem Set the GODOT environment variable to your Godot 4.6 executable,
rem or edit the default path below.
if not defined GODOT set "GODOT=C:\Users\Uncertainty\Desktop\Godot\Godot_v4.6.1-stable_win64.exe"
if not exist "%GODOT%" (
  echo Could not find Godot at: %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --editor --path "%~dp0.."
