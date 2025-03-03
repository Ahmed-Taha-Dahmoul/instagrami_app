# Define paths
$envRoot = "$PSScriptRoot"
$venvPath = "$envRoot\venv"
$pythonPath = "$envRoot\portable_python\python.exe"

# ✅ Set environment variables
$env:VIRTUAL_ENV = $venvPath
$env:PATH = "$venvPath\Scripts;$envRoot\portable_python;" + $env:PATH
$env:PYTHONHOME = ""  # Unset any global Python installation

Write-Host "✅ Virtual environment activated with updated paths!"

# ✅ Start a new PowerShell session inside the virtual environment
& "$pythonPath" -m venv "$venvPath"

# ✅ Activate the environment automatically
& "$venvPath\Scripts\Activate.ps1"
