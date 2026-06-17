# Deploy AI proxy + episode push functions + RTDB rules (VOA project).
# Prerequisites: firebase login, Blaze billing, secrets set (see below).
#
#   firebase use voa-learning-english-c75fe
#   firebase functions:secrets:set AI_OPENAI_API_KEY
#   firebase functions:secrets:set AI_GEMINI_API_KEY
#   firebase functions:secrets:set AI_AZURE_SPEECH_KEY
#
# Seed RTDB config (requires RTDB write access via service account or Console):
#   Upload functions/ai_server_config.seed.json to /ai_server_config in Firebase Console
#
# Register App Check debug token (debug builds only):
#   Firebase Console -> App Check -> Apps -> Manage debug tokens
#
# FCM: app subscribes to topic "episodes" (see push_notification_service.dart)

$ErrorActionPreference = "Stop"
# Windows: tránh timeout khi CLI phân tích code functions (10s mặc định).
if (-not $env:FUNCTIONS_DISCOVERY_TIMEOUT) {
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = "120"
}
Set-Location (Split-Path $PSScriptRoot -Parent)
Set-Location ..

Write-Host "Deploying aiRequest, onEpisodeCreatedWithYear, onEpisodeCreatedFlat + database rules..."
firebase deploy --only "functions:aiRequest,functions:onEpisodeCreatedWithYear,functions:onEpisodeCreatedFlat,database"

Write-Host "Done. Rotate any API keys that were previously committed to source control."
