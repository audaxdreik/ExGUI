# Example GUI

## Introduction

Practice project demonstrating three-tier architecture.

![alt-text](https://github.com/audaxdreik/ExGUI/raw/master/media/sample_exgui.png "sample application screenshot")

## Design

* **Presentation:** WPF (Windows Presentation Foundation)
* **Application:** PowerShell
* **Data:** SQLite

Quick prototyping: PowerShell will consume Visual Studio generated XAML to render WPF application. Query sample SQLite database to retrieve stored data and calculate some derived data to present to user.

## Use & Requirements

In order to use the application, the example database (exdb.db) must be located in the same directory as the ExGUI.ps1 script. Ensure your PowerShell execution policy has been set to allow the script to run or enter `Set-ExecutionPolicy -ExecutionPolicy Bypass` to override it for the current session only. Then run,

`.\ExGUI.ps1 -Verbose`

Requires PowerShell version 7.0+

## Examples

The sample database (exdb.db) contains one table (Test) with 5 users,

| FirstName | LastName |
| --------- | -------- |
| Mary      | Black    |
| Austin    | Derck    |
| John      | Doe      |
| Tom       | Smith    |
| Sally     | Sue      |

To find a user's exact age, leave the Action radio button set to **Query** and enter a first and last name in the respective text boxes under Information, then click the Execute button. If a user is found, the DOB field will update with the date of birth on record and the Age field will show their exact, calculated age. If the queried user does not yet exist in the database, the status bar will inform you that no user has been found.

To create a new user or update an existing user, set the Action radio button to **Update** and enter a first name, last name, and date of birth in the respective text boxes under Information, then click the Execute button. If a user with matching first and last names already exists, you will be notified with a pop-up to update that record with the new DOB specified in the date picker. Otherwise, the user record will be created and the status bar will inform you of the action's success.