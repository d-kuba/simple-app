Azure DevOps project: https://dev.azure.com/kdzhekishev/simple-app
GH repo: https://github.com/d-kuba/simple-app
App URL: https://hello-world-app.azurewebsites.net/

Implement the changes in a new git branch based on `main`. Create a pull request afterwards

Tasks:
* Investigate why secret value is not displayed on https://hello-world-app.azurewebsites.net/, and fix it in IaC templates
* Add a new storage account into IaC to collect a memory dump from the web app. Update app settings accordingly
* Introduce staging slot for deployments