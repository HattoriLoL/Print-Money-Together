# Abre o jogo com o Godot da Steam, direto na kitnet.
#
#   .\tools\play.ps1                  sozinho, partida normal
#   .\tools\play.ps1 fuga             cenário: dinheiro à vista e o vizinho vindo bater na porta
#   .\tools\play.ps1 fuga -Online     o mesmo, hospedando a sala (os amigos entram pelo IP)
#
# Os cenários estão em scripts/scenarios.gd.

param(
    [string]$Scenario = "",
    [switch]$Online,
    [string]$Name = "Player"
)

$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$root = Split-Path -Parent $PSScriptRoot

$gameArgs = @("--path", $root, "--", "--name=$Name")
$gameArgs += $(if ($Online) { "--host" } else { "--solo" })
if ($Scenario -ne "") { $gameArgs += "--scenario=$Scenario" }

& $godot @gameArgs
