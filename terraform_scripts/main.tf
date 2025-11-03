# Create a resource group

resource "azurerm_resource_group" "rg" {
  name     = "rg_terraform"
  location = "southindia"
}

# Create storage account for function app
resource "azurerm_storage_account" "sa" {
  name                     = "safabrictosnowflake897"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"
  #account_kind             = "StorageV2"
  #is_hns_enabled           = "true"
  
  blob_properties {
    versioning_enabled = true
    container_delete_retention_policy {
      days = 7
    }
  }
}

# Create storage container
resource "azurerm_storage_container" "con" {
  name                  = "confabrictosnowflake"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# Create user assigned managed identity
resource "azurerm_user_assigned_identity" "identity" {
  name                = "id-fabrictosnowflake-timer"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}


# Assign Storage Blob Data Contributor role to the managed identity
resource "azurerm_role_assignment" "storage_role" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

# Create App Service Plan (Consumption)
resource "azurerm_service_plan" "asp" {
  name                = "asp-fabrictosnowflake-timer"
  resource_group_name = azurerm_resource_group.rg.name
  location           = azurerm_resource_group.rg.location
  os_type            = "Linux"
  sku_name           = "FC1"
}

# Create Application Insights
resource "azurerm_application_insights" "ai" {
  name                = "ai-fabrictosnowflake-timer"
  resource_group_name = azurerm_resource_group.rg.name
  location           = azurerm_resource_group.rg.location
  application_type   = "web"
  #retention_in_days  = 90
  #sampling_percentage = 100
}

# Create Function App
resource "azurerm_function_app_flex_consumption" "fa" {
  name                        = "fa-fabrictosnowflake-timer"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  service_plan_id             = azurerm_service_plan.asp.id
  runtime_name                = "python"
  runtime_version             = "3.12"
  storage_container_type      = "blobContainer"
  storage_container_endpoint   = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.con.name}"
  storage_authentication_type = "UserAssignedIdentity"
  #storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.identity.id
  #storage_account_use_managed_identity      = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.identity.id]
  }
 site_config {}
  depends_on = [azurerm_role_assignment.storage_role,azurerm_user_assigned_identity.identity]

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai.connection_string
    "PYTHON_ENABLE_WORKER_EXTENSIONS" = "1"
    #"FUNCTIONS_WORKER_RUNTIME"       = "python"
    #"FUNCTIONS_WORKER_PROCESS_COUNT" = 5
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.sa.name
    # "AzureWebJobsFeatureFlags"       = "EnableWorkerIndexing"
    # "AzureWebJobsSecretStorageType" = "files"
    # "ENABLE_ORYX_BUILD"             = "true"
    # "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    # "WEBSITE_MOUNT_ENABLED"         = "1" 
  }

}