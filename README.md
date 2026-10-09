# Token Wars: Build, Route & Optimize Your AI Stack

A 4-hour Azure GenAI **cost-optimisation microhack** for digital-native teams.

**ByteCart** is a fictional, fast-growing EU e-commerce marketplace. Its GenAI *Support Copilot* answers customer
questions — and it works, but it is **expensive**: it always calls the frontier model, stuffs the whole knowledge base and
the whole orders database into every prompt, puts dynamic data at the top of the system prompt (so prompt caching never
kicks in), has no output limits and no caching.

Your mission: **cut the cost per successful answer** while keeping answer quality above the bar (≥ 85 % of the
100 workload questions judged correct by an LLM judge). The cheapest valid team wins the leaderboard.

| Time | Block |
|---|---|
| 0:00 | Kickoff — "Enter the Arena" (deploy, run the baseline) |
| 0:30 | Challenge 1 — "The Token Diet" (prompt, retrieval, output control, caching) |
| 1:30 | Break |
| 1:40 | Challenge 2 — "Bring Your Own Model" (open-weight & self-hosted models, compare; optional 2.4 *Fireworks Arena*) |
| 2:40 | Challenge 3 — "Route & Rule" (routing, escalation, retries, AI gateway policies; stretch 3.6 *Multi-Provider Failover*) |
| 3:30 | Final Showdown & Debrief |

Step-by-step instructions: open [`docs/index.html`](docs/index.html) in a browser.
Before the event, every team works through [`coach/pre-event-checklist.md`](coach/pre-event-checklist.md).

## Principles

- **Pay-as-you-go first.** Every model in the kit is billed per token (Global / Data Zone Standard). Nothing in the
  kit requires provisioned throughput (PTU); PTU only appears as a "for reference" line in the coach's break-even demo.
- **Each team brings its own Azure subscription.** Quota, feature registrations and costs stay isolated per team.
  The coach uses a **separate** subscription for the leaderboard and for demos that do not fit into 4 hours
  ("Own the Weights" fine-tuning).
- **Optional extras stay optional.** Fireworks on Foundry (Challenge 2.4) and multi-provider failover (Challenge 3.6)
  are off by default (`deploy_fireworks = false`); the core challenges work without them.

## Repository map

```
.
├── README.md                 you are here
├── .env.example              template; terraform writes the real .env (git-ignored)
├── infra/                    Terraform: Microsoft Foundry resource + project + model deployments, APIM AI gateway,
│   │                         monitoring, optional Ollama on Container Apps, optional secondary region
│   ├── fireworks.tf          optional Fireworks on Foundry deployments (Challenge 2.4, deploy_fireworks = true)
│   ├── scripts/              check-fireworks-prereqs.sh / .ps1 (feature registration, roles, region, model list)
│   └── policies/             APIM policy templates: ai-gateway-starter.xml (TODO 3.5) / ai-gateway-solution.xml /
│                             ai-gateway-multiprovider.xml (Challenge 3.6 stretch: failover to Fireworks)
├── shared/
│   ├── knowledge-base/       ByteCart help-center articles (10 Markdown docs, ~7.8k tokens)
│   ├── data/orders.json      60 orders of 20 customers (scenario date 2026-09-15)
│   ├── data/workload.jsonl   the 100 customer questions you are scored on (+ ground truth for the judge only)
│   ├── config/               pricing.json, scoring.json, models.example.json (models.json is generated)
│   └── prompts/              system-baseline.md (the wasteful baseline) and judge.md
├── python/starter|solution   Python app (requests only)       -> python -m tokenwars ...
├── dotnet/starter|solution   .NET 8 app (no NuGet packages)    -> dotnet run -- ...
├── leaderboard/              stdlib-only leaderboard server + Dockerfile (for coaches)
├── coach/                    coach guide, scoring rules, troubleshooting
│   ├── pre-event-checklist.md  what each team and the coach must do before the event
│   └── own-the-weights/      coach-only demo: fine-tune a small open-weight model, compare, break-even (coach subscription)
└── docs/index.html           visual step-by-step instructions
```

## Prerequisites

Full list with commands and timing: [`coach/pre-event-checklist.md`](coach/pre-event-checklist.md).

- **Your own Azure subscription** (one per team) with permission to create resource groups, Microsoft Foundry
  resources and deployments, API Management and role assignments: **Owner**, or **Contributor + User Access
  Administrator**. Owner/Contributor is also needed because azurerm 5.x registers the required resource providers
  (`Microsoft.CognitiveServices`, `Microsoft.ApiManagement`, `Microsoft.OperationalInsights`, `Microsoft.Insights`,
  `Microsoft.App`) itself.
