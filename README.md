# Auto-Deploy-New-VDI-In-Xendesktop-Catalog
Deploy VDIs automatically in XenDesktop Catalog

## Description

This script allows you to create new VDIs in xendesktop catalog.

### Prerequisites

N/A

### Installing

No installation required.

### Usage

Run this script when required Or, create a scheduled task with this script and run every hour.

### How does this script work

It checks if XenDesktop catalog has minimum 8 free VDIs and:
* Deploys VDIs till free VDI count is 8. 
* If catalog already has 8 VDIs, it quits.

### Who can use

Citrix Admins whose task is to maintain free VDIs in the pool.

### Built With

* [PowerShell](https://en.wikipedia.org/wiki/PowerShell) - Powershell

### Authors

* **Chay Scripts** - [ChayScripts](https://github.com/ChayScripts)

### Contributing

Please follow [github flow](https://guides.github.com/introduction/flow/index.html) for contributing.

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
