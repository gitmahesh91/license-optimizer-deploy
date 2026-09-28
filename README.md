# License Optimizer — Azure Deployment

Deploys the License Optimizer Azure Functions into your Azure subscription.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fgitmahesh91%2Flicense-optimizer-deploy%2Fmain%2Fazuredeploy.json)

## What gets created

| Resource | Details |
|---|---|
| Function App | .NET 8 isolated, Functions v4, Windows |
| Hosting plan | Consumption (Y1) |
| Storage account | Required by the Functions runtime |
| Application Insights + Log Analytics | Monitoring |

The function code is loaded automatically from the published release package.

## Values you need before you click

| Field | Where to find it |
|---|---|
| Tenant ID | Entra ID → Overview → Tenant ID |
| Client ID | Entra ID → App registrations → your app → Application (client) ID |
| Client Secret | Your app registration → Certificates & secrets (the secret **value**) |
| Dataverse URL | Power Platform admin center → your environment → Environment URL |

## After deployment

1. Open the deployment → **Outputs** → copy **functionAppUrl**.
2. Paste it into the **FunctionAppUrl** field of the Dataverse Config record.
3. Open the Function App → **Functions** → confirm all 12 functions are listed.
