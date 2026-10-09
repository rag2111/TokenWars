# Troubleshooting — Token Wars

Start every investigation with `python -m tokenwars doctor` / `dotnet run -- doctor`: it prints ROOT, the configured
models, which keys are present, and makes a test call to every chat model with a 64-token output budget.
This leaves room for the short "OK" reply to finish; a one-token cap can cause an output-limit HTTP 400.
Embedding probes and normal run output limits are unchanged.

## Deployment (Terraform)

| Symptom | Cause | Fix |
|---|---|---|
| `InsufficientQuota` / "exceeds the available quota" on `azurerm_cognitive_deployment` | TPM quota per subscription + region + model + SKU is exhausted (often shared by several teams in one subscription). | Lower `capacity` in `terraform.tfvars` (e.g. `frontier_model = { capacity = 100 }`), request more quota (Foundry portal > Quota), use another region or a separate subscription per team. |
| `DeploymentModelNotSupported` / "model ... not available in region" / `InvalidResourceProperties` | Model/version/SKU not offered in that region, or the model is deprecated for new deployments (e.g. the GPT-4.1 family in 2026). | `az cognitiveservices model list --location <region> -o table`; adjust `name`/`version`/`sku` (e.g. `DataZoneStandard`, `Standard`) or `location`. Defaults are gpt-5.6-sol / gpt-5.6-terra / gpt-5.6-luna, all version 2026-07-09. When switching model family, also set `pricing_key` (+ price in `pricing.json`), `max_tokens_param`, `supports_temperature` and `extra_body` (GPT-4.1 block in `terraform.tfvars.example`). |
| Llama deployment fails with a format/version error | Catalog version numbers change. | Keep `open_model.version = null` (default version) and `format = "Meta"`; or disable with `deploy_open_model = false`. |
| `RequestConflict` / "Another operation is being performed" | Parallel operations on one Foundry resource. | Deployments are chained with `depends_on`; just re-run `terraform apply`. |
| Custom subdomain / name already taken | Soft-deleted account with the same name. | The provider purges on destroy; otherwise `az cognitiveservices account list-deleted` + `az cognitiveservices account purge`. |
| APIM takes long | v2 tiers typically 5–15 min; classic Developer/Basic 30–60 min. | Keep `BasicV2_1`. Deploy the day before or during kickoff; teams can start Challenge 1 without APIM (`use_gateway: false`). |
| APIM "soft-deleted service with the same name exists" | Previous destroy without purge. | `recover_soft_deleted`/purge are enabled in the provider; else `az apim deletedservice purge --service-name <name> --location <region>`. |
| `subscription_id` / "a subscription ID must be configured" | azurerm 4.x / 5.x needs an explicit subscription. | `export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)` or set `subscription_id` in tfvars. |
| `terraform init`: "locked provider registry.terraform.io/hashicorp/azurerm 4.x does not match configured version constraint ~> 5.8" (or "Inconsistent dependency lock file") | Lock file from an older checkout (azurerm 4.x). | `terraform init -upgrade`. If a team must stay on 4.x: follow the fallback comment in `infra/providers.tf` (`~> 4.81`, remove `resource_providers_to_register` and `logs_destination`). |
| `MissingSubscriptionRegistration` / "The subscription is not registered to use namespace 'Microsoft.…'" or `resource_providers_to_register` fails with `AuthorizationFailed` | azurerm 5.x registers **no** providers by default; the kit registers `Microsoft.CognitiveServices`, `Microsoft.ApiManagement`, `Microsoft.OperationalInsights`, `Microsoft.Insights`, `Microsoft.App`, which needs Owner/Contributor on the subscription. | Run as Owner/Contributor, or register manually: `az provider register --namespace <ns>` (check with `az provider show -n <ns> --query registrationState`), then re-apply. |
| Unsupported argument `resource_providers_to_register` / `logs_destination` | Running the 5.x configuration with azurerm 4.x. | `terraform init -upgrade` (pin is `~> 5.8`). |
| `foundry_project_endpoint` looks like `https://<sub>.services.ai.azure.com/api/projects/<proj>` | The `"AI Foundry API"` key was not found in the project's `endpoints` map (VALIDATE); the output fell back. | Informational only — the apps use `ai_base_url`. Check `terraform output foundry_project_endpoints`. |
| `AuthorizationFailed` on `azurerm_role_assignment` | Contributor cannot create role assignments. | Needs Owner or User Access Administrator; or ask the coach to pre-create the assignments / set `deploy_apim = false`. |
| Policy error "Resource ... disallowed by policy" or `disableLocalAuth` enforced | Organisation Azure Policy (no public network / no local auth / allowed regions). | Use a sandbox subscription. If local auth is forced off, the apps' API keys won't work: use the APIM gateway only (`use_gateway: true`, APIM uses managed identity), which requires `via_gateway: true` models. |

