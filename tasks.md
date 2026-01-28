Azure DevOps project: https://dev.azure.com/kdzhekishev/simple-app
GH repo: https://github.com/d-kuba/simple-app
App URL: https://hello-world-app.azurewebsites.net/

Implement the changes in a new git branch based on `main`.

Tasks:
* Update the pipeline template `azure-pipelines.yml` to trigger the runs automatically from your branch
* Investigate why secret value is not displayed on https://hello-world-app.azurewebsites.net/, and fix it in IaC templates
* Add a new storage account for collecting a memory dump from the web app. Update app settings accordingly. Existing storage account was modified manually, and we want to move away from it. You can use it to compare with your new storage.
* If time allows, introduce staging slot for deployments