- Model quota in your region (default `swedencentral`) for `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`,
  `gpt-5.5` (independent judge), `text-embedding-3-small` and `Llama-3.3-70B-Instruct` (GlobalStandard). Check with
  `az cognitiveservices model list --location swedencentral -o table`, `az cognitiveservices usage list --location swedencentral -o table`
  and the Foundry portal's *Quota* page.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [Terraform ≥ 1.6](https://developer.hashicorp.com/terraform/install)
  (the Azure Developer CLI `azd` is not needed).
- **Either** Python 3.10+ (`pip install requests`) **or** .NET 8 SDK (or newer).
- Optional, Challenge 2.4 / 3.6 only: subscription feature `Fireworks.EnableDeploy` registered (up to 30 min) and a
  US region for Fireworks — run `infra/scripts/check-fireworks-prereqs.sh --register` (PowerShell:
  `./scripts/check-fireworks-prereqs.ps1 -Register`) **at least a day before** the event.

## Quick start

```bash
# 1. Sign in
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)      # PowerShell: $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)

# 2. Deploy (10-20 min; APIM is the slowest part)
cd infra
cp terraform.tfvars.example terraform.tfvars                          # set team_name (+ leaderboard_url/key from your coach)
terraform init                                                        # existing checkout with an old lock file: terraform init -upgrade
terraform apply
#   -> writes ../.env and ../shared/config/models.json
terraform output foundry_portal_hint                                 # how to find your project in https://ai.azure.com

# 3a. Python
cd ../python/starter
pip install -r requirements.txt
python -m tokenwars doctor                  # checks config + test calls (64-token chat output budget)
python -m tokenwars run --limit 20          # quick baseline
python -m tokenwars run --submit            # full scored baseline -> leaderboard

# 3b. .NET
cd ../dotnet/starter/TokenWars
dotnet run -- doctor
dotnet run -- run --limit 20
dotnet run -- run --submit
```

No Azure yet? Every command works offline with `--mock` (or `TOKENWARS_MOCK=1`): no HTTP calls, simulated token counts.

Then work through the challenges: flip flags in `strategy.json`, implement the `TODO x.y` stubs, re-run, and watch
your **cost per successful answer** drop. The `solution/` folders contain the reference implementation.

## Useful commands

| Action | Python (`python/<variant>/`) | .NET (`dotnet/<variant>/TokenWars/`) |
|---|---|---|
| Full scored run | `python -m tokenwars run` | `dotnet run -- run` |
| Quick run | `python -m tokenwars run --limit 20` | `dotnet run -- run --limit 20` |
| Submit to leaderboard | `python -m tokenwars run --submit` | `dotnet run -- run --submit` |
| Skip judging | `python -m tokenwars run --no-judge` | `dotnet run -- run --no-judge` |
| Ask one question | `python -m tokenwars ask "Can I return shoes?" --customer C1001` | `dotnet run -- ask "Can I return shoes?" --customer C1001` |
| Compare models (Ch. 2) | `python -m tokenwars compare --models frontier,mini,nano,open` | `dotnet run -- compare --models frontier,mini,nano,open` |
| Fireworks Arena (Ch. 2.4, optional) | `python -m tokenwars compare --models mini,frontier,fw_fast,fw_pro` | `dotnet run -- compare --models mini,frontier,fw_fast,fw_pro` |
| Check setup | `python -m tokenwars doctor` | `dotnet run -- doctor` |

## Microsoft Foundry

Terraform uses the **new Microsoft Foundry** resource model: one Foundry resource (`azurerm_cognitive_account`, kind
`AIServices`, `project_management_enabled = true`, custom subdomain, system-assigned identity) plus a Foundry
**project** `proj-tokenwars` (display name "Token Wars – <team>"). Model deployments live on the resource; there
are no hub or ML workspace resources. Open the project in the new Foundry portal at <https://ai.azure.com>
(`terraform output foundry_portal_hint`).

- The apps call the OpenAI-compatible v1 API. By default `models.json` uses
  `https://<subdomain>.services.ai.azure.com/openai/v1/` (`ai_endpoint_style = "foundry"`). If you get 401s on that
  host, set `ai_endpoint_style = "openai"` (→ `https://<subdomain>.openai.azure.com/openai/v1/`) and re-apply.
- The APIM gateway always talks to `https://<subdomain>.openai.azure.com/openai` with its managed identity.
- The provider is pinned to **azurerm `~> 5.8`** (4.x ended with 4.81.0). If your checkout still has a lock file from
  azurerm 4.x, run `terraform init -upgrade`. Fallback for teams that must stay on 4.x: see the comment in
  `infra/providers.tf`.
- Upgrading an existing deployment: switching `project_management_enabled` on is an in-place update and the project is
  added; the resource and its deployments are not recreated.

