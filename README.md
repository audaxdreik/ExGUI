# Example GUI

## Introduction

Quick practice project demonstrating three-tier architecture.

## Design

* **Presentation:** WPF
* **Application:** PowerShell
* **Data:** SQLite

Quick prototyping: PowerShell will consume VS generated XAML to render WPF application. Query sample SQLite database to retrieve stored data and calculate some derived data to present to user.

## Work in Progress

* Add application icon (base 64 encoding to avoid loose resources)
* Apply polish. After core functionality achieved, add more robust error handling and test cases