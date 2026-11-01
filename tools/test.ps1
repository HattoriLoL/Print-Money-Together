# Roda o teste da kitnet (tools/tests/test_kitnet.gd) com o Godot da Steam.
#
#   .\tools\test.ps1                       a suíte inteira (uns 12 minutos)
#   .\tools\test.ps1 escada,vizinho        só essas partes (a perseguição do vizinho: uns 2 minutos)
#   .\tools\test.ps1 escada,vizinho -Client  com uma segunda janela entrando na sala
#
# As partes estão em docs/kitnet.md (Teste). Os prints vão para a pasta temporária do Windows
# (%TEMP%\print_money_test), fora do projeto: dentro dele, o Godot importaria cada print.

# O PowerShell lê "escada,vizinho" como uma lista: chega aqui como várias partes.
param(
    [string[]]$Only = @(),
    [switch]$Client
)

# O Godot escreve em UTF-8 (sem isso, "não" aparece como "n├úo").
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $env:TEMP "print_money_test"

$testArgs = @("--path", $root, "--resolution", "1280x720", "--script", "res://tools/tests/test_kitnet.gd", "--", "--out=$out")
if ($Only.Count -gt 0) { $testArgs += "--only=" + ($Only -join ",") }
if ($Client) { $testArgs += "--client" }

& $godot @testArgs 2>&1 | Where-Object { "$_" -match "^(  ok  |FALHOU|TESTE OK|FALHAS|  - |--- parte|SCRIPT ERROR)" }