## Fireworks on Foundry (Challenge 2.4 / 3.6, optional)

Run `cd infra && ./scripts/check-fireworks-prereqs.sh` (PowerShell: `pwsh ./scripts/check-fireworks-prereqs.ps1`)
first: it checks login, the feature, the resource provider, your role, the region and the visible `FW-*` models
(with their *format*), and ends with next steps. Exit code 0 = no blockers.

| Symptom | Cause | Fix |
|---|---|---|
| Deployment fails with "feature not registered" / "subscription is not enabled for Fireworks" | Feature `Fireworks.EnableDeploy` not registered. | `./scripts/check-fireworks-prereqs.sh --register` (needs Subscription Owner/Contributor), wait, re-run the script, then `terraform apply`. |
| Script shows feature state **Registering** | Opt-in can take up to 30 min; "Registering" counts as a blocker. | Wait and re-run the script; afterwards `az provider register --namespace Microsoft.CognitiveServices` re-propagates the feature (`--register` does both). Don't start this during a challenge. |
| Feature not found under `Microsoft.CognitiveServices` | The namespace is a VALIDATE item (Learn names only the feature). | The script falls back to `az feature list` and searches for "Fireworks"; register the feature under the namespace it shows. |
| `FW-*` models not visible in the script / `DeploymentModelNotSupported` | Wrong region: pay-per-token Data Zone Standard is US-only (eastus, eastus2, centralus, northcentralus, westus, westus3); or the model retired (15-day notice). | Set `fireworks_location` to a US Data Zone region (default `eastus2`); pick an alternative from `terraform.tfvars.example` and add its `pricing_key` (coach). |
| `InsufficientQuota` on a Fireworks deployment / many 429s | Default quota 10M TPM per region per pool, shared by all Fireworks models; adaptive rate limits. | Lower `capacity` in `fireworks_models`, implement TODO 3.4 retry, lower `"concurrency"`; request more via **aka.ms/fireworks-quota**. |
| **Forbidden** / `AuthorizationFailed` when creating a Fireworks deployment | Deploying needs **Foundry Owner** (formerly Azure AI Owner) or **Azure AI Developer** on the project; RBAC propagation can take minutes. | Set `fireworks_grant_deployer_role = true` (and `fireworks_deployer_role = "Azure AI Owner"` if the tenant still shows the old name), apply again; or ask the subscription owner to assign the role on the Fireworks project. |
| Deployment fails with a model **format** / version error (`InvalidResourceProperties`, "format ... not supported") | `fireworks_model_format` (default `"Fireworks"`) and `version = null` are VALIDATE items. | Run the check script — step 6 prints the real *format* and version per model; set `fireworks_model_format` / `version` accordingly. `"FireworksCustom"` is only for imported custom weights (PTU-only, not used). |
| Apply runs for 20–30 min on `fireworks_first` / `fireworks_rest` | A Fireworks deployment can take up to 30 min (Terraform timeout is 60 min). | Wait; this is why it belongs in setup, not in Challenge 2. |
| `doctor`: `fw_fast` 401 | `FIREWORKS_AI_API_KEY` missing/stale in `.env`, or the `services.ai.azure.com` host (VALIDATE). | Re-run `terraform apply`; if 401 persists, `ai_endpoint_style = "openai"` and re-apply. |
| `fw_*` returns 400 for a parameter | Fireworks models take `max_tokens`, not GPT-5.x-only parameters. | Keep `max_tokens_param = "max_tokens"`, no `reasoning_effort` in `extra_body`. |
| Embeddings on `fw_*` fail | Fireworks on Foundry is chat completions only. | Keep `embedding` on `text-embedding-3-small`. |
| `fw_*` not reachable through APIM (`use_gateway: true`) | By design: `via_gateway` is false for `fw_*`; the `openai` API routes only to Azure. Fireworks is reachable through APIM only as the 3.6 failover target. | The apps call `fw_*` directly even with `use_gateway: true`. |

### Multi-provider failover policy (Challenge 3.6)

