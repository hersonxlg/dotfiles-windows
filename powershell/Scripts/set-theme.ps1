
param(
    [string]$theme_name
)

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\\${theme_name}.omp.json" | Invoke-Expression
