@echo off
setlocal
cd /d "%~dp0"

REM Repo root = tool/mcp_idle_party/../..
for %%I in ("%~dp0..\..") do set "REPO_ROOT=%%~fI"
if not defined IDLE_PARTY_ROOT set "IDLE_PARTY_ROOT=%REPO_ROOT%"
set "PYTHONWARNINGS=ignore"

if not exist ".venv\Scripts\python.exe" (
  py -3 -m venv .venv
  ".venv\Scripts\pip.exe" install -r requirements.txt
)
".venv\Scripts\python.exe" -c "from mcp.server.fastmcp import FastMCP" 1>nul 2>nul
if errorlevel 1 (
  ".venv\Scripts\pip.exe" install -r requirements.txt
)

REM Prefer direct python (no cmd echo); keep process on stdio for Cursor.
".venv\Scripts\python.exe" -u "%~dp0server.py"
