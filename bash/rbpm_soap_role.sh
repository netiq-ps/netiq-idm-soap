#! /bin/bash

###########
# Shell script that uses curl to issue SOAP requests to IDMAPPS 
# Each function is coded to provide a few possible use cases for its namesake SOAP request
# This by no means exausts all avaliable options per SOAP request, was meant to automate
#+ building labs and performing tests from command-line agains RBPM 4.5.0
#
# Version: 0.06
# Author: Fernando Freitas
# Last updated on: 2015-05-12 00:18:00 MST
# Validated/tested against NetIQ Identity Manager 4.5.0 only, will probably need to be 
#+ adjusted for other versions of the product.
#
# For more information on the individual SOAP requests please read:
# https://www.netiq.com/documentation/idm45/agpro/data/bbmmtme.html
#
# most functions were designed with the input format being similar to:
# function $USERNAME $PASSWORD $RBPMURL $OUTFILE <other parameters, space-separated>
# If a password of -W is entered, the program will ask for the password
###########

###########
# BASH functions to make role SOAP calls to RBPM
# Copyright (C) 2015  Fernando Freitas
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
###########

###########
# TODO:
#  Decide on a good way to implement:
#  - findRoleByExampleWithOperator
#  - findSodByExample
#  - findSodByExampleWithOperator
# Current challenge is the sheer amount of different valid options, where all
#+ of them can be used simultaneously. Barring some sort of common usage pattern  
#+ the best way might be to use getopts and use parameter names, not only positions.
#
#  Figure how modifyRole works
###########

# -v = verbose, -k = ignore SSL validation, -s = silent, -S show error (used with -s) 
# Example with all the optionsi above:
# export _CURL_OPTIONS="-v -k -sS"
# Default setting does not have -v 
export _CURL_OPTIONS="-k -sS"
# Set _RBPM_SOAP_ROLE_DEBUG to true to enable debugging for each function
#  At the moment this dumps the parameters passed in as well as the POST data 
export _RBPM_SOAP_ROLE_DEBUG="false"

### collection Function: rbpm_soap_role_getVersion
# Usage:
# rbpm_soap_role_getVersion
# Prints the version string for this collection of functions.  
#
rbpm_soap_role_getVersion()
{
echo "Version: 0.06 updated on 2015-05-12 00:18:00 MST"
}

### Function: 
# Usage:
# rbpm_soap_role_connectiontest username password rbpmURL
# Tests the connection to RBPM using the provided username, password and URL. 
# Returns HTTP code and connection as well as the full URL used.
#
rbpm_soap_role_connectiontest()
{
if [[ -z "$1" || -z "$2" || -z "$3" ]]
then
  echo "Please use rbpm_soap_role_connectiontest username password rbpmURL"
  echo "if the password is exactly -W the function will prompt for it"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleLevels'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/><soapenv:Body><ser:getVersionRequest/></soapenv:Body></soapenv:Envelope>"

_CONN_OPTS="--connect-timeout 5 -m 10 -sS"
echo "Using SOAP endpoint $URL"
echo -n "Testing connection: "
curl $_CONN_OPTS -w "HTTP code %{http_code}\\n" -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o /dev/null 
echo -n "Testing connection without SSL/TLS validation: "
curl -k $_CONN_OPTS -w "HTTP code: %{http_code}\\n" -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o /dev/null
}

