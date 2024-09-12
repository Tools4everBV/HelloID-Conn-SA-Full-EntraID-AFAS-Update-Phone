# HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone](#helloid-conn-sa-full-entraid-afas-update-phone)
  - [Table of contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Remarks](#remarks)
  - [Introduction](#introduction)
      - [Description](#description)
      - [Endpoints](#endpoints)
      - [Form Options](#form-options)
      - [Task Actions](#task-actions)
  - [Connector Setup](#connector-setup)
    - [Variable Library - User Defined Variables](#variable-library---user-defined-variables)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Requirements
1. **HelloID Environment**:
   - Set up your _HelloID_ environment.
2. **Entra ID**:
   - App registration with `API permissions` of the type `Application`:
      -  `User.ReadWrite.All`
   - The following information for the app registration is needed in HelloID:
      - `Application (client) ID`
      - `Directory (tenant) ID`
      - `Secret Value`
3. **AFAS Profit**:
   - AFAS tenant id
   - AppConnector token
   - Loaded AFAS GetConnector
     - Tools4ever - HelloID - T4E_HelloID_Users_v2.gcn
     - https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Employees
   - Build-in Profit update connector: KnEmployee

## Remarks
- None at this time.

## Introduction

#### Description
_HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone_ is a template designed for use with HelloID Service Automation (SA) Delegated Forms. It can be imported into HelloID and customized according to your requirements. 

By using this delegated form, you can update the mobile phone and business phone in Entra ID and AFAS Profit. The following options are available:
 1. Search and select the Entra ID user
 2. Enter new values for the following Entra ID account attributes: mobile phone and business phone
 3. The entered mobile phone and business phone are validated
 4. Entra ID account [mobile phone and business phone] and AFAS employee [TeNr and MbNr] attributes are updated with new values
 5. Writing back [TeNr and MbNr] in AFAS will be skipped if the employee is not found in AFAS

#### Endpoints
Entra Id and AFAS Profit provide a set of REST APIs that allow you to programmatically interact with its data. The API endpoints listed in the table below are used.

| Endpoint                      | Description                        |
| ----------------------------- | ---------------------------------- |
| users                         | The user endpoint of the Graph API |
| profitrestservices/connectors | AFAS endpoint                      |

#### Form Options
The following options are available in the form:

1. **Lookup user**:
   - This Powershell data source runs an Entra ID query to search for matching Entra ID accounts.
2. **Validate mobile phone and business phone**:
   - The mobile phone and business phone fields are validated by a RegEx, please change them according to your needs

#### Task Actions
The following actions will be performed based on user selections:

1. **Update mobile phone and business phone in Entra ID**:
   - On the Entra ID account the attributes mobile phone and business phone will be updated.
2. **Update TeNr and MbNr in AFAS Profit Employee**:
   - On the AFAS employee the attributes TeNr and MbNr will be updated.

## Connector Setup
### Variable Library - User Defined Variables
The following user-defined variables are used by the connector. Ensure that you check and set the correct values required to connect to the API.

| Setting          | Description                                                     |
| ---------------- | --------------------------------------------------------------- |
| `EntraTenantId`  | The ID to the Tenant in Microsoft Entra ID                      |
| `EntraAppId`     | The ID to the App Registration in Microsoft Entra ID            |
| `EntraAppSecret` | The Client Secret to the App Registration in Microsoft Entra ID |
| `AFASBaseUrl`    | The URL to the AFAS environment REST service                    |
| `AFASToken`      | The password to the P12 certificate of your service account     |

## Getting help
> [!TIP]
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/