Useful outputs: `foundry_project_name`, `foundry_project_endpoint`, `foundry_project_endpoints`, `foundry_portal_hint`,
`ai_endpoint_style`, `ai_base_url`; with Fireworks also `fireworks_account_name`, `fireworks_base_url`,
`fireworks_deployments`, `fireworks_project_endpoint`, `apim_failover_model_map`. `terraform output next_steps`
prints what to run next.

## Infrastructure switches (`infra/terraform.tfvars`)

| Variable | Default | What it does |
|---|---|---|
| `foundry_project_name` | `proj-tokenwars` | name of the Foundry project |
| `ai_endpoint_style` | `foundry` | host written to `models.json`: `foundry` (`*.services.ai.azure.com`) or `openai` (`*.openai.azure.com`, fallback) |
| `deploy_apim` | `true` | API Management (BasicV2) as AI gateway with managed-identity auth to Azure AI |
| `apim_policy_file` | `policies/ai-gateway-starter.xml` | policy template applied to the `openai` API (TODO 3.5; `ai-gateway-multiprovider.xml` for 3.6) |
| `deploy_selfhosted_model` | `false` | Ollama (`llama3.2:3b`) on Azure Container Apps (CPU) → models.json key `selfhosted` |
| `deploy_secondary_region` | `false` | second Foundry resource + APIM backend pool for the failover demo |
| `deploy_fireworks` | `false` | Challenge 2.4: second Foundry resource + project in `fireworks_location` (default `eastus2`, US Data Zone only) with the `fireworks_models` deployments → models.json keys `fw_fast`, `fw_pro`, `.env` `FIREWORKS_AI_API_KEY` |
| `fireworks_models` | `fw_fast` = `FW-DeepSeek-V4-Flash-0731`, `fw_pro` = `FW-DeepSeek-V4-Pro` | DataZoneStandard / GlobalStandard only (no PTU); alternatives listed in `terraform.tfvars.example` |
| `fireworks_grant_deployer_role` | `false` | assigns `fireworks_deployer_role` (`Foundry Owner`) on the Fireworks project if deployment fails with Forbidden |
| `fireworks_backend_auth` / `failover_model_map` | `api_key` / mini→fw_fast, frontier→fw_pro | Challenge 3.6 failover backend auth and model mapping |
| `*_model` | GPT-5.6 answer tiers, GPT-5.5 judge, text-embedding-3-small, Llama 3.3 70B | model name / version / SKU / capacity (TPM ×1000) / pricing key / `max_tokens_param` / `supports_temperature` / `extra_body` / `extra_headers` |

Re-run `terraform apply` after every change; it regenerates `.env` and `shared/config/models.json`.

### Models

| Key | Default deployment | Notes |
|---|---|---|
| `frontier` | `gpt-5.6-sol` (2026-07-09) | reasoning-capable; written with `max_completion_tokens`, no `temperature`, `reasoning_effort: none` |
| `mini` | `gpt-5.6-terra` (2026-07-09) | same settings |
| `nano` | `gpt-5.6-luna` (2026-07-09) | same settings; also the classifier router |
| `judge` | `judge` → `gpt-5.5` (2026-04-24) | independent evaluator; not part of the score; bypasses the gateway |
| `embedding` | `text-embedding-3-small` | semantic cache / embedding retrieval |
| `open` | `Llama-3.3-70B-Instruct` | serverless open-weight model, `max_tokens`, temperature supported |
| `selfhosted` | `llama3.2:3b` (Ollama) | optional, CPU on Container Apps |
| `fw_fast` | `FW-DeepSeek-V4-Flash-0731` | optional (Challenge 2.4), Fireworks on Foundry, Data Zone Standard pay-per-token, direct call (`via_gateway: false`), `prompt_cache_key` in `extra_body` |
| `fw_pro` | `FW-DeepSeek-V4-Pro` | same; open frontier model vs `frontier` |
| `custom` | fine-tuned model | coach demo only ("Own the Weights", coach subscription); has an informational `hourly_cost_usd` |

The three GPT-5.6 answer deployments and the independent GPT-5.5 `judge` default to capacity **800** (800K TPM each).
The optional secondary region uses capacity **800** per chat deployment too; embeddings and open-weight models
keep their existing capacities. Terra needs 800K TPM for `mini`; GPT-5.5 needs a separate 800K TPM allocation for `judge`.

**Why GPT-5.5 for the judge:** the challenges optimise GPT-5.6 answer tiers, so a separate frontier evaluator
avoids using Terra to grade Terra's own answers. GPT-5.5 fits the existing short reference-answer/JSON grading
flow; GPT-6.1 Sol is an alternative to evaluate, not a requirement for these challenges. A different model does
not guarantee unbiased grading: coaches must calibrate it against a few human-reviewed answers in the dry run.
The judge keeps `max_completion_tokens`, omitted temperature and `reasoning_effort: none`.

