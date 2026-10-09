# Model deployments on the Foundry resource (deployments stay on the resource, not on the project).
# Deployments on the same resource are created one after another (depends_on chain): parallel deployment
# operations on one resource frequently fail with "RequestConflict / another operation in progress".
# Fireworks deployments: fireworks.tf

locals {
  deployment_names = {
    frontier  = var.frontier_model.name
    mini      = var.mini_model.name
    nano      = var.nano_model.name
    judge     = "judge"
    embedding = var.embedding_model.name
    open      = var.open_model.name
  }
}

resource "azurerm_cognitive_deployment" "frontier" {
  name                 = local.deployment_names.frontier
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.frontier_model.format
    name    = var.frontier_model.name
    version = var.frontier_model.version
  }

  sku {
    name     = var.frontier_model.sku
    capacity = var.frontier_model.capacity
  }
}

resource "azurerm_cognitive_deployment" "mini" {
  name                 = local.deployment_names.mini
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.mini_model.format
    name    = var.mini_model.name
    version = var.mini_model.version
  }

  sku {
    name     = var.mini_model.sku
    capacity = var.mini_model.capacity
  }

  depends_on = [azurerm_cognitive_deployment.frontier]
}

resource "azurerm_cognitive_deployment" "nano" {
  name                 = local.deployment_names.nano
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.nano_model.format
    name    = var.nano_model.name
    version = var.nano_model.version
  }

  sku {
    name     = var.nano_model.sku
    capacity = var.nano_model.capacity
  }

  depends_on = [azurerm_cognitive_deployment.mini]
}

resource "azurerm_cognitive_deployment" "judge" {
  name                 = local.deployment_names.judge
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.judge_model.format
    name    = var.judge_model.name
    version = var.judge_model.version
  }

  sku {
    name     = var.judge_model.sku
    capacity = var.judge_model.capacity
  }

  depends_on = [azurerm_cognitive_deployment.nano]
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = local.deployment_names.embedding
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.embedding_model.format
    name    = var.embedding_model.name
    version = var.embedding_model.version
  }

  sku {
    name     = var.embedding_model.sku
    capacity = var.embedding_model.capacity
  }

  depends_on = [azurerm_cognitive_deployment.judge]
}

resource "azurerm_cognitive_deployment" "open" {
  count = var.deploy_open_model ? 1 : 0

  name                 = local.deployment_names.open
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = var.open_model.format
    name    = var.open_model.name
    version = var.open_model.version
  }

  sku {
    name     = var.open_model.sku
    capacity = var.open_model.capacity
  }

  depends_on = [azurerm_cognitive_deployment.embedding]
}

# -----------------------------------------------------------------------------
# Secondary region: same deployment NAMES as the primary so the APIM backend pool can fail over transparently.
# Only the chat tiers are replicated (the judge, embedding and open model stay in the primary region).
# -----------------------------------------------------------------------------
resource "azurerm_cognitive_deployment" "frontier_secondary" {
  count = local.secondary_enabled ? 1 : 0

  name                 = local.deployment_names.frontier
  cognitive_account_id = azurerm_cognitive_account.ai_secondary[0].id

  model {
    format  = var.frontier_model.format
    name    = var.frontier_model.name
    version = var.frontier_model.version
  }

  sku {
    name     = var.frontier_model.sku
    capacity = var.secondary_capacity
  }
}

resource "azurerm_cognitive_deployment" "mini_secondary" {
  count = local.secondary_enabled ? 1 : 0

  name                 = local.deployment_names.mini
  cognitive_account_id = azurerm_cognitive_account.ai_secondary[0].id

  model {
    format  = var.mini_model.format
    name    = var.mini_model.name
    version = var.mini_model.version
  }

  sku {
    name     = var.mini_model.sku
    capacity = var.secondary_capacity
  }

  depends_on = [azurerm_cognitive_deployment.frontier_secondary]
}

resource "azurerm_cognitive_deployment" "nano_secondary" {
  count = local.secondary_enabled ? 1 : 0

  name                 = local.deployment_names.nano
  cognitive_account_id = azurerm_cognitive_account.ai_secondary[0].id

  model {
    format  = var.nano_model.format
    name    = var.nano_model.name
    version = var.nano_model.version
  }

  sku {
    name     = var.nano_model.sku
    capacity = var.secondary_capacity
  }

  depends_on = [azurerm_cognitive_deployment.mini_secondary]
}
