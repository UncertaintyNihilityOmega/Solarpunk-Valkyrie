@echo off
rem Plays Solarpunk Valkyrie with Godot 4.6.
rem Set the GODOT environment variable to your Godot 4.6 executable,
rem or edit the default path below.
if not defined GODOT set "GODOT=C:\Users\Uncertainty\Desktop\Godot\Godot_v4.6.1-stable_win64.exe"
if not exist "%GODOT%" (
  echo Could not find Godot at: %GODOT%
  echo Install Godot 4.6 from https://godotengine.org and set GODOT to its .exe,
  echo or edit this file.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0.."