### Function: createResourceAssociations
# Usage:
# createResourceAssociation $username $password $rbpm_url $output_file $roledn $resourcedn $description $entitlement_parameter
# if the $entitlement_parameter is omitted, will create the association without an entitlement value
#
createResourceAssociation()
{

USAGE="Function Usage:

createResourceAssociation username password rbpm_url output_file role_dn resource_dn description entitlement_value
 The dn should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:
  cn=ResourceName,cn=ResourceDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 If the parameter entitlement_value is omitted the function will not bind a dynamic entitlement value
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/createResourceAssociation'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:createResourceAssociationRequest>\
<ser:resourceAssociation>\
<ser:approvalOverride>false</ser:approvalOverride>\
<ser:dynamicParameters>"

if [[ ! -z "$8" ]] 
then 
POST="${POST}<ser:dynamicparameter>\
<ser:expression>false</ser:expression>\
<ser:key>EntitlementParamKey</ser:key>\
<ser:value>${8}</ser:value>\
</ser:dynamicparameter>"
fi

POST="${POST}</ser:dynamicParameters>\
<ser:entityKey/>\
<ser:localizedDescriptions>\
<ser:localizedvalue>\
<ser:locale>en</ser:locale>\
<ser:value>${7}</ser:value>\
</ser:localizedvalue>\
</ser:localizedDescriptions>\
<ser:resource>${6}</ser:resource>\
<ser:role>${5}</ser:role>\
<ser:status>10</ser:status>\
</ser:resourceAssociation>\
</ser:createResourceAssociationRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request 
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: createRole
# Usage:
# createRole $username $password $rbpm_url $output_file $rolename $description $rolelevel $category $correlation_id
# if the $correlation_id is omitted, will call createRoleRequest, otherwise will call createRoleAidRequest
# if the category is omitted with use the value "default"
# Order of parameters is important, it is not possible to use the correlation_id and skip category
#
createRole()
{

USAGE="Function Usage:

createRole username password rbpm_url output_file rolename description rolelevel category correlation_id
 if the correlation_id is omitted, will call createRoleRequest, otherwise will call createRoleAidRequest
 if the category is omitted with use the value "default"
 Order of parameters is important, it is not possible to provide a correlation_id and skip category at the same time
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ -z "$8" ]]
then
  CAT=default
else
  CAT="$8"
fi

if [[ -z "$9" ]]
then
  NOCID=true
else
  NOCID=false
  CID="$9"
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"

if [[ "$NOCID" = "true" ]]
then
  ACTION="SOAPAction: 'http://www.novell.com/role/service/createRole'"
  SOAPCALL=createRoleRequest
else
  ACTION="SOAPAction: 'http://www.novell.com/role/service/createRoleAid'"
  SOAPCALL=createRoleAidRequest
fi
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:${SOAPCALL}>\
<ser:role>\
<ser:approvers/>\
<ser:container/>\
<ser:description>${6}</ser:description>\
<ser:entityKey/>\
<ser:name>${5}</ser:name>\
<ser:owners/>\
<ser:quorum/>\
<ser:requestDef/>\
<ser:revokeRequestDef/>\
<ser:roleCategoryKeys>\
<ser:categorykey>\
<ser:categoryKey>${CAT}</ser:categoryKey>\
</ser:categorykey>\
</ser:roleCategoryKeys>\
<ser:roleLevel>${7}</ser:roleLevel>\
<ser:systemRole>false</ser:systemRole>\
</ser:role>"

if [[ "$NOCID" = "false" ]] 
then
  POST="${POST}<ser:correlationId>${CID}</ser:correlationId>"
fi

POST="${POST}</ser:${SOAPCALL}>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: deleteResourceAssociations
# Usage:
# deleteResourceAssociation $username $password $rbpm_url $output_file $resource_assoc_dn
#
deleteResourceAssociation()
{

USAGE="Function Usage:

deleteResourceAssociation username password rbpm_url output_file resource_assoc_dn
 The dn should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:
  cn=20150430183939-307869dafa2341d683e1df1963bfcc99,cn=ResourceAssociations,cn=ResourceName,cn=ResourceDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/deleteResourceAssociation'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:deleteResourceAssociationRequest>\
<ser:resourceAssociationDn>\
<ser:dn>${5}</ser:dn>\
</ser:resourceAssociationDn>\
</ser:deleteResourceAssociationRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getAssignedIdentities
# Usage:
# getAssignedIdentities $username $password $rbpm_url $output_file $roleDN $identityType $direct
#
getAssignedIdentities()
{

USAGE="Function Usage:

getAssignedIdentities username password rbpm_url output_file roleDN identityType direct
 The dn should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:  cn=Role,cn=Level30,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 identityType type can be USER, GROUP, CONTAINER or ROLE
 direct can be true or false, and it is only used when USER is provided as Identity
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ -z "$7" ]]
then
   if [[ "X$6" = "XUSER" ]]
   then 
     DIRECT="true"
   else
     DIRECT="false"
   fi
