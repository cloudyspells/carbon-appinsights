# Running deployment from local workstation

## Deploying the resources to Azure

To run the deployment from your local workstation, you will need to install the
following tools:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

Then create a new parameters json file with the following content:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "template": "./main.bicep"
  },
  "parameters": {
    "projectName": {
      "value": "co2-insights"
    },
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "westeurope"
    },
    "emissionRegions": {
      "value": "\"westeurope\",\"norwayeast\",\"northeurope\""
    }
  }
}

Adapt the parameters to your own needs. Specifically the `emissionRegions`
parameter as that sets the Azure regions to be polled for emissions.

Then you can run the following commands to deploy the resources:

```bash
cd src/bicep
az login
az account set --subscription <SUBSCRIPTION_ID>
az deployment sub create --location <REGION> --template-file ./main.bicep --parameters @<PARAMETERS_FILE>
```

**Example**:

```bash
az login
az account set --subscription 00000000-0000-0000-0000-000000000000
az deployment sub create --location westeurope --template-file ./main.bicep --parameters @./main.parameters.json
```

## Running the function locally in Visual Studio Code

To run the function locally in Visual Studio Code, you will need to install the
following tools:

- [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Azure Functions extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)

Then you can open the `src/carbon-appinsights` folder in Visual Studio Code and run the function
locally by pressing `F5`.
