# Continuous Delivery Automation Framework (CDAF)

For principles and usage guidance see [https://cdaf.io](https://cdaf.io/10-cdaf/index.html).

For the complete set of samples and provisioning helpers, see [GitHub](https://github.com/cdaf/windows).

For related blog, see [LinkedIn articles](https://www.linkedin.com/in/jules-clements-842b589/recent-activity/articles/).

## Entry arguments

`entry.ps1` (also launched by `entry.bat`) accepts `BUILDNUMBER`, `BRANCH`,
`ACTION`, and `AUTOMATIONROOT`, in that positional order.
`ci.bat` launches `processor\buildPackage.ps1`, preserving its positional order:
`BUILDNUMBER`, `REVISION`, `ACTION`, `SOLUTION`, `AUTOMATIONROOT`,
`LOCAL_WORK_DIR`, and `REMOTE_WORK_DIR`. `-BRANCH` is an alias for `-REVISION`.
Both PowerShell scripts accept case-insensitive named parameters and `-help`,
which displays usage without starting a build or updating the build counter.

```powershell
.\entry.ps1 42 main buildonly
.\entry.ps1 -BUILDNUMBER 42 -BRANCH main -ACTION buildonly
.\ci.bat 42 main -ACTION packageonly -LOCAL_WORK_DIR "local tasks"
```

Named and positional arguments can be mixed: positional values fill parameters
not supplied by name, in the order above.
`skipenv` remains exclusive to `processor\cdEmulate.ps1`.
