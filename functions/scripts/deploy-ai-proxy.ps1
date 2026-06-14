# Deploy AI proxy function + RTDB rules.
# Prerequisites: firebase login, secrets set (see below).
#
#   firebase functions:secrets:set AI_OPENAI_API_KEY
#   firebase functions:secrets:set AI_GEMINI_API_KEY
#   firebase functions:secrets:set AI_AZURE_SPEECH_KEY
#
# Seed RTDB config (requires RTDB write access via service account or Console):
#   Upload functions/ai_server_config.seed.json to /ai_server_config in Firebase Console
#
# Register App Check debug token (debug builds only):
#   Firebase Console -> App Check -> Apps -> Manage debug tokens

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
Set-Location ..

Write-Host "Deploying aiRequest + database rules..."
firebase deploy --only "functions:aiRequest,database"

Write-Host "Done. Rotate any API keys that were previously committed to source control."