Challenges 1–3, answer routing and the ≥85% quality bar are unchanged. The judge bypasses APIM and is not a
failover target; its cost remains `judge_cost_usd`, outside the leaderboard score. Use the same pinned judge,
prompt and settings for all teams throughout the event. Changing the evaluator can change pass rates:
repeat the baseline and scored comparisons, and do not rank new scores against old-judge runs.

For an existing deployment, run `terraform plan` and review the model replacements, then `terraform apply` from
`infra/`. Terraform regenerates `shared/config/models.json` only after the new deployments exist; until then,
the generated registry still points to your current deployments. Do not manually rewrite Terraform state or old
run results. Re-run `doctor` and the baseline after applying, since model quality and latency must be remeasured.

GPT-5.6 pricing uses Microsoft's published Standard Global **short-context** rates:
Sol $4.00 / $0.50 / $20.00, Terra $2.00 / $0.20 / $12.00, Luna $0.20 / $0.02 / $1.20
per 1M input / cached input / output tokens. Sol's input/output rates are promotional through at least
2026-11-30; recheck before later events. [Pricing source](https://azure.microsoft.com/en-us/blog/gpt-5-6-now-available-in-microsoft-foundry/).
GPT-5.5 judge pricing is $5.00 / $0.50 / $30.00 per 1M input / cached input / output tokens
([Microsoft pricing source](https://azure.microsoft.com/en-us/blog/openais-gpt-5-5-in-microsoft-foundry-frontier-intelligence-on-an-enterprise-ready-platform/));
measure its unscored cost and latency during the dry run.

The GPT-4.1 family is deprecated for new customers in 2026; if your subscription still has access you can switch back
with the commented block in `infra/terraform.tfvars.example` (`pricing.json` keeps the `gpt-4.1*` prices).
Reasoning tokens are billed as **output** tokens and count against `max_completion_tokens` — keep `reasoning_effort` at
`none`/`low` for cheap tiers (per-model `extra_body` in `terraform.tfvars`).

Any key in `models.json` works with `compare`, `default_model` and the router's tier mapping; keys outside the
`nano → mini → frontier` chain (`open`, `selfhosted`, `fw_*`, `custom`) escalate straight to `frontier`.

### Optional: Fireworks Arena (Challenge 2.4) and Multi-Provider Failover (Challenge 3.6)

Fireworks on Foundry lets you put **open frontier** models (DeepSeek V4 Flash / Pro) next to the closed frontier
models — pay-per-token only.

```bash
cd infra
./scripts/check-fireworks-prereqs.sh --register      # PowerShell: ./scripts/check-fireworks-prereqs.ps1 -Register
./scripts/check-fireworks-prereqs.sh                 # repeat until it reports no blockers (feature up to 30 min)
terraform apply -var 'deploy_fireworks=true'         # or set deploy_fireworks = true in tfvars; a deployment can take up to 30 min
# Challenge 3.6 (stretch, needs deploy_apim + deploy_fireworks):
terraform apply -var 'deploy_fireworks=true' -var 'apim_policy_file=policies/ai-gateway-multiprovider.xml'
```

Do this **during setup** (ideally the day before), not during the challenge. Current limitations: pay-per-token Data
Zone Standard is **US-only** (eastus, eastus2, centralus, northcentralus, westus, westus3) and Fireworks on Foundry is
currently **excluded from the EU Data Boundary** (the workshop uses synthetic data); chat completions only; adaptive
rate limits can return 429s; per-token models can retire with 15 days' notice. Fireworks prices in `pricing.json` are
marked `"verified": false` until the coach confirms them. With the 3.6 policy, a 429/5xx from the Azure backend for a
mapped model is retried once on Fireworks; the response header `x-tokenwars-provider` shows who answered.

## Rules in one paragraph

Score = **total cost ÷ successful answers** (judge score ≥ 4 of 5) over the full 100-question workload. A run is
only valid with a pass rate ≥ 85 %. The answering pipeline may only use `id`, `customer_id` and `question` from the
workload — using `category`, `difficulty`, `reference_answer` or `must_include` means disqualification. Judge costs
are not counted. Details: [`coach/scoring.md`](coach/scoring.md).

## Cleanup

```bash
cd infra
terraform destroy
```
This deletes the resource group with all Foundry resources (including the optional Fireworks resource), model
deployments, APIM, Container Apps and logs (soft-deleted Foundry resources and APIM instances are purged). Nothing keeps billing afterwards. The generated `.env` and `models.json` stay on disk —
delete them if you like.

## Disclaimer

ByteCart, its customers, orders and policies are fictional. Prices in `shared/config/pricing.json` are illustrative
list prices — update them to current Azure pricing for your region before the event. Entries with `"verified": false`
(the Fireworks models) could not be confirmed on the official pricing page.