else
  DIRECT="$7"
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getAssignedIdentities'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getAssignedIdentitiesRequest>\
<ser:roleDN>${5}</ser:roleDN>\
<ser:identityType>${6}</ser:identityType>\
<ser:directAssignOnly>${DIRECT}</ser:directAssignOnly>\
</ser:getAssignedIdentitiesRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getConfigPropertyRequest
# Usage:
# getConfigPropertyRequest $username $password $rbpm_url $output_file $property
#
getConfigPropertyRequest()
{

USAGE="Function Usage:

getConfigPropertyRequest username password rbpm_url output_file property
 The property is the / separated path to the property, for example:
  WorkflowService/SOAP-End-Points-Accessible-By-ProvisioningAdminOnly
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getConfigProperty'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getConfigPropertyRequest>\
<ser:configPropertyKey>${5}</ser:configPropertyKey>\
</ser:getConfigPropertyRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getConfigurationRequest
# Usage:
# getConfigurationRequest $username $password $rbpm_url $output_file
#
getConfigurationRequest()
{

USAGE="Function Usage:

getConfigurationRequest username password rbpm_url output_file
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getConfiguration'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getConfigurationRequest/>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getContainerRequest
# Usage:
# getContainerRequest $username $password $rbpm_url $output_file $containerDN
#
getContainerRequest()
{

USAGE="Function Usage:

getContainerRequest username password rbpm_url output_file containerDN
 The containerDN is the LDAP FDN of the desired container, for example:
  ou=users,o=vault
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getContainer'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getConfigPropertyRequest>\
<ser:configPropertyKey>${5}</ser:configPropertyKey>\
</ser:getConfigPropertyRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getExceptionsListRequest
# Usage:
# getExceptionsListRequest $username $password $rbpm_url $output_file $identityDN $identityType
#
getExceptionsListRequest()
{

USAGE="Function Usage:

getExceptionsListRequest username password rbpm_url output_file identityDN identityType
 The dn should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:  cn=user,ou=people,o=vault
 identityType type can be USER, GROUP, CONTAINER or ROLE
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getExceptionsList'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getExceptionsListRequest>\
<ser:identityDN>${5}</ser:identityDN>\
<ser:identityType>${6}</ser:identityType>\
</ser:getExceptionsListRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getGroupRequest
# Usage:
# getGroupRequest $username $password $rbpm_url $output_file $containerDN
#
getGroupRequest()
{

USAGE="Function Usage:

getGroupRequest username password rbpm_url output_file containerDN
 The groupDN is the LDAP FDN of the desired group, for example:
  cn=group,ou=groups,o=vault
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getGroup'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getGroupRequest>\
<ser:groupDN>${5}</ser:groupDN>\
</ser:getGroupRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}


### Function: getIdentitiesinViolation
# Usage:
# getIdentitiesinViolation $username $password $rbpm_url $output_file $SoDDN
#
getIdentitiesinViolation()
{

USAGE="Function Usage:

getIdentitiesinViolation username password rbpm_url output_file SoDDN
 The SoDDN is the LDAP FDN of the desired SoD, for example:
  cn=SoD,cn=SoDDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getIdentitiesInViolation'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getIdentitiesInViolationRequest>\
<ser:sodDN>${5}</ser:sodDN>\
</ser:getIdentitiesInViolationRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getIdentityRoleConflictsRequest
# Usage:
# getIdentityRoleConflictsRequest $username $password $rbpm_url $output_file $identityDN identityType $roleDN
#
getIdentityRoleConflictsRequest()
{

USAGE="Function Usage:

getIdentityRoleConflictsRequest username password rbpm_url output_file SoDDN
 The identityDN is the LDAP FDN of the desired identity, for example:
  cn=user001,ou=users,o=data
 identityType type can be USER, GROUP, CONTAINER or ROLE
 The roleDN is the LDAP FDN of the desired role, for example:
  cn=Role,cn=Level20,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getIdentityRoleConflicts'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getIdentityRoleConflictsRequest>\
<ser:identityDN>${5}</ser:identityDN>\
<ser:identityType>${6}</ser:identityType>\
<ser:rolesDN>\
<ser:dnstring>\
<ser:dn>${7}</ser:dn>\
</ser:dnstring>\
</ser:rolesDN>\
</ser:getIdentityRoleConflictsRequest>
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getResourceAssociation
# Usage:
# getResourceAssociation $username $password $rbpm_url $output_file $resourceAssociationDN
#
getResourceAssociation()
{

USAGE="Function Usage:

getResourceAssociation username password rbpm_url output_file resourceAssociationDN
 The resourceAssociationDN is the LDAP FDN of the resource association object, for example:
  cn=20150413184813-813d1697ddd64d4d9b9cbe6ccfc38eeb,cn=ResourceAssociations,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getResourceAssociation'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getResourceAssociationRequest>\
<ser:resourceAssociationDn>\
<ser:dn>${5}</ser:dn>\
</ser:resourceAssociationDn>\
</ser:getResourceAssociationRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getResourceAssociations
# Usage:
# getResourceAssociations $username $password $rbpm_url $output_file $dn $dn_type
#
getResourceAssociations()
{

USAGE="Function Usage:

getResourceAssociations username password rbpm_url output_file dn dn_type
 dn_type should be either role or resource
 dn should be in full ldap format, for example:
  cn=ResourceName,cn=ResourceDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getResourceAssociations'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getResourceAssociationsRequest>"

if [ "X$6" = "Xrole" ] 
then 
POST="${POST}<ser:roleDn>\
<ser:dn>${5}</ser:dn>\
</ser:roleDn>"
elif [ "X$6" = "Xresource" ]
then
POST="${POST}<ser:resourceDn>\
<ser:dn>${5}</ser:dn>\
</ser:resourceDn>"
else
  echo "Invalid dn_type: $6"
  echo "$USAGE"
  return 1
fi

POST="${POST}</ser:getResourceAssociationsRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRole
# Usage:
# getRole $username $password $rbpm_url $output_file $roleDN
#
getRole()
{

USAGE="Function Usage:

getRole username password rbpm_url output_file roleDN
 The roleDN is the LDAP FDN of the role object, for example:
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRole'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleRequest>\
<ser:roleDN>${5}</ser:roleDN>\
</ser:getRoleRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleAssignmentRequestStatus
# Usage:
# getRoleAssignmentRequestStatus $username $password $rbpm_url $output_file $correlationID
#
getRoleAssignmentRequestStatus()
{

USAGE="Function Usage:

getRoleAssignmentRequestStatus username password rbpm_url output_file correlationID
 The correlationID is the value used to link requests together, for example:
  UserApp#RoleRequest#a2d56181-7518-4b30-bb5f-72e4e0216267
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleAssignmentRequestStatus'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleAssignmentRequestStatusRequest>\
<ser:correlationId>${5}</ser:correlationId>\
</ser:getRoleAssignmentRequestStatusRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleAssignmentRequestStatusByDN
# Usage:
# getRoleAssignmentRequestStatusByDN $username $password $rbpm_url $output_file $requestDN
#
getRoleAssignmentRequestStatusByDN()
{

USAGE="Function Usage:

getRoleAssignmentRequestStatusByDN username password rbpm_url output_file requestDN
 The requestDN is the LDAP FDN of the role object, for example:
  cn=20150507145211-d30c854046c746e0952ddb9bd63a87e7-0,cn=Requests,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleAssignmentRequestStatusByDN'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleAssignmentRequestStatusByDNRequest>\
<ser:requestDNs>\
<ser:dnstring>\
<ser:dn>${5}</ser:dn>\
</ser:dnstring>\
</ser:requestDNs>\
</ser:getRoleAssignmentRequestStatusByDNRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleAssignmentRequestStatusByIdentityType
# Usage:
# getRoleAssignmentRequestStatusByIdentityType $username $password $rbpm_url $output_file $identityDN $identityType
#
getRoleAssignmentRequestStatusByIdentityType()
{

USAGE="Function Usage:

getRoleAssignmentRequestStatusByIdentityType username password rbpm_url output_file identityDN identityType
 The identityDN should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:  cn=user001,ou=users,o=vault
 identityType type can be USER, GROUP, CONTAINER or ROLE
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleAssignmentRequestStatusByIdentityType'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleAssignmentRequestStatusByIdentityTypeRequest>\
<ser:identityDN>${5}</ser:identityDN>\
<ser:identityType>${6}</ser:identityType>\
</ser:getRoleAssignmentRequestStatusByIdentityTypeRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleAssignmentTypeInfo
# Usage:
# getRoleAssignmentTypeInfo $username $password $rbpm_url $output_file $assignmentType
#
getRoleAssignmentTypeInfo()
{

USAGE="Function Usage:

getRoleAssignmentTypeInfo username password rbpm_url output_file assignmentType
 The assignmentType can be one of the following values:
USER_TO_ROLE , GROUP_TO_ROLE , CONTAINER_TO_ROLE or ROLE_TO_ROLE
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleAssignmentTypeInfo'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleAssignmentTypeInfoRequest>\
<ser:roleAssignmentType>${5}</ser:roleAssignmentType>\
</ser:getRoleAssignmentTypeInfoRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleCategories
# Usage:
# getRoleCategories $username $password $rbpm_url $output_file
#
getRoleCategories()
{

USAGE="Function Usage:

getRoleCategories username password rbpm_url output_file
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleCategories'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleCategoriesRequest/>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleConflicts
# Usage:
# getRoleConflicts $username $password $rbpm_url $output_file $roleDN
#
getRoleConflicts()
{

USAGE="Function Usage:

getRoleConflicts username password rbpm_url output_file roleDN
 The roleDN is the LDAP FDN of the role object, for example:
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleConflicts'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleConflictsRequest>\
<ser:rolesDN>\
<ser:dnstring>\
<ser:dn>${5}</ser:dn>\
</ser:dnstring>\
</ser:rolesDN>\
</ser:getRoleConflictsRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleLevels
# Usage:
# getRoleLevels $username $password $rbpm_url $output_file
#
getRoleLevels()
{

USAGE="Function Usage:

getRoleLevels username password rbpm_url output_file
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleLevels'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleLevelsRequest/>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRoleLocalizedStrings
# Usage:
# getRoleLocalizedStrings $username $password $rbpm_url $output_file $roleDN $stringtype
#
getRoleLocalizedStrings()
{

USAGE="Function Usage:

getRoleLocalizedStrings username password rbpm_url output_file roleDN stringtype
 The roleDN should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:  cn=Role,cn=Level30,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 stringtype should be 1 for role names, 2 for descriptions.
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleLocalizedStrings'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRoleLocalizedStringsRequest>\
<ser:roleDn>\
<ser:dn>${5}</ser:dn>\
</ser:roleDn>\
<ser:type>${6}</ser:type>\
</ser:getRoleLocalizedStringsRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRolesInfo
# Usage:
# getRolesInfo $username $password $rbpm_url $output_file $roleDN
#
getRolesInfo()
{

USAGE="Function Usage:

getRolesInfo username password rbpm_url output_file roleDN
 The roleDN is the LDAP FDN of the role object, for example:
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRolesInfo'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRolesInfoRequest>\
<ser:roleDns>\
<ser:dnstring>\
<ser:dn>${5}</ser:dn>\
</ser:dnstring>\
</ser:roleDns>\
</ser:getRolesInfoRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRolesInfoByCategory
# Usage:
# getRolesInfoByCategory $username $password $rbpm_url $output_file $category
#
getRolesInfoByCategory()
{

USAGE="Function Usage:

getRolesInfoByCategory username password rbpm_url output_file category
 The category is one of the role categories set in RBPM, the list can be obtained 
 using the SOAP call getRoleCategories
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRolesInfoByCategory'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRolesInfoByCategoryRequest>\
<ser:roleCategoryKeys>\
<ser:categorykey>\
<ser:categoryKey>${5}</ser:categoryKey>\
</ser:categorykey>\
</ser:roleCategoryKeys>\
</ser:getRolesInfoByCategoryRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getRolesInfoByLevel
# Usage:
# getRolesInfoByLevel $username $password $rbpm_url $output_file $level
#
getRolesInfoByLevel()
{

USAGE="Function Usage:

getRolesInfoByLevel username password rbpm_url output_file level
 The level is one of the role levels in RBPM, the list can be obtained 
 using the SOAP call getRoleLevels
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRolesInfoByLevel'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getRolesInfoByLevelRequest>\
<ser:roleLevels>\
<ser:long>${5}</ser:long>\
</ser:roleLevels>\
</ser:getRolesInfoByLevelRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getTargetSourceConflicts
# Usage:
# getTargetSourceConflicts $username $password $rbpm_url $output_file $srcroleDN $destroleDN
#
getTargetSourceConflicts()
{

USAGE="Function Usage:

getTargetSourceConflicts username password rbpm_url output_file srcroleDN destroleDN
 Both src and dest roleDNs are the LDAP FDN their respective role object, for example:
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getTargetSourceConflicts'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getTargetSourceConflictsRequest>\
<ser:sourceRoleDN>${5}</ser:sourceRoleDN>\
<ser:targetRoleDN>${6}</ser:targetRoleDN>\
</ser:getTargetSourceConflictsRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getUser
# Usage:
# getUser $username $password $rbpm_url $output_file $userDN
#
getUser()
{

USAGE="Function Usage:

getUser username password rbpm_url output_file userDN
 userDN is the LDAP FDN of the user object being read, for example:
  cn=user001,ou=users,o=vault
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getUser'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getUserRequest>\
<ser:userDN>${5}</ser:userDN>\
</ser:getUserRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: getVersion
# Usage:
# getVersion $username $password $rbpm_url $output_file
#
getVersion()
{

USAGE="Function Usage:

getVersion username password rbpm_url output_file
 NOTE: This call get the SOAP API version, not the IDM/RBPM version
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getRoleLevels'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:getVersionRequest/>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: isUserInRole
# Usage:
# isUserInRole $username $password $rbpm_url $output_file $userDN $roleDN
#
isUserInRole()
{

USAGE="Function Usage:

isUserInRole username password rbpm_url output_file userDN roleDN
 Both userDNc and roleDN are the LDAP FDN their respective objects, for example:
  cn=user001,ou=users,o=vault
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/getTargetSourceConflicts'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:isUserInRoleRequest>\
<ser:userDN>${5}</ser:userDN>\
<ser:roleDN>${6}</ser:roleDN>\
</ser:isUserInRoleRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: modifyRole  #### Cannot get it to change anything in SOAPUI. Need further testing. 
# Usage:
# modifyRole $username $password $rbpm_url $output_file $rolename $modification $value $correlation_id
# only a subset of the SOAP call capabilities is exposed by this function
# if the $correlation_id is omitted, will call modifyRoleRequest, otherwise will call modifyRoleAidRequest
#
# Note from the forums:
#  The correct endpoint to use for adding/removing a child role is the
#+ same one that you use to add/remove a user: requestRoleAssignment. If
#+ you were to create a Parent-Child relationship in the UI you would see
#+ that a Role Request is created in the UA for this.
#

modifyRole()
{

USAGE="Function Usage:

modifyRole username password rbpm_url output_file rolename modification value correlation_id
 modification can be . Note that this does not cover everything the SOAP call can do, only what this function has been coded to handle
 if the $correlation_id is omitted, will call modifyRoleRequest, otherwise will call modifyRoleAidRequest
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ -z "$8" ]]
then
  NOCID=true
else
  NOCID=false
  CID="$8"
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"

if [[ "$NOCID" = "true" ]]
then
  ACTION="SOAPAction: 'http://www.novell.com/role/service/modifyRole'"
  SOAPCALL=modifyRoleRequest
else
  ACTION="SOAPAction: 'http://www.novell.com/role/service/modifyRoleAid'"
  SOAPCALL=modifyRoleAidRequest
fi
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:${SOAPCALL}>\
<ser:role>\
<ser:entityKey>cn=itrole007,cn=Level20,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=rbpm,cn=ds,ou=iam,o=system</ser:entityKey>\
<ser:name>itrole007_mod</ser:name>\
<ser:owners>\
<ser:dnstring>\
<ser:dn>cn=contuser005,ou=contractors,ou=people,o=vault</ser:dn>\
</ser:dnstring>\
</ser:owners>\
<ser:roleCategoryKeys>\
<ser:categorykey>\
<ser:categoryKey>aon</ser:categoryKey>\
</ser:categorykey>\
</ser:roleCategoryKeys>\
<ser:roleLevel>\
<ser:level>20</ser:level>\
</ser:roleLevel>\
<ser:systemRole>false</ser:systemRole>
</ser:role>"

if [[ "$NOCID" = "false" ]] 
then
  POST="${POST}<ser:correlationId>${CID}</ser:correlationId>"
fi

POST="${POST}</ser:${SOAPCALL}>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: removeRoles 
# Usage:
# removeRoles $username $password $rbpm_url $output_file $roleDN $correlation_id
# if the $correlation_id is omitted, will call removeRolesRequest, otherwise will call removeRolesAidRequest
#

removeRoles()
{

USAGE="Function Usage:

removeRoles username password rbpm_url output_file rolename correlation_id
 The roleDN is the LDAP FDN of the role object, for example:
  cn=RoleName,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 if the correlation_id is omitted, will call removeRolesRequest, otherwise will call removeRolesAidRequest
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ -z "$6" ]]
then
  NOCID=true
else
  NOCID=false
  CID="$6"
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"

if [[ "$NOCID" = "true" ]]
then
  ACTION="SOAPAction: 'http://www.novell.com/role/service/removeRoles'"
  SOAPCALL=removeRolesRequest
else
  ACTION="SOAPAction: 'http://www.novell.com/role/service/removeRolesAid'"
  SOAPCALL=removeRolesAidRequest
fi
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:${SOAPCALL}>\
<ser:roleDns>\
<ser:dnstring>\
<ser:dn>${5}</ser:dn>\
</ser:dnstring>\
</ser:roleDns>"

if [[ "$NOCID" = "false" ]] 
then
  POST="${POST}<ser:correlationId>${CID}</ser:correlationId>"
fi

POST="${POST}</ser:${SOAPCALL}>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: requestRolesAssignment
# Usage:
# requestRolesAssignment $username $password $rbpm_url $output_file $action $assignmentType $identityDN $originator $reason $roleDN $effectiveDate $expirationDate $correlationID
#
requestRolesAssignment()
{

USAGE="Function Usage:

requestRolesAssignment username password rbpm_url output_file action assignmentType identityDN originator reason roleDN effectiveDate expirationDate correlationID
 action should be either grant or revoke
 assignmentType should be one of:
  USER_TO_ROLE , GROUP_TO_ROLE , CONTAINER_TO_ROLE or ROLE_TO_ROLE .
  In the case of role to role the roleDN becomes a child role of the identityDN
 originator and reason are text strings
 identityDN and roleDN should be in full ldap format. for example:
  o=vault
  cn=group,ou=groups,o=vault
  cn-user001,ou=users,o=vault
  cn=Role,cn=Level30,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 effectiveDate and expirationDate should be date and time in a format like: 
  2030-01-27T11:05:00
 correlationID can be skipped, it is auto-generated by the system if not provided
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6"\
 || -z "$7" || -z "$8" || -z "$9" || -z "${10}" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/requestRolesAssignment'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:requestRolesAssignmentRequest>\
<ser:assignRequest>\
<ser:actionType>${5}</ser:actionType>\
<ser:assignmentType>${6}</ser:assignmentType>"

if [[ -z "${13}" ]]
then
  POST="${POST}<ser:correlationID/>"
else
  POST="${POST}<ser:correlationID>${13}</ser:correlationID>"
fi

if [[ -z "${11}" || -z "${12}" ]]
then
  :
else
  POST="${POST}<ser:effectiveDate>${11}</ser:effectiveDate>"
  POST="${POST}<ser:expirationDate>${12}</ser:expirationDate>"
fi

POST="${POST}<ser:identity>${7}</ser:identity>\
<ser:originator>${8}</ser:originator>\
<ser:reason>${9}</ser:reason>\
<ser:roles>\
<ser:dnstring>\
<ser:dn>${10}</ser:dn>\
</ser:dnstring>\
</ser:roles>\
<ser:sodOveridesRequested/>\
</ser:assignRequest>\
</ser:requestRolesAssignmentRequest>\
</soapenv:Body>\
</soapenv:Envelope>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}

### Function: setRoleLocalizedStrings
# Usage:
# setRoleLocalizedStrings $username $password $rbpm_url $output_file $roleDN $stringtype <pairs of locale and value>
#
setRoleLocalizedStrings()
{

USAGE="Function Usage:

setRoleLocalizedStrings username password rbpm_url output_file roleDN stringtype <pairs of locala and value>
 The roleDN should be in full ldap format, and if it has spaces need to be encased in quotes.
 for example:  cn=Role,cn=Level30,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UAD,cn=driverset,o=system
 stringtype should be 1 for role names, 2 for descriptions.
 <pairs of locale and value> -> Since we are setting (overwriting) existing strings, it is necessary to add all locales and texts in pairs, each value double-quoted on its on. 
 for example(setting 2 localized descriptions):
  'en' 'Business Role' 'pt' 'Regra de Negocio'
 rbpm_url should be in the format:
  protocol://server:port/servicename
 for example:
  https://rbpm.lab.novell.com:8543/IDMProv";

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  dbgparams=$#
  dbgparam=1
  while [ "$dbgparam" -le "$dbgparams" ]
  do
    echo -n "Parameter " 
    echo -n \$$dbgparam
    echo -n " = "
    eval echo \$$dbgparam
    (( dbgparam++ ))
  done
fi

# Initial Parameters check
if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" || -z "$8" ]]
then
  echo "$USAGE"
  return 1
fi

PARAMS=$#
PARAM=7               # first locale positional parameter
let "Z = $PARAMS % 2"
if [[ $Z = "1" ]]
then
  echo "$USAGE"
  return 1
fi

if [[ "X$2" = "X-W" ]]
then
  read -sp "Please enter the password for user $1: " SENHA
  echo
else
  SENHA=$2
fi

# Setup for the SOAP call
URL="${3}/role/service"
ACTION="SOAPAction: 'http://www.novell.com/role/service/setRoleLocalizedStrings'"
CTYPE='Content-Type: text/xml;charset=UTF-8'

# Build SOAP XML envelope and call to be issued
POST="<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://www.novell.com/role/service'>\
<soapenv:Header/>\
<soapenv:Body>\
<ser:setRoleLocalizedStringsRequest>\
<ser:roleDn>\
<ser:dn>${5}</ser:dn>\
</ser:roleDn>\
<ser:locStrings>"

while [ "$PARAM" -le "$PARAMS" ]
do
  eval LOCALE=\$$PARAM
  (( PARAM ++ ))
  eval VALUE=\$$PARAM
  POST="${POST}<ser:localizedvalue>"
  POST="${POST}<ser:locale>${LOCALE}</ser:locale>"
  POST="${POST}<ser:value>${VALUE}</ser:value>"
  POST="${POST}</ser:localizedvalue>"

  (( PARAM ++ ))
done

POST="${POST}</ser:locStrings>\
<ser:type>${6}</ser:type>\
</ser:setRoleLocalizedStringsRequest>"

if [[ "X$_RBPM_SOAP_ROLE_DEBUG" = "Xtrue" ]]
then
  echo
  echo POST data:
  echo $POST
  echo
fi

# Issue the request
curl $_CURL_OPTIONS -u "$1:$SENHA" -H "$CTYPE" -H "$ACTION" -d "$POST" "$URL" -o "$4"
}
