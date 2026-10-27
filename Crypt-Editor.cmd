@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Dev.ps1" DungeonEditor -DungeonFile res://assets/data/custom_dungeons/dungeon_crypt_of_the_damned.json
if errorlevel 1 pause
