# Nerdio Manager Shell Apps

    Note: this code is provided as-is, without warranty or support of any kind.

A list of definitions for Nerdio Manager Shell Apps - these include detection, install and uninstall scripts.

Included here is a proof-of-concept for automating the import for Shell Apps and versions - requires Nerdio Manager for Enterprise 7.2+:

* `NerdioShellApps.psm1` - a module with functions required for automating the import of Shell Apps. This depends on the [Evergreen](https://stealthpuppy.com/evergreen)
* `Create-ShellApps.ps1` - a sample script for importing a selection of Shell Apps into Nerdio Manager

Read more here:

* [Automating Nerdio Manager Shell Apps, with Evergreen, Part 1](https://stealthpuppy.com/nerdio-shell-apps-p1/)
* [Automating Nerdio Manager Shell Apps, with Evergreen, Part 2](https://stealthpuppy.com/nerdio-shell-apps-p2/)
* [Automating Nerdio Manager Shell Apps, with Evergreen, Part 3](https://stealthpuppy.com/nerdio-shell-apps-p3/)

## Pipelines

### pipeline-newapps.yml

This Azure DevOps pipeline automates the import and management of Nerdio Manager Shell Apps using Evergreen to automatically retrieve the latest application versions.

**Triggers:**

* Manual execution
* Automatic on commits to the `apps/**` directory in the `main` branch
* Daily scheduled run at 2AM AEST (5PM UTC)

**Prerequisites:**

* Azure DevOps service connection configured (default name: `sc-rg-Avd1Images-aue`)
* Variable group named `Credentials` containing:
  * `ClientId` - Azure AD application client ID
  * `ClientSecret` - Azure AD application client secret
  * `TenantId` - Azure AD tenant ID
  * `ApiScope` - Nerdio Manager API scope
  * `SubscriptionId` - Azure subscription ID
  * `OAuthToken` - Nerdio Manager OAuth token
  * `resourceGroupName` - Resource group containing the storage account
  * `storageAccountName` - Storage account for Shell App installers
  * `containerName` - Storage container name
  * `nmeHost` - Nerdio Manager host URL

**Pipeline Steps:**

1. **Checkout repository** - Clones the repository to access Shell App definitions and the `NerdioShellApps.psm1` module

2. **Install Modules** - Installs required PowerShell modules:
   * `Az.Accounts` - Azure authentication
   * `Az.Storage` - Azure storage operations
   * `VcRedist` - Microsoft Visual C++ Redistributables management
   * `Evergreen` - Retrieves latest application versions

3. **Azure Login** - Authenticates to Azure using the service connection and sets the subscription context

4. **Import Shell Apps** - Core automation step that:
   * Authenticates to Nerdio Manager API
   * Scans the `apps` directory for Shell App definitions (`Definition.json` files)
   * For each app definition:
     * Retrieves app metadata using Evergreen
     * Checks if the Shell App already exists in Nerdio Manager
     * If new: Creates the Shell App and imports the first version
     * If existing: Updates the Shell App and checks if the version exists
     * If the version is new or newer: Imports the new version
     * Skips import if the version already exists

5. **Prune Shell Apps versions** - Maintenance step that:
   * Keeps only the 3 most recent non-preview versions of each Shell App
   * Removes older versions from Nerdio Manager
   * Deletes associated installer files from Azure Storage to save costs

6. **List Shell Apps** - Outputs a summary table showing:
   * Publisher and name
   * Version count
   * Latest version
   * Creation date
   * File extraction settings
   * Public/private status
   * Shell App ID

**How It Works:**

The pipeline uses the `NerdioShellApps.psm1` module to interact with the Nerdio Manager API. It reads Shell App definitions from subdirectories under `apps/`, retrieves the latest version information using Evergreen, uploads installer files to Azure Storage, and creates or updates Shell Apps in Nerdio Manager. The pipeline intelligently detects whether apps and versions already exist to avoid duplicates, and automatically cleans up old versions to maintain only the three most recent releases.

### pipeline-newappgroup.yml

This Azure DevOps pipeline creates or updates an App Group in Nerdio Manager, populating it with all available Shell Apps. App Groups allow you to organize and deploy multiple Shell Apps as a single unit.

**Triggers:**

* Manual execution only (no automatic triggers)

**Parameters:**

* `appGroupName` - Name of the app group to create or update (default: `'All Shell Apps'`)

**Prerequisites:**

* Same as pipeline-newapps.yml
* Variable group named `Credentials` with all required connection details

**Pipeline Steps:**

1. **Checkout repository** - Clones the repository to access the `NerdioShellApps.psm1` module

2. **Install Modules** - Installs required PowerShell modules:
   * `Az.Accounts`
   * `Az.Storage`
   * `Evergreen`
   * `VcRedist`

3. **Create or Update App Group** - Main logic step that:
   * Authenticates to Nerdio Manager API
   * Retrieves all existing Shell Apps
   * Checks if the specified app group already exists
   * If the app group exists:
     * Compares Shell Apps in the repository to those in the app group
     * Adds any new Shell Apps that aren't already included
     * Updates the app group with the expanded list
   * If the app group doesn't exist:
     * Creates a new app group with the specified name
     * Populates it with all available Shell Apps

**How It Works:**

The pipeline uses the Shell Apps repository ID to create payload objects for each Shell App, then either creates a new app group or updates an existing one. This is useful for maintaining a master app group that automatically includes all Shell Apps managed by your pipeline. Run this after importing new Shell Apps to ensure they're included in your deployment groups.

### pipeline-removeapps.yml

This Azure DevOps pipeline removes all Shell Apps from Nerdio Manager. This is a destructive operation intended for cleanup or testing scenarios.

**Triggers:**

* Manual execution only (no automatic triggers)

**Prerequisites:**

* Same as pipeline-newapps.yml
* Variable group named `Credentials` with all required connection details
* Azure DevOps service connection configured (default name: `sc-rg-Avd1Images-aue`)

**Pipeline Steps:**

1. **Checkout repository** - Clones the repository to access the `NerdioShellApps.psm1` module

2. **Install Modules** - Installs required PowerShell modules:
   * `Az.Accounts`
   * `Az.Storage`
   * `Evergreen`
   * `VcRedist`

3. **Remove Shell Apps** - Destructive operation that:
   * Authenticates to Azure using the service connection
   * Sets the Azure subscription context
   * Authenticates to Nerdio Manager API
   * Retrieves all existing Shell Apps
   * Deletes each Shell App (without confirmation)
   * Cleans up secrets from memory

**How It Works:**

The pipeline iterates through all Shell Apps in Nerdio Manager and removes them using the API. This operation does not remove the installer files from Azure Storage - only the Shell App definitions from Nerdio Manager. All versions of each Shell App are deleted.

**Warning:** This is a destructive operation that cannot be undone. Use with caution and only in development/testing environments or when you need to completely reset your Shell Apps configuration.
