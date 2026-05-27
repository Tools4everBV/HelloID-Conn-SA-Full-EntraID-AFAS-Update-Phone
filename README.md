# HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone

| :information_source: Information |
| :------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

## Description
_HelloID-Conn-SA-Full-EntraID-AFAS-Update-Phone_ is a template designed for use with HelloID Service Automation (SA) Delegated Forms. It can be imported into HelloID and customized according to your requirements. 

By using this delegated form, you can manage resource attributes across your connected systems. The following options are available:
 1. Search and select the resource
 2. Enter new values for the resource attributes
 3. The entered values are validated
 4. Resource attributes are updated with new values across connected systems
 5. Writing back values will be handled according to system-specific rules and configurations

## Getting started
### Requirements

#### App Registration & Certificate Setup

Before implementing this connector, make sure to configure a Microsoft Entra ID, an App Registration. During the setup process, you’ll create a new App Registration in the Entra portal, assign the necessary API permissions (such as user and group read/write), and generate and assign a certificate.

Follow the official Microsoft documentation for creating an App Registration and setting up certificate-based authentication:
- [App-only authentication with certificate (Exchange Online)](https://learn.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps#set-up-app-only-authentication)

#### HelloID-specific configuration

Once you have completed the Microsoft setup and followed their best practices, configure the following HelloID-specific requirements.

- **API Permissions** (Application permissions):
  - `User.ReadWrite.All`
  - `User-Phone.ReadWrite.All`
- **Certificate:**
  - Upload the public key file (.cer) in Entra ID
  - Provide the certificate as a Base64 string in HelloID. For instructions on creating the certificate and obtaining the base64 string, refer to our forum post: [Setting up a certificate for Microsoft Graph API in HelloID connectors](https://forum.helloid.com/forum/helloid-provisioning/5338-instruction-setting-up-a-certificate-for-microsoft-graph-api-in-helloid-connectors#post5338)


### Connection settings

The following user-defined variables are used by the connector.

| Setting                           | Description                                                            | Mandatory |
| --------------------------------- | ---------------------------------------------------------------------- | --------- |
| EntraIdAppId                      | The Application (client) ID of the Entra ID app registration           | Yes       |
| EntraIdTenantId                   | The Directory (tenant) ID of the Entra ID tenant                       | Yes       |
| EntraIdCertificateBase64String    | The Base64 encoded certificate string for Entra ID authentication      | Yes       |
| EntraIdCertificatePassword        | The password for the certificate                                       | Yes       |
| AFASBaseUrl                       | The base URL to the AFAS Profit REST API                               | Yes       |
| AFASToken                         | The AppConnector token for AFAS Profit authentication                  | Yes       |
| companyName                       | The company name (used for display purposes only)                      | No        |

## Remarks

### Certificate-Based Authentication Required
- **Entra ID Authentication**: This connector uses certificate-based authentication for Microsoft Entra ID instead of client credentials. The certificate must be properly configured in the app registration and provided as a Base64 encoded string with its password.

### AFAS Employee Matching
- **Employee ID Correlation**: The connector correlates Entra ID users with AFAS employees using the Employee ID field. If no matching AFAS employee is found, the update for AFAS will be skipped, but the Entra ID update will still proceed.

### Phone Number Validation
- **Pattern Validation**: The form includes RegEx pattern validation for mobile and fixed phone numbers. The default patterns are:
  - Mobile Phone: `^\\+316\\d{8}$` (format: +31612345678)
  - Business Phone: `^(088-123)+[0-9]{4}$` (format: 088-123xxxx)
  
  These patterns should be adjusted according to your organization's phone number format requirements.

### No Changes Detection
- **Skip Unnecessary Updates**: The connector checks if the phone numbers in AFAS are already set to the requested values. If no changes are detected, the update operation is skipped to avoid unnecessary API calls and potential errors.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                                                | Description                                         |
| ------------------------------------------------------- | --------------------------------------------------- |
| https://graph.microsoft.com/v1.0/users/{id}             | Update Entra ID user attributes                     |
| https://login.microsoftonline.com/{tenant}/oauth2/token | Obtain access token for Microsoft Graph API         |
| {AFASBaseUrl}/connectors/T4E_HelloID_Users_v2           | Retrieve AFAS employee information                  |
| {AFASBaseUrl}/connectors/KnEmployee                     | Update AFAS employee phone numbers                  |

### API documentation

- [Microsoft Graph API - Update User](https://learn.microsoft.com/en-us/graph/api/user-update)
- [AFAS Profit REST API Documentation](https://help.afas.nl/help/NL/SE/App_Cnr_Rest_Updconnectors.htm)

## Getting help
> :bulb: **Tip:**  
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/