| Symptom | Cause | Fix |
|---|---|---|
| Apply fails: "policies/ai-gateway-multiprovider.xml needs the Fireworks backend" | Precondition: the policy needs `deploy_fireworks = true` (and `deploy_apim = true`). | Complete the Fireworks prerequisites, then `terraform apply -var 'deploy_fireworks=true' -var 'apim_policy_file=policies/ai-gateway-multiprovider.xml'`. |
| Apply fails on `azurerm_api_management_api_policy` with a validation error | A policy expression does not compile (VALIDATE: untested on a live gateway). | Read the error line, fix the XML (template variables use `${...}`; literal `$` must be `$${...}`), re-apply. APIM *Test* tab + trace shows the failing policy. |
| A 429 never fails over | The 429 comes from `llm-token-limit` (APIM's consumer budget, before any backend call), or the model is not in `failover_model_map` (nano, Llama, embeddings and judge never fail over). | Raise `tokens_per_minute_per_consumer` for the demo; check `terraform output apim_failover_model_map` — keys are **Azure deployment names**. |
| 503 / error without a Fireworks retry | With a secondary region the pool circuit breaker may be **open**: the gateway raises an error, `on-error` runs, no retry (VALIDATE). | Keep `deploy_secondary_region = false` for the failover demo; use a low deployment TPM; expect the first 429s to fail over. |
| Failover attempt returns 401 | `fireworks_backend_auth = "managed_identity"` not accepted by Fireworks deployments (VALIDATE), or the `fireworks-api-key` named value is stale. | Use the default `fireworks_backend_auth = "api_key"`; re-apply to refresh the named value. |
| Failover attempt returns 400 | Fireworks rejected a remaining GPT-5.x-only parameter (the policy removes `reasoning_effort` and renames `max_completion_tokens`). | Check the trace; remove the parameter in the `set-body` of the policy. |
| `x-tokenwars-provider` always `azure-openai` in metrics, although the header says `fireworks` | `llm-emit-token-metric` may evaluate the Provider dimension before the backend call (VALIDATE). | Use the outbound metric **"Provider Tokens"** (namespace `tokenwars`) — it is exact. |
| Answers got worse after enabling failover | A different model answers silently (quality drift). | That is the debrief point; read `x-tokenwars-model`. |

## Calling models

| Symptom | Cause | Fix |
|---|---|---|
| **401** from `*.services.ai.azure.com/openai/v1/...` while keys are correct | The apps send `api-key` **and** `Authorization` headers; the new Foundry host may reject this combination (VALIDATE). | Set `ai_endpoint_style = "openai"` in `terraform.tfvars`, `terraform apply` (rewrites `models.json` to `*.openai.azure.com`), `doctor`. |
| **401** from `*.openai.azure.com/openai/v1/...` | Wrong/missing `AZURE_AI_API_KEY`, local auth disabled, or a stale `.env` after re-creating the resource. | Re-run `terraform apply` (rewrites `.env`), check `doctor`. `az cognitiveservices account keys list -n <acct> -g <rg>`. |
| **404** `DeploymentNotFound` / "model not found" | `model` in the body must be the **deployment name**; deployment still provisioning; or a wrong `base_url`. | `base_url` must end with `/openai/v1/` (trailing slash) and the app appends `chat/completions`. Check `az cognitiveservices account deployment list -n <acct> -g <rg> -o table`. |
| **404** `Resource not found` on the v1 path | Using the old `/openai/deployments/<name>/chat/completions?api-version=` style, or the endpoint `*.cognitiveservices.azure.com`. | Use `https://<subdomain>.services.ai.azure.com/openai/v1/` (default) or `https://<subdomain>.openai.azure.com/openai/v1/` (`ai_endpoint_style = "openai"`). |
| **400** `unsupported_parameter: max_tokens` ("use max_completion_tokens instead") | GPT-5.x models do not accept `max_tokens`. | `max_tokens_param = "max_completion_tokens"` for that model (Terraform default for the GPT-5.6 family); re-apply to regenerate `models.json`. |
| **400** "Unsupported value: 'temperature' does not support 0.2 with this model" | GPT-5.x reasoning-capable models only accept the default temperature. | `supports_temperature = false` for that model (default for GPT-5.6) → the apps omit `temperature`. Check that `models.json` was regenerated. |
| **400** `unsupported_parameter` / "Unrecognized request argument: reasoning_effort" | `extra_body` with `reasoning_effort` sent to a model that doesn't support it (GPT-4.1, Llama, Ollama). | Set `extra_body = {}` for that model. |
| **Empty answer** (`content` = "" or null, `finish_reason: "length"`), judge score 1 | Reasoning tokens count against `max_completion_tokens`: with `reasoning_effort` above `none` and a low cap (e.g. 350, or 5 for the classifier) the model spends the whole budget thinking. The tokens are still billed. | Keep `reasoning_effort: "none"` (default), or raise `max_output_tokens` when using `low`/`medium`; look at `usage.completion_tokens_details.reasoning_tokens`. |
| Output tokens / cost much higher than expected | Reasoning tokens are billed as output ($20/1M on gpt-5.6-sol at the current promotional short-context rate). | Lower `reasoning_effort` per tier via `extra_body`; use higher effort only for the COMPLEX route. |
| **429** during the baseline | Token-hungry prompts and concurrent workers can exceed deployment TPM (default 800K for each GPT-5.6 deployment; newer models can have lower quota on some subscription types). | Increase `frontier_model.capacity` (if quota allows), lower `"concurrency"` in `strategy.json` (e.g. 4), or implement TODO 3.4 (retry). Errors count as failed items. |
| **429** via APIM with header `Retry-After` | Your `llm-token-limit` (TODO 3.5a) is working. | Retry (TODO 3.4), raise `tokens_per_minute_per_consumer`, or shrink prompts. |
| **401** via APIM "Access denied due to missing subscription key" | `APIM_SUBSCRIPTION_KEY` empty or sent in the wrong header. | Header must be `api-key`; re-run `terraform apply` to refresh `.env`; keys: `terraform output -json apim_consumer_keys`. |
| **401/403** via APIM from the backend ("PermissionDenied", "principal does not have access") | Role assignment for APIM's managed identity not propagated yet (up to ~10 min), or policy lacks `authentication-managed-identity`. | Wait and retry; check roles *Cognitive Services OpenAI User* + *Cognitive Services User* on the Foundry resource (Fireworks resource too). |
| **404** via APIM | Path must be `https://<apim>.azure-api.net/openai/v1/chat/completions` (API path `openai`, operations `/v1/chat/completions`, `/v1/embeddings`, `/v1/models`). | Check `gateway.base_url` in `models.json`. |
| **500** via APIM right after editing the policy | Policy references a backend id that does not exist (e.g. pool without `deploy_secondary_region`). | Use `${pool_backend_id}` (falls back to the primary automatically) or deploy the secondary region. APIM *Test* tab + trace shows the failing policy. |
| No token metrics in App Insights | Metrics appear after a few minutes; need API diagnostics with metrics enabled (Terraform does this). | App Insights > Metrics > namespace `tokenwars`. For dimension splits enable custom metric dimensions in App Insights. |
| `cached_tokens` always 0 | Prompt prefix < 1,024 tokens, or the prefix changes every call (dynamic lines on top). | That's the lesson of TODO 1.7 — put static content first; caching is best-effort and needs repeated identical prefixes within minutes. |
| Semantic cache returns wrong answers | Threshold too low or order-specific questions cached. | Keep 0.92+, never cache order-specific questions semantically. |

## Self-hosted model (Ollama on Container Apps)

| Symptom | Cause | Fix |
|---|---|---|
| `model "llama3.2:3b" not found` right after deploy | The model is pulled at container start (~2 GB, 1–5 min). | Wait; check logs: `az containerapp logs show -n <app> -g <rg> --follow`. |
| Very slow answers / timeouts (60 s) | CPU inference: ~5–15 tokens/s with 4 vCPU; long baseline prompts take minutes. | Use it only with compact prompt + retrieval + `max_output_tokens`, low concurrency; or pick a smaller model (`selfhosted_model = "qwen2.5:1.5b"`, `llama3.2:1b`). Expect low quality — that's part of the Challenge 2 story. |
| Container restarts / OOM | Model + context does not fit memory. | Keep 8Gi with 4 vCPU; smaller model. |
| Model re-downloads after restart | No persistent volume (by design, to keep it simple). | Acceptable for a workshop; mount Azure Files for `/root/.ollama` if needed. |

## Apps

| Symptom | Fix |
|---|---|
| "Could not find ROOT" | Run from inside the repo, or set `TOKENWARS_ROOT` to the repository root. |
| `TODO 1.2 not implemented yet – see ...` | Expected in the starter when a flag is on but the TODO is not implemented. Implement it or turn the flag off. |
| `models.json` missing | Run `terraform apply`, or copy `shared/config/models.example.json` to `models.json` and fill in endpoints/keys manually. |
| Everything offline / no Azure | `--mock` or `TOKENWARS_MOCK=1` (no HTTP; leaderboard rejects mock runs). |
| Leaderboard submit fails with 401 | `TOKENWARS_LEADERBOARD_KEY` wrong; 400 = mock run or missing team name (`TOKENWARS_TEAM`). |
| Corporate proxy / TLS inspection | Python: set `REQUESTS_CA_BUNDLE`; .NET: trust the proxy root CA in the OS store. |
