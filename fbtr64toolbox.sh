#!/bin/bash
#------------------------------------------------------------------------------
# fbtr64toolbox.sh
#
# Command line tool for the TR-064 interface of fritzboxes
#
# Copyright (C) 2016-2024 Marcus Roeckrath, marcus(dot)roeckrath(at)gmx(dot)de
#
# Creation:     2016-09-04
# Last Update:  2024-04-05
# Version:      3.2.14
#
# Usage:
#
# fbtr64toolbox.sh [command] [option [value]] .. [option [value]]
#
# For full help use: fbtr64toolbox.sh --help
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#------------------------------------------------------------------------------

# adds, deletes, enables or disables port forwarding on fritzbox
# shows list of port forwardings
# shows external ipv4/ipv6 address
# reboots or reconnects the fritzbox
# infos about fritzbox, wlan, storage, upnp, media server, ddns,
# dect, deflections, homeauto, homeplug, hosts, tam, tr69 and firmware updates
# switches wlans, ftp, smb, upnp, media server, autowol and tam on or off
# status of internet connection
# reconnect to internet
# saves fritzbox configuration
# shows fritzbox log
# shows xml documents from fritzbox
# performs self defined soap request described in a file or on command line
# creates soap request files from documents on fritzbox

version="3.2.14"
copyright="Version: ${version} ; Copyright (C) 2016-2024 Marcus Roeckrath ; License: GPL2"
contact=$(echo "${version}" | sed 's/./ /g')"                                    marcus(dot)roeckrath(at)gmx(dot)de"

# Main xml documents on fritzboxes
mainxmlfiles=" tr64desc.xml igddesc.xml igd2desc.xml fboxdesc.xml usbdesc.xml avmnexusdesc.xml l2tpv3.xml aura.xml "

# Exitcodes
error_0="Success"
error_1="Error on communication with fritzbox"
error_2="Fritzbox not reachable"
error_3="Tool(s) missing"
error_4="Unknown or missing command"
error_5="Unknown option"
error_6="Wrong or missing parameter"
error_7="Configuration error"
error_8="No internet connection"
error_9="No external IPv4 address"
error_10="No external IPv6 address or prefix"
error_11="Function only available in experimental mode"
error_12="SOAP request: File not given/not existing or options not given on command line"
error_13="\${HOME} environment variable is not set or target file for soap sample file not given"
error_14="not found on fritzbox"
error_15="Error downloading fritzbox configuration file"
error_16="Configuration file missing"
error_17="Error on downloading or processing the certificate"
error_18="Error on calculating the secret"
error_255="Include file eislib missing"

# debug mode true/false
debug=false
if ${debug:-false}
then
    exec 2>/tmp/fbtr64toolbox-$$.log
    set -x
    ask_debug=true
    export ask_debug
fi

# Neccessary include file for formatted output from eisfair distribution (www.eisfair.org).
# On eisfair it resides in /var/install/include.
# A shortened version of this include file is available from the author of this script.
# Store this file in /usr/share/doc/fbtr64toolbox or in the same directory
# where the script is located.
if [ -f /var/install/include/eislib ]
then
    . /var/install/include/eislib
else
    if [ -f /usr/share/doc/fbtr64toolbox/eislib ]
    then
        . /usr/share/doc/fbtr64toolbox/eislib
    else
        if [ -f "$(dirname "$(readlink -e "${0}")")"/eislib ]
        then
            . "$(dirname "$(readlink -e "${0}")")"/eislib
        else
            echo "Neccessary include file eislib not found."
            echo "Please read documentation."
            exit 255
        fi
    fi
fi

if [ -n "${HOME}" ]
then
    configfile="${HOME}/.fbtr64toolbox"
    if (echo "${*}" | grep -q "\--conffilesuffix")
    then
        conffilesuffix="$(echo "${*}" | sed -r 's/.*--conffilesuffix[ \t]+([^ \t]*)[ \t]?.*/\1/g' | grep -E "^[_a-zA-Z0-9]+$")"
        if [ -n "${conffilesuffix}" ]
        then
            configfile=${configfile}.${conffilesuffix}
        else
            mecho --error "Wrong or no value for configuration file suffix given!"
            mecho --error "Only string containing a-z, A-Z, 0-9 and _ is allowed."
            mecho --error "f. e. \"--conffilesuffix Router3\" resulting in configuration file \"${HOME}/.fbtr64toolbox.Router3\"."
            exit 6
        fi
    fi
    soapfile="${HOME}/fbtr64toolbox.samplesoap"
    netrcfile="${HOME}/.netrc"
fi

# Begin settings section ---------------------------------------------
#
# Do not change the default values here, create a configuration file with
#
# fbtr64toolbox.sh writeconfig
#
# in your Home directory; HOME envrionment variable has to be set!
#
# Address (IP or FQDN)
FBIP="192.168.178.1"
# SOAP port; do not change
FBPORT="49000"
# SSL SOAP port; will be read from the fritzbox later in this script.
FBPORTSSL="49443"

# Fixes for faulty fritzboxes
FBREVERSEPORTS="false"
FBREVERSEFTPWAN="false"

# Use http or https SOAP request
type="https"

# Authentication settings
user="dslf-config"
password="xxxxx"
secret=""

# Save fritzbox configuration settings
# Absolute path fritzbox configuration file; not empty.
if [ -n "${HOME}" ]
then
    fbconffilepath=${HOME}
else
    fbconffilepath="/tmp"
fi
# Prefix/suffix of configuration file name.
# Model name, serial number, firmware version and date/time stamp will be added.
fbconffileprefix="fritzbox"
fbconffilesuffix="config"
# Password for fritzbox configuration file, could be empty.
fbconffilepassword="xxxxx"

# Default port forwarding settings
# do not change
new_remote_host=""
# Source port
new_external_port="80"
# Protocol TCP or UDP
new_protocol="TCP"
# Target port
new_internal_port="80"
# Target ip
new_internal_client="192.168.178.3"
# Port forward enabled (1) or disabled (0)
new_enabled="1"
# Description (not empty)
new_port_mapping_description="http forward for letsencrypt"
# do not change
new_lease_duration="0"
#
# End settings section -----------------------------------------------

# Read settings from ${HOME}/.fbtr64toolbox overriding above default values
readconfig () {
    command="${1}"
    if [ -n "${configfile}" ] && [ -f "${configfile}" ]
    then
        . "${configfile}"
    else
        if [ "${command}" != "writeconfig" ]
        then
            mecho --error "Configuration file \"${configfile}\" not found, using default values!"
            if [ -n "${conffilesuffix}" ]
            then
                mecho --warn "Use \"fbtr64toolbox.sh writeconfig --conffilesuffix ${conffilesuffix}\" to create a sample"
                mecho --warn "configuration file named \"${configfile}\" and edit it."
            else
                mecho --warn "Use \"fbtr64toolbox.sh writeconfig\" to create a sample configuration file"
                mecho --warn "named \"${configfile}\ and edit it."
            fi
            mecho --warn "The option \"--conffilesuffix <text>\" gives the possibility to create"
            mecho --warn "a configuration file with a special suffix/extension."
            if [ "${command}" = "calcsecret" ]
            then
                mecho --error "Programm terminated: Command \"calcsecret\" requires existing configuration file!"
                mecho --warn "Run \"fbtr64toolbox.sh writeconfig [--conffilesuffix <text>]\", edit the configuration file."
                mecho --warn "and start \"fbtr64toolbox.sh calcsecret\" again."
                exit 16
            fi
        fi
    fi
}

# Check settings
checksettings () {
    configfault=false
    if ! (echo "${FBIP}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$") &&
       ! (echo "${FBIP}" | grep -Eq "^[[:alnum:]]([-]*[[:alnum:]])*(\.[[:alnum:]]([-]*[[:alnum:]])*)*$")
    then
        configfault=true
        faultyparameters="FBIP=\"${FBIP}\""
    fi
    if ! ((echo "${FBPORT}" | grep -Eq "^[[:digit:]]{1,5}$") && \
          [ "${FBPORT}" -ge 1 ]  && [ "${FBPORT}" -le 65535 ])
    then
        configfault=true
        faultyparameters="${faultyparameters}\nFBPORT=\"${FBPORT}\""
    fi
    if ! ((echo "${FBPORTSSL}" | grep -Eq "^[[:digit:]]{1,5}$") && \
          [ "${FBPORTSSL}" -ge 1 ]  && [ "${FBPORTSSL}" -le 65535 ])
    then
        configfault=true
        faultyparameters="${faultyparameters}\nFBPORTSSL=\"${FBPORTSSL}\""
    fi
    if [ "${FBREVERSEPORTS}" != "true" ] && [ "${FBREVERSEPORTS}" != "false" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nFBREVERSEPORTS=\"${FBREVERSEPORTS}\""
    fi
    if [ "${FBREVERSEFTPWAN}" != "true" ] && [ "${FBREVERSEFTPWAN}" != "false" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nFBREVERSEFTPWAN=\"${FBREVERSEFTPWAN}\""
    fi
    if [ "${type}" != "http" ] && [ "${type}" != "https" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\ntype=\"${type}\""
    fi
    if ! (echo "${secret}" | grep -Eq "^[a-z0-9]*$")
    then
        configfault=true
        faultyparameters="${faultyparameters}\nsecret=\"${secret}\""
    fi
    if [ -z "${fbconffilepath}" ] || [ ! -d "${fbconffilepath}" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nfbconffilepath=\"${fbconffilepath}\""
    fi
    if ! ((echo "${new_external_port}" | grep -Eq "^[[:digit:]]{1,5}$") && \
          [ "${new_external_port}" -ge 1 ]  && [ "${new_external_port}" -le 65535 ])
    then
        configfault=true
        faultyparameters="${faultyparameters}}\nnew_external_port=\"${new_external_port}\""
    fi
    if [ "${new_protocol}" != "TCP" ] && [ "${new_protocol}" != "UDP" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nnew_protocol=\"${new_protocol}\""
    fi
    if ! ((echo "${new_internal_port}" | grep -Eq "^[[:digit:]]{1,5}$") && \
          [ "${new_internal_port}" -ge 1 ]  && [ "${new_internal_port}" -le 65535 ])
    then
        configfault=true
        faultyparameters="${faultyparameters}\nnew_internal_port=\"${new_internal_port}\""
    fi
    if ! (echo "${new_internal_client}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$")
    then
        configfault=true
        faultyparameters="${faultyparameters}\nnew_internal_client=\"${new_internal_client}\""
    fi
    if [ "${new_enabled}" != "0" ] && [ "${new_enabled}" != "1" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nnew_enabled=\"${new_enabled}\""
    fi
    if [ -z "${new_port_mapping_description}" ]
    then
        configfault=true
        faultyparameters="${faultyparameters}\nnew_port_mapping_description is empty"
    fi
    if [ "${configfault}" = "true" ]
    then
        if [ -n "${1}" ]
        then
            mecho --error "The configuration file ${1} is faulty!"
        else
            mecho --error "Script default configuration is faulty!"
        fi
        mecho --warn "Faulty parameters:\n${faultyparameters}"
        exit_with_error 7
    fi
}

# Use ${HOME}/.netrc for authentication if present
# avoiding that the password could be seen in environment or process list.
# Rights on ${HOME}/.netrc has to be 0600 (chmod 0600 ${HOME}/.netrc).
# Content of a line in this file for your fritzbox should look like:
# machine <ip of fritzbox> login <user> password <password>
determineauthmethod () {
    if [ -n "${secret}" ]
    then
        detauthmethod="SOAP-Auth (secret/nonce)"
    else
        if [ -n "${netrcfile}" ] && [ -f "${netrcfile}" ] &&
           ((grep -Eq "^[[:space:]]*machine[[:space:]]+${FBIP}[[:space:]]+" "${netrcfile}") ||
           (grep -Eq "^[[:space:]]*machine[[:space:]]+${FBIP}[[:space:]]*$" "${netrcfile}"))
        then
            authmethod="--netrc"
            detauthmethod=".netrc"
        else
            authmethod="-u ${user}:${password}"
            detauthmethod="user/password"
        fi
    fi
}

# Write sample configuration file to ${HOME}/.fbtr64toolbox
writeconfig () {
    echo "Writing script configuration file ${configfile}"
    if [ -n "${secret}" ]
    then
        password=""
    fi
    cat > "${configfile}" << EOF
# Configuration file for fbtr64toolbox.sh
#
# Fritzbox settings
# Address (IP or FQDN)
FBIP="${FBIP}"
# SOAP port; do not change
FBPORT="${FBPORT}"
# SSL SOAP port; will be read from the fritzbox in the script.
FBPORTSSL="${FBPORTSSL}"

# Fixes for faulty fritzboxes / fritzbox firmwares
# Maybe fixed in firmware version 6.80.
# It seams that some of them reverses the values of "NewInternalPort" and
# "NewExternalPort" in function "GetGenericPortMapEntry" of "WANIPConnection:1"
# resp. "WANPPPConnection:1".
# Set this to true if you are affected."
FBREVERSEPORTS="${FBREVERSEPORTS}"
# It seams that some of them reverses the values of "NewFTPWANEnable" and
# "NewFTPWANSSLOnly" in function "SetFTPWANServer" of "X_AVM-DE_Storage:1".
# Set this to true if you are affected."
FBREVERSEFTPWAN="${FBREVERSEFTPWAN}"

# Use http or https SOAP request
# Normally http requests are much faster than https requests.
type="${type}"

# Authentication settings
# dslf-config is the standard user defined in TR-064 with web login password.
# You can use any other user defined in your fritzbox with sufficient rights.
#
# Instead of writing down your password here it is safer to use \${HOME}/.netrc
# for the authentication data avoiding that the password could be seen in
# environment or process list.
# Rights on \${HOME}/.netrc has to be 0600: chmod 0600 \${HOME}/.netrc
# Content of a line in this file for your fritzbox should look like:
# machine <ip of fritzbox> login <user> password <password>
# f. e.
# machine ${FBIP} login ${user} password ${password}
# The fritzbox address has to be given in the same type (ip or fqdn) in
# \${HOME}/.fbtr64toolbox or on command line parameter --fbip and \${HOME}/.netrc.
#
# Saviest solution for authentication is the use of "user" and hashed "secret".
# Write down "user" and "password into this file an run "fbtrtoolbox calcsecret"
# which will calculate the "secret", stores it in this configuration file and
# removes the password from it.
user="${user}"
password="${password}"
secret="${secret}"

# Save fritzbox configuration settings
# Absolute path to fritzbox configuration file; not empty.
fbconffilepath="${fbconffilepath}"
# Prefix/suffix of configuration file name.
# Model name, serial number, firmware version and date/time stamp will be added.
# "_" is added to prefix and "." is added to suffix automatically so that name
# will be: prefix_<model>_<serialno>_<firmwareversion>_<date_time>.suffix
fbconffileprefix="${fbconffileprefix}"
fbconffilesuffix="${fbconffilesuffix}"
# Password for fritzbox configuration file, could be empty.
# Configuration files without password could be restored to
# the same fritzbox not to a different fritzbox.
fbconffilepassword="${fbconffilepassword}"

# Default port forwarding settings
# do not change
new_remote_host="${new_remote_host}"
# Source port
new_external_port="${new_external_port}"
# Protocol TCP or UDP
new_protocol="${new_protocol}"
# Target port
new_internal_port="${new_internal_port}"
# Target ip address
new_internal_client="${new_internal_client}"
# Port forward enabled (1) or disabled (0)
new_enabled="${new_enabled}"
# Description (not empty)
new_port_mapping_description="${new_port_mapping_description}"
# do not change
new_lease_duration="${new_lease_duration}"
EOF
}

# Write sample soap file to ${HOME}/fbtr64toolbox.samplesoap or
# to file given on command line with full path
writesoapfile () {

type="https"
descfile="tr64desc.xml"
controlURL="deviceconfig"
serviceType="DeviceConfig:1"
action="X_AVM-DE_GetConfigFile"
data="
       <NewX_AVM-DE_Password>abcdef</NewX_AVM-DE_Password>
     "
search=""
# Read settings from ${HOME}/fbtr64toolbox.samplesoap
if [ -n "${soapfile}" ] && [ -f "${soapfile}" ]
then
    . "${soapfile}"
    found=false
    soapfiletemp=$(mktemp)
    # Special construct to avoid loosing last line if there is no newline on it
    while read soapfileline || [ -n "${soapfileline}" ]
    do
        if [ "${soapfileline}" = "# [GENERAL_CONFIGURATION]" ]
        then
            found=true
            continue
        fi
        if [ "${found}" = "true" ]
        then
            echo "${soapfileline}" >> "${soapfiletemp}"
        fi
    done < "${soapfile}"
fi

echo "Writing sample soap file ${soapfile}"
cat > "${soapfile}" << EOF
# This files describes a SOAP request which can be used by the
# "fbtr64toolbox.sh mysoaprequest <soapfile>" command.
#
# More infos on
# https://avm.de/service/schnittstellen
# http://www.fhemwiki.de/wiki/FRITZBOX
#
# Never change the names of the variables!
#
# Look at "https://avm.de/service/schnittstellen" for documents
# on the TR-064 interface.
#
#
# Type of SOAP-Request: http or https
# Https SOAP Request are allways user authenticated.
# Most functions needs https requests.
# All http soap request are available through https also while
# https soap request needs https type allways.
# On commandline use --SOAPtype <https|http>
#
type="${type}"
#
#
# Name of description file normally one of:
#  ${mainxmlfiles}
# On commandline use --SOAPdescfile <xmlfilename>
#
descfile="${descfile}"
#
#
# Download desired descfile from above from your fritzbox.
#
# curl http://<fritzbox-ip>:49000/tr64desc.xml
#
# or use
#
# fbtr64toolbox.sh showxmlfile tr64desc.xml
#
# Search in this file for the service you want to use, f. e.
#
# <service>
# <serviceType>urn:dslforum-org:service:DeviceConfig:1</serviceType>
# <serviceId>urn:DeviceConfig-com:serviceId:DeviceConfig1</serviceId>
# <controlURL>/upnp/control/deviceconfig</controlURL>
# <eventSubURL>/upnp/control/deviceconfig</eventSubURL>
# <SCPDURL>/deviceconfigSCPD.xml</SCPDURL>
# </service>
#
# Put here last part of the path (most right) or full path from the
# <controlURL>-line without xml tags.
# On commandline use --SOAPcontrolURL <URL>
#
controlURL="${controlURL}"
#
#
# Put here last part (most right, must include ":<number>") or
# complete content from the <serviceType>-line without xml tags.
# On commandline use --SOAPserviceType <service type>
#
serviceType="${serviceType}"
#
#
# Download the file from the <SCPDURL>-line from your fritzbox f. e.
#
# curl http://<fritzbox-ip>:49000/deviceconfigSCPD.xml
#
# or use
#
# fbtr64toolbox.sh showxmlfile deviceconfigSCPD.xml
#
# Search in this file for the action you want to use, f. e.
#
# <action>
# <name>X_AVM-DE_GetConfigFile</name>
# <argumentList>
# <argument>
# <name>NewX_AVM-DE_Password</name>
# <direction>in</direction>
# <relatedStateVariable>X_AVM-DE_Password</relatedStateVariable>
# </argument>
# <argument>
# <name>NewX_AVM-DE_ConfigFileUrl</name>
# <direction>out</direction>
# <relatedStateVariable>X_AVM-DE_ConfigFileUrl</relatedStateVariable>
# </argument>
# </argumentList>
# </action>
#
# Put here the name of the action (function) without xml tags.
# On commandline use --SOAPaction <function name>
#
action="${action}"
#
#
# Put here one line for every argument which has direction "in" without xml tags
#
# data="
#       <in_argument_name_1>value_1</in_argument_name_1>
#       <in_argument_name_2>value_2</in_argument_name_2>
#       ...
#       <in_argument_name_n>value_2</in_argument_name_2>
#      "
#
# or if there are no "in" arguments.
#
# data=""
#
# Take the <name>- and not the <relatedStateVariable>-line for every argument.
# Arguments mostly but not allways are "New" prefixed.
# On commandline use --SOAPdata "<function data>" (space separated enclosed in parenthesis).
#
data="${data}"
#
#
# Put here one line for every argument having direction "out" without xml tags
#
# search="
#         <out_argument_name_1>
#         <out_argument_name_2>
#         ...
#         <out_argument_name_n>
#        "
#
# which you want to see as filtered output. Take those arguments you want to see in
# output f. e.
#
# search="NewX_AVM-DE_ConfigFileUrl"
#
# or if you want to see all arguments in filtered output.
#
# search="all"
#
# If you want to see complete unfiltered raw output set
#
# search=""
#
# Filtered output format: out_argument_name_X|value
#
# Filtered output for a multiline out argument displays the first line only.
#
# Take the <name>- and not the <relatedStateVariable>-line for every choosen argument.
# Arguments mostly but not allways are "New" prefixed.
# On commandline use --SOAPsearch "<search text>|all" (space separated enclosed in parenthesis).
#
search="${search}"
#
#
# Put here any text you want to see as header line in output. If not empty
# a standard device string like "(FRITZ!Box 7490 113.06.83@192.168.178.1)"
# will be added automatically.
#
# title=""
# title="my text"
#
title=""
#
#
# You can put in all parameter="value" lines from the config file here,
# overriding the settings from the config file \${HOME}/$(basename "${configfile}") f. e.
#
# FBIP="192.168.178.1"
#
# Put your settings below the "# [GENERAL_CONFIGURATION]" line.
# Never delete or modify the  "# [GENERAL_CONFIGURATION]" line. If you do so you will loose
# these additional setting lines when updating a soap file with the writesoapfile command.
#
# [GENERAL_CONFIGURATION]
EOF

if [ -n "${soapfiletemp}" ] && [ -f "${soapfiletemp}" ]
then
    cat "${soapfiletemp}" >> "${soapfile}"
    rm -f "${soapfiletemp}"
fi
}

# Output debugfbfile
output_debugfbfile () {
    if [ -f "${debugfbfile}" ]
    then
        echo
        mecho --info "Debug output of communication with fritzbox"
        cat "${debugfbfile}"
        rm -f "${debugfbfile}"
    fi
    if [ -f "${verbosefile}" ]
    then
        echo
        mecho --info "Return codes of TR-064 function calls"
        cat "${verbosefile}"
        rm -f "${verbosefile}"
    fi
    if [ "${verbose:-false}" = "true" ] || [ "${debugfb:-false}" = "true" ]
    then
        echo "------------------------------------------------------------------"
        echo "Device        : ${debugdevice}"
        echo "Command line  : ${commandline}"
        echo "Auth method   : ${detauthmethod}"
        echo "Script version: ${version}"
        echo "Errorlevel    : ${exit_code}"
        eval error='$'error_"${exit_code}"
        echo "Errorcode     : ${error}"
        echo "------------------------------------------------------------------"
    fi
    if [ "${exit_code}" = "1" ]
    then
        case ${verbose},${debugfb} in
            false,false)
                mecho --warn "Use --verbose or --debugfb or both options to retrieve more informations."
            ;;
            true,false)
                mecho --warn "Use --debugfb option to retrieve more informations."
            ;;
            false,true)
                mecho --warn "Use --verbose option to retrieve return codes of TR-064 function calls."
            ;;
        esac
    fi
}

# Remove debugfbfile
remove_debugfbfile () {
    if [ -f "${debugfbfile}" ]
    then
        rm -f "${debugfbfile}"
    fi
    if [ -f "${verbosefile}" ]
    then
        rm -f "${verbosefile}"
    fi
    if [ -f "${soapauthfile}" ]
    then
        rm -f "${soapauthfile}"
    fi
}

# Convert boolean values to yes/no
convert_yes_no () {
    case "${1}" in
        0)
            echo "no"
        ;;
        1)
            echo "yes"
        ;;
        *)
            echo "?"
        ;;
    esac
}

# Convert boolean values to active_inactive
convert_active_inactive () {
    case "${1}" in
        0)
            echo "inactive"
        ;;
        1)
            echo "active"
        ;;
        *)
            echo "?"
        ;;
    esac
}

# Convert html entities
convert_html_entities () {
    echo "$(echo "${1}" | sed -e 's#\&lt;#<#g' -e 's#\&gt;#>#g' -e 's#\&amp;#\&#g' -e 's#\&quot;#"#g' -e "s#\&apos;#'#g")"
}

# Convert seconds to human readable time output
convert_seconds_to_time_string () {
    local seconds="${1}"
    echo "$((seconds / 3600 / 24)) day(s) $((seconds / 3600 % 24)) hour(s) $((seconds % 3600 / 60)) minute(s) $((seconds % 60)) second(s)"
}

# Determine mac from ip
determine_mac_from_ip () {
    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
    mac=$(execute_soap_request \
        "X_AVM-DE_GetSpecificHostEntryByIP" \
        "<NewIPAddress>${ip}</NewIPAddress>" \
        "${type}" | grep "NewMACAddress")
    exit_code=$?
    if [ "${exit_code}" != "0" ]
    then
        mecho --error "Host with IP ${ip} not found!"
        unset mac
    else
        mac=$(parse_xml_response "${mac}" "NewMACAddress")
    fi
}

# Determine ip or mac from name
determine_ip_or_mac_from_name () {
    local name=${1}
    local search=${2}
    local result
    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
    result=$(execute_soap_request \
        "X_AVM-DE_GetHostListPath" \
        "" \
        "${type}" | grep "NewX_AVM-DE_HostListPath")
    exit_code=$?
    if [ "${exit_code}" != "0" ]
    then
        echo "Unable to get host list!"
    else
        result=$(parse_xml_response "${result}" "NewX_AVM-DE_HostListPath")
        if (echo ${result} | grep "^http")
        then
            result=$(wget -q --no-check-certificate -O - "${result}")
        else
            result=$(wget -q --no-check-certificate -O - "https://${FBIP}:${FBPORTSSL}${result}")
        fi
        result=$(parse_list_response "${result}" "List/Item[HostName='${name}']" "${search}")
        if [ -z "${result}" ]
        then
            echo "Host with name ${name} not found!"
        fi
        echo "${result}"
    fi
}

# Multiline output
# $1            : Comment on first line
# $2            : Comment on additional lines
# $3 and higher : Output text enclosed in "" if there are special chars contained
multilineoutput () {
    refresh_screensize --tty
    comment="${1}"
    shift
    secondcomment="${1}"
    shift
    if [ "${secondcomment}" = "" ]
    then
        secondcomment="$(echo ${comment} | sed 's/./ /g')"
    fi
    maxlength=$((_EISLIB_SCREENSIZE_X - ${#comment} - 1))
    for word in ${*}
    do
        if [ -z "${output}" ]
        then
            output="${word}"
        else
            length=$((${#output} + ${#word} + 1))
            if [ ${length} -le ${maxlength} ]
            then
                output="${output} ${word}"
            else
                echo "${comment} ${output}"
                comment="${secondcomment}"
                output="${word}"
            fi
        fi
    done
    if [ -n "${output}" ]
    then
        echo "${comment} ${output}"
    fi
    output=""
}

# Get url and urn from the fritzbox description files for the desired command
get_url_and_urn () {
    local response
    soapdescfile="${1}"
    name_controlURL="${2}"
    name_serviceType="${3}"
    if [ "${debugfb:-false}" = "true" ]
    then
        local duration=$(date +%s.%N)
    fi
    case "${soapdescfile}" in
        tr64desc.xml)
            if [ -z "${tr64descxml}" ]
            then
                tr64descxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${tr64descxml}"
        ;;
        igddesc.xml)
            if [ -z "${igddescxml}" ]
            then
                igddescxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${igddescxml}"
        ;;
        fboxdesc.xml)
            if [ -z "${fboxdescxml}" ]
            then
                fboxdescxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${fboxdescxml}"
        ;;
        usbdesc.xml)
            if [ -z "${usbdescxml}" ]
            then
                usbdescxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${usbdescxml}"
        ;;
        avmnexusdesc.xml)
            if [ -z "${avmnexusdescxml}" ]
            then
                avmnexusdescxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${avmnexusdescxml}"
        ;;
        l2tpv3.xml)
            if [ -z "${l2tpv3xml}" ]
            then
                l2tpv3xml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${l2tpv3xml}"
        ;;
        aura.xml)
            if [ -z "${auraxml}" ]
            then
                auraxml=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
            fi
            response="${auraxml}"
        ;;
        *)
            response=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${soapdescfile}" | grep -v "404 Not Found")
        ;;
    esac
    control_url=$(echo "${response}" | \
        grep -Eo "<controlURL>"'([a-zA-Z0-9/]*)'"${name_controlURL}</controlURL>" | \
        sed -e 's/^<controlURL>//' -e 's/<\/controlURL>.*$//')
    urn=$(echo "${response}" | \
        grep -Eo "<serviceType>"'([a-zA-Z:-]*)'"${name_serviceType}</serviceType>" | \
        sed  -e 's/^<serviceType>//' -e 's/<\/serviceType>.*$//')
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "Get url and urn from desc file"
            echo
            echo "duration        : $(echo $(date +%s.%N) - ${duration} | bc) seconds"
            echo
            echo "fbip            : ${FBIP}"
            echo
            echo "fbport          : ${FBPORT}"
            echo
            echo "desc file       : ${soapdescfile}"
            echo
            echo "name_controlURL : ${name_controlURL}"
            echo
            echo "name_serviceType: ${name_serviceType}"
            echo
            echo "control_url     : ${control_url}"
            echo
            echo "urn             : ${urn}"
        ) >> ${debugfbfile}
    fi
}

# Quit script immediately from soap request function subshell
# Call: kill -s TERM $TOP_PID
quitmessagefile="/tmp/fbtr64toolbox.sh.quitmessagefile"
trap "quit_from_soap_request" TERM
export TOP_PID=$$
quit_from_soap_request () {
    mecho --error "$(cat ${quitmessagefile})"
    rm -f "${quitmessagefile}"
    exit_code=1
    output_debugfbfile
    exit 1
}

# Collect tr64 function return codes
collect_tr64_return_codes () {
    local function="${1}"
    local response="${2}"
    local errorcode
    local errordesc
    if [ "${verbose:-false}" = "true" ]
    then
        filtered_serviceType=$(echo ${name_serviceType} | awk -F ":" '{print $(NF-1)":"$NF}')
        if (echo "${response}" | grep -q "${function}Response")
        then
            echo "${soapdescfile};${name_controlURL##*/};${filtered_serviceType};${function}: ok" >> ${verbosefile}
        else
            errorcode=$(echo "${response}" | sed -ne "s#[ \t]*</*errorCode>[ \t]*##gp")
            errordesc=$(echo "${response}" | sed -ne "s#[ \t]*</*errorDescription>[ \t]*##gp")
            echo "${soapdescfile};${name_controlURL##*/};${filtered_serviceType};${function}: ${errorcode} ${errordesc}" >> ${verbosefile}
        fi
    fi
}

# Rexecute soap request on unauthenticated soap response
reexecute_soap_request () {
    local function="${1}"
    local data="${2}"
    local type="${3}"
    local response
    local port
    if [ "${type}" = "https" ]
    then
        port="${FBPORTSSL}"
    else
        port="${FBPORT}"
    fi
    if [ "${debugfb:-false}" = "true" ]
    then
        local duration=$(date +%s.%N)
    fi
    auth=$(cut -d " " -f 1 ${soapauthfile} 2>/dev/null)
    nonce=$(cut -d " " -f 2 ${soapauthfile} 2>/dev/null)
    response=$(curl -s -m 15 -k \
                 --capath /var/certs/ssl \
                 "${type}://${FBIP}:${port}${control_url}" \
                 -H "Content-Type: text/xml; charset=\"utf-8\"" \
                 -H "SoapAction:${urn}#${function}" \
                 -d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
                 <s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
                 ${challenge@P}
                 <s:Body>
                 <u:${function} xmlns:u=\"${urn}\">
                 ${data}
                 </u:${function}>
                 </s:Body>
                 </s:Envelope>")
    collect_tr64_return_codes "${function}" "${response}"
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "SOAP request (reexecuted because of unauthenticated response)"
            echo
            echo "duration : $(echo $(date +%s.%N) - ${duration} | bc) seconds"
            echo
            echo "fbip     : ${FBIP}"
            echo
            echo "port     : ${port}"
            echo
            echo "type     : ${type}"
            echo
            echo "function : ${function}"
            echo
            echo "data     : ${data}"
            echo
            echo "response : ${response}"
        ) >> ${debugfbfile}
    fi
    nonce=$(parse_xml_response "${response}" "Nonce")
    if [ -n "${nonce}" ]
    then
        auth=$(echo -n "${secret}:${nonce}" | md5sum)
        auth="${auth:0:-3}"
        echo "${auth} ${nonce}" > ${soapauthfile}
    fi
    if [ -z "${response}" ]
    then
        echo "No response from fritzbox on ${type}:${port}." > ${quitmessagefile}
        kill -s TERM $TOP_PID
    else
        echo "${response}"
    fi
}

# Execute soap request
execute_soap_request () {
    local function="${1}"
    local data="${2}"
    local type="${3}"
    local response
    local port
    if [ "${type}" = "https" ]
    then
        port="${FBPORTSSL}"
    else
        port="${FBPORT}"
    fi
    if [ "${debugfb:-false}" = "true" ]
    then
        local duration=$(date +%s.%N)
    fi
    if [ -n "${secret}" ] && [ -f "${soapauthfile}" ]
    then
        auth=$(cut -d " " -f 1 ${soapauthfile} 2>/dev/null)
        nonce=$(cut -d " " -f 2 ${soapauthfile} 2>/dev/null)
    fi
    response=$(curl -s -m 15 -k --anyauth ${authmethod} \
                 --capath /var/certs/ssl \
                 "${type}://${FBIP}:${port}${control_url}" \
                 -H "Content-Type: text/xml; charset=\"utf-8\"" \
                 -H "SoapAction:${urn}#${function}" \
                 -d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
                 <s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
                 ${challenge@P}
                 <s:Body>
                 <u:${function} xmlns:u=\"${urn}\">
                 ${data}
                 </u:${function}>
                 </s:Body>
                 </s:Envelope>")
    collect_tr64_return_codes "${function}" "${response}"
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "SOAP request"
            echo
            echo "duration : $(echo $(date +%s.%N) - ${duration} | bc) seconds"
            echo
            echo "fbip     : ${FBIP}"
            echo
            echo "port     : ${port}"
            echo
            echo "type     : ${type}"
            echo
            echo "function : ${function}"
            echo
            echo "data     : ${data}"
            echo
            echo "response : ${response}"
        ) >> ${debugfbfile}
    fi
    if [ -n "${secret}" ]
    then
        nonce=$(parse_xml_response "${response}" "Nonce")
        if [ -n "${nonce}" ]
        then
            auth=$(echo -n "${secret}:${nonce}" | md5sum)
            auth="${auth:0:-3}"
            echo "${auth} ${nonce}" > ${soapauthfile}
        fi
    fi
    if [ -z "${response}" ]
    then
        echo "No response from fritzbox on ${type}:${port}." > ${quitmessagefile}
        kill -s TERM $TOP_PID
    else
        if [ -n "${secret}" ] && (echo "${response}" | grep -q "<Status>Unauthenticated</Status>") && \
           [ "${challenge}" = "${FBAUTH}" ]
        then
            echo $(reexecute_soap_request "${function}" "${data}" "${type}")
        else
            echo "${response}"
        fi
    fi
}

# Parse xml response from fritzbox
parse_xml_response () {
    local response="${1}"
    local search="${2}"
    local found
    found=$(echo "${response}" | sed -ne "s#[ \t]*</*${search}>[ \t]*##gp")
    echo "${found}"
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "Parse fritzbox xml response"
            echo
            echo "response: ${response}"
            echo
            echo "search  : ${search}"
            echo
            echo "found   : ${found}"
        ) >> ${debugfbfile}
    fi
}

# Parse list response from fritzbox
parse_list_response () {
    local response="${1}"
    local element="${2}"
    local search="${3}"
    local found
    found=$(echo "${response}" | xmlstarlet sel -t -m "${element}" -v "${search}")
    echo "${found}"
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "Parse fritzbox list response with xmlstarlet"
            echo
            echo "response: ${response}"
            echo
            echo "element : ${element}"
            echo
            echo "search  : ${search}"
            echo
            echo "found   : ${found}"
        ) >> ${debugfbfile}
    fi
}

# Parse singular element from list response from fritzbox
parse_singular_element_list_response () {
    local response="${1}"
    local search="${2}"
    local found
    found=$(echo "${response}" | xmlstarlet sel -t -v "${search}")
    echo "${found}"
    if [ "${debugfb:-false}" = "true" ]
    then
        (
            echo "------------------------------------------------------------------"
            echo "Parse singular element from fritzbox list response with xmlstarlet"
            echo
            echo "response: ${response}"
            echo
            echo "search  : ${search}"
            echo
            echo "found   : ${found}"
        ) >> ${debugfbfile}
    fi
}

# Default types of all wlan aps
defaultwlantypes () {
    # determine count of wlans
    wlancount=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/tr64desc.xml" | grep -Eo "WLANConfiguration:"'[[:digit:]]{1}'"</serviceType>" | wc -l)
    wlan1text="2,4 GHz WLAN-AP (presumed)"
    if [ "${wlancount}" -eq 2 ]
    then
        wlan2text="Guest WLAN-AP (presumed)"
    else
        wlan2text="5 GHz WLAN-AP (presumed)"
        if [ "${wlancount}" -eq 3 ]
        then
            wlan3text="Guest WLAN-AP (presumed)"
        else
            wlan3text="6 GHz WLAN-AP (presumed)"
        fi
    fi
    wlan4text="Guest WLAN-AP (presumed)"
}

# Detect type of single wlan ap
detectwlantype () {
    get_url_and_urn "tr64desc.xml" "wlanconfig${1}" "WLANConfiguration:${1}"
    wlantype=$(execute_soap_request \
        "X_AVM-DE_GetWLANExtInfo" \
        "" \
        "${type}")
    wlantype=$(parse_xml_response "${wlantype}" "NewX_AVM-DE_APType")
    wlanchannels=$(execute_soap_request \
        "GetChannelInfo" \
        "" \
        "${type}")
    wlanchannels=$(parse_xml_response "${wlanchannels}" "NewPossibleChannels")
    wlanfrequencyband=$(parse_xml_response "${wlanchannels}" "NewX_AVM-DE_FrequencyBand")
    case "${wlanchannels}" in
        1,*)
            wlanband="2,4\ GHz"
        ;;
        32,*|36,*)
            wlanband="5\ GHz"
        ;;
        *)
            if [ "${wlanfrequencyband}" = "6000" ]
            then
                wlanband="6\ GHz"
            else
                wlanband="\(unknown\ GHz\)"
            fi
        ;;
    esac
    case "${wlantype}" in
        guest)
            eval 'wlan'${1}'text'="${wlanband}\ Guest\ WLAN"
        ;;
        normal)
            eval 'wlan'${1}'text'="${wlanband}\ WLAN"
        ;;
        *)
            eval 'wlan'${1}'text'="Unknown\ type\ of\ WLAN"
        ;;
    esac
}

# Print out xml documents from fritzbox
showxmlfile () {
    local descfile="${1}"
    xmlfile=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${descfile}")
    if [ -n "${xmlfile}" ]
    then
        if ! (echo "${xmlfile}" | grep -q "404 Not Found")
        then
            # Correction for malformed fritzbox xml files
            xmlfile=$(echo "${xmlfile}" | sed "s/\(>\)\(<[^/]\)/\1\n\2/g" | sed "s/\(<[/].*>\)\(<[/]\)/\1\n\2/g")
            if [ -z "${soapfilter}" ]
            then
                mecho --info "Content of ${descfile} ${device}"
                echo "${xmlfile}"
            else
                mecho --info "Filtered Content of ${descfile} ${device}"
                if (echo "${mainxmlfiles}" | grep -q " ${descfile} ")
                then
                    echo "${xmlfile}" | \
                        grep -E "^<(serviceType>|controlURL>|SCPDURL>|/service>$)" | \
                        sed 's#</service>#--------------------#g'
                else
                    action_found=false
                    argument_found=false
                    action=""
                    argument=""
                    direction=""
                    related=""
                    type=""
                    echo "${xmlfile}" |
                    while read xmlline
                    do
                        xmltag=$(echo "${xmlline}" | cut -d ">" -f 1 | sed -e "s#^[ \t]*<##g")
                        xmlvalue=$(echo "${xmlline}" | sed -e "s#[ \t]*</*${xmltag}>[ \t]*##g")
                        case "${xmltag}" in
                            action)
                                action_found=true
                                argument_found=false
                                action=""
                                argument=""
                                direction=""
                                related=""
                                type=""
                            ;;
                            /action)
                                action_found=false
                                argument_found=false
                                action=""
                                argument=""
                                direction=""
                                related=""
                                type=""
                            ;;
                            name)
                                if [ "${action_found}" = "true" ]
                                then
                                    if [ "${argument_found}" = "false" ]
                                    then
                                        action="${xmlvalue}"
                                        echo "action: ${xmlvalue}"
                                    else
                                        argument="${xmlvalue}"
                                    fi
                                fi
                            ;;
                            argument)
                                if [ "${action_found}" = "true" ]
                                then
                                    argument_found=true
                                    argument=""
                                    direction=""
                                    related=""
                                    type=""
                                fi
                            ;;
                            direction)
                                if [ "${argument_found}" = "true" ]
                                then
                                    if [ "${xmlvalue}" = "in" ]
                                    then
                                        direction=" in:"
                                    else
                                        if [ "${xmlvalue}" = "out" ]
                                        then
                                            direction="out:"
                                        else
                                            direction="${xmlvalue} (!):"
                                        fi
                                    fi
                                fi
                            ;;
                            relatedStateVariable)
                                if [ "${argument_found}" = "true" ]
                                then
                                    related="${xmlvalue}"
                                fi
                            ;;
                            /argument)
                                if [ "${action_found}" = "true" ] && [ "${argument_found}" = "true" ] && \
                                   [ -n "${action}" ]
                                then
                                    # grep -A 2 because sometimes there is defaultValue line between name and dataType
                                    type=$(echo "${xmlfile}" | grep -A 2 -P "^[ \t]*<name>${related}[ \t]*</name>" | \
                                        sed -ne "s#[ \t]*</*dataType>[ \t]*##gp")
                                    if [ -z "${type}" ]
                                    then
                                        type="?"
                                    fi
                                    if [ -z "${direction}" ]
                                    then
                                        direction="  ?:"
                                    fi
                                    if [ -z "${argument}" ]
                                    then
                                        argument="?"
                                    fi
                                    echo "   ${direction} ${argument} ${type}"
                                fi
                                argument_found=false
                                argument=""
                                direction=""
                                related=""
                                type=""
                            ;;
                            /actionList)
                                break
                            ;;
                        esac
                    done
                fi
            fi
        else
            error_14="${descfile} ${error_14}"
            exit_code=14
        fi
    else
        exit_code=1
    fi
}

# Create sample soap files of all functions described in xml documents on fritzbox
writesoapfilefooter () {
    ( if [ "${soapdatafound}" = false ]
      then
          echo "\""
      else
          echo
          echo "     \""
          echo "#"
          echo "# Use --SOAPparameterlist <parameter><separator>..<parameter><separator>"
          echo "# for automatic on the fly replacement of the placeholders \${P<x>}"
          echo "# and removement of the <type>typevalue</type> part in the"
          echo "# data string by the script when executing this TR-064 function, f. e.:"
          echo "# fbtr64toolbox.sh mysoaprequest <SOAP file name> --SOAPparameterlist \"1,2,3,4,\""
          echo "# Omit empty parameters but never seperators, f. e.:"
          echo "# fbtr64toolbox.sh mysoaprequest <SOAP file name> --SOAPparameterlist \",2,,4,5,,7\""
          echo "# Allowed separators: One of .:,;-_%/=+~#"
          echo "# Separator can not be used as part of parameters at the same time."
          echo "# Separator has to be last character of parameter list."
          echo "# Enclose the complete parameter list in double quotes (\")."
          echo "# Other ways to set up needed data values for this TR-064 function:"
          echo "#     --SOAPdata <argument>value</argument>..<argument>value</argument> option"
          echo "#   or"
          echo "#     editing the data part in this file by replacing"
          echo "#     \"\\\${P<x>}<type>typevalue<type>\" manually with a valid value."
      fi ) >> "${soapfile}"
    if [ -n "${soapoutput}" ]
    then
        ( echo
          echo "# Result(s) on successful function call is/are presented by"
          echo "# device in format \"<variable>value</variable>\" while"
          echo "# data type of value is given in the following line(s):"
          echo "#"
          echo -e "${soapoutput}"
          echo "#"
          echo "# Use the search line or --SOAPsearch \"<search text>|all\""
          echo "# to get filtered output like: Variable|Value."
          echo "#"
          echo "search=\"\"" ) >> "${soapfile}"
        unset soapoutput
    fi
    unset soapfile
    soapdatafound=false
}

createsoapfiles () {
    unset soapfile
    soapdatafound=false
    soaptmpfile=$(mktemp)
    rm -f "${soapfilestargetdir}"/*
    for descfile in ${mainxmlfiles}
    do
        soapfilter=1
        echo -n "Downloading ${descfile} "
        showxmlfile "${descfile}" > ${soaptmpfile}
        mainfile=$(cat ${soaptmpfile})
        if [ -n "${mainfile}" ]
        then
            mecho --info "ok"
        else
            mecho --warn "not found"
            if [ -n "${xmlfilenotfound}" ]
            then
                xmlfilenotfound="${xmlfilenotfound}, ${descfile}"
            else
                xmlfilenotfound="${descfile}"
            fi
        fi
        header="# Device : "$(echo "${mainfile}" | head -1 | grep -Eo "\(.*\)" | sed -e 's/(//' -e 's/)//')
        rm -f ${soaptmpfile}
        while read main
        do
            if echo "${main}" | grep -q "<serviceType>"
            then
                serviceType=$(echo "${main}" | sed -e 's/.*<serviceType>//' -e 's/<\/serviceType>.*//')
            else
                if echo "${main}" | grep -q "<controlURL>"
                then
                    controlURL=$(echo "${main}" | sed -e 's/.*<controlURL>//' -e 's/<\/controlURL>.*//')
                else
                    if echo "${main}" | grep -q "<SCPDURL>"
                    then
                        scpdfile=$(echo "${main}" | sed -e 's/.*<SCPDURL>//' -e 's/<\/SCPDURL>.*//' | cut -d "/" -f 2)
                    else
                        if echo "${main}" | grep -q "^--------"
                        then
                            echo -n "    Downloading ${scpdfile} "
                            showxmlfile "${scpdfile}" > ${soaptmpfile}
                            subfile=$(cat ${soaptmpfile} ; echo "action:end")
                            if [ -n "${subfile}" ]
                            then
                                mecho --info "ok"
                            else
                                mecho --warn "not found"
                                if [ -n "${xmlfilenotfound}" ]
                                then
                                    xmlfilenotfound="${xmlfilenotfound}, ${descfile}"
                                else
                                    xmlfilenotfound="${descfile}"
                                fi
                            fi
                            rm -f ${soaptmpfile}
                            while read sub
                            do
                                if echo ${sub} | grep -q "^action: "
                                then
                                    action=$(echo "${sub}" | sed -e 's/action: //')
                                    if [ -n "${soapfile}" ]
                                    then
                                        writesoapfilefooter
                                    fi
                                    address=$(echo "${serviceType}" | awk -F ":" '{print $NF}')
                                    soapfile="${descfile}.${scpdfile}.${action}_${address}"
                                    if [ -z "${1}" ]
                                        then echo "        Writing ${soapfile}"
                                    fi
                                    soapfile="${soapfilestargetdir}/${soapfile}"
                                    ( echo ${header}
                                      echo "# Created: "$(date +"%Y-%m-%d %H:%M")" by fbtr64toolbox.sh ${version}"
                                      echo "#"
                                      echo "# Main xml description file  : ${descfile}"
                                      echo "# Sub xml description file   : ${scpdfile}"
                                      echo "# Sub address                : ${address}"
                                      echo "# Function call              : ${action}"
                                      echo "# Official AVM documentation : https://avm.de/service/schnittstellen/"
                                      echo
                                      echo "# Title line of output"
                                      echo "title=\"\""
                                      echo "# Function data"
                                      echo "type=\"https\""
                                      echo "descfile=\"${descfile}\""
                                      echo "controlURL=\"${controlURL}\""
                                      echo "serviceType=\"${serviceType}\""
                                      echo "action=\"${action}\""
                                      echo -n "data=\"" ) > "${soapfile}"
                                      paramcount=1
                                else
                                    if echo ${sub} | grep -q "^in: "
                                    then
                                        sub=$(echo ${sub} | sed 's/in: //g') 
                                        paramarg="$(echo "${sub}" | cut -d " " -f 1)"
                                        paramtype="<type>$(echo "${sub}" | cut -d " " -f 2)</type>"
                                        data="       <${paramarg}>\\\${P${paramcount}}${paramtype}</${paramarg}>"
                                        ( echo
                                          echo -n "${data}" ) >> "${soapfile}"
                                        paramcount=$((paramcount + 1))
                                        soapdatafound=true
                                    else
                                        if echo ${sub} | grep -q "^out: "
                                        then
                                            soapout="${soapout}"$(echo ${sub} | sed -e 's/out: //' -e 's/ />/')
                                            soapout="#      <"${soapout}"</"$(echo ${soapout} | cut -d ">" -f 1)">"
                                            if [ -n "${soapoutput}" ]
                                            then
                                                soapoutput="${soapoutput}"\\n"${soapout}"
                                            else
                                                soapoutput="${soapout}"
                                            fi
                                            unset soapout
                                        else
                                            if  [ -n "${soapfile}" ] && (echo ${sub} | grep -q "^action:end")
                                            then
                                                writesoapfilefooter
                                            fi
                                        fi
                                    fi
                                fi
                            done <<< "$(echo "${subfile}")"
                        fi
                    fi
                fi
            fi
        done <<< "$(echo "${mainfile}")"
        if [ -n "${xmlfilenotfound}" ]
        then
            error_14="$(echo ${xmlfilenotfound} | sed -r 's/(.*),(.*)/\1 and\2/g') not found on fritzbox"
        fi
    done
}

# Help page
usage () {
    if [ "${1}" = "commandline" ] && [ -n "${commandline}" ]
    then
        mecho --error "Command line: ${commandline}"
    fi
    echo "Command line tool for the TR-064 interface of fritzboxes"
    echo "${copyright}"
    echo "${contact}"
    if [ "${1}" = "license" ]
    then
        echo "License:          This program is free software; you can redistribute it and/or modify"
        echo "                  it under the terms of the GNU General Public License as published by"
        echo "                  the Free Software Foundation; either version 2 of the License, or"
        echo "                  (at your option) any later version."
    else
        if [ "${1}" = "disclaimer" ]
        then
            echo "Disclaimer:       This program is distributed in the hope that it will be useful,"
            echo "                  but WITHOUT ANY WARRANTY; without even the implied warranty of"
            echo "                  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the"
            echo "                  GNU General Public License for more details."
        else
            echo "                  This program comes with ABSOLUTELY NO WARRANTY."
            echo "                  This is free software, and you are welcome to"
            echo "                  redistribute it under certain conditions."
        fi
    fi
    echo "                  (for details see <https://www.gnu.org/licenses/>)"
    if [ "${1}" = "version" ] || [ "${1}" = "license" ] || [ "${1}" = "disclaimer" ]
    then
        return 0
    fi
    echo
    echo "Usage           : $(basename ${0}) command [option [value]] .. [option [value]]"
    echo
    echo "Commands:"
    echo "add             : Adds a (predefined) port forward."
    echo "del             : Deletes a (predefined) port forward."
    echo "enable          : Activates a previous disabled (predefined) port forward."
    echo "                  If not yet present in fritzbox port forward will be added enabled."
    echo "disable         : Deactivates a (predefined) port forward if present in fritzbox."
    echo "                  If not yet present in fritzbox port forward will be added disabled."
    echo "show            : Shows all port forwardings whether set by authorized user or upnp."
    echo "extip           : Shows the external IP v4 and v6 addresses."
    echo "extipv4         : Shows the external IP v4 address."
    echo "extipv6         : Shows the external IP v6 address."
    echo "conninfo        : Informations/Status of internet connection."
    echo "connstat        : Status of internet connection."
    echo "ddnsinfo        : Informations/Status of dynamic dns service."
    echo "timeinfo        : Informations/Status of time servers and date/time."
    echo "wlancount       : Prints number and type of available wlans."
    echo "wlan?info       : Informations/Status of wlan; ? = 1, 2, 3 or 4."
    echo "wlanswitch (*)  : Activates/deactivates wlan global acting like button on fritzbox."
    echo "wlan?switch (*) : Activates/deactivates wlan; ? = 1, 2, 3 or 4."
    echo "dectinfo        : Shows dect telephone list."
    echo "deflectionsinfo : Shows telephone deflections list."
    echo "homeautoinfo    : Shows informations from home automation/smart home devices."
    echo "homeautoswitch \"<ain>\" (*)"
    echo "                : Switches home automation switch given by ain."
    echo "homepluginfo    : Shows homeplug/powerline devices list."
    echo "hostsinfo       : Shows hosts list."
    echo "hostinfo <ip>|<name>"
    echo "                : Informations about host given by ip address or name."
    echo "wanaccessinfo <ip>|<name>"
    echo "                : Shows if host given by ip address or name has WAN access."
    echo "wanaccessswitch <ip>|<name>"
    echo "                : Activates/Deactivates WAN access for host given by ip address or name."
    echo "                  WAN access depends also on the profile defined in fritzbox web ui."
    echo "autowolinfo <ip>|<mac>|<name>"
    echo "                : Shows Auto WOL configuration of host given by ip address, mac address or name."
    echo "autowolswitch <ip>|<mac>|<name>"
    echo "                : Activates/Deactivates Auto WOL configuration of host given by"
    echo "                  ip address, mac address or name."
    echo "wolclient <ip>|<mac>|<name>"
    echo "                : Wake on lan client given by ip address, mac address or name."
    echo "storageinfo     : Information/Status of ftp and smb server."
    echo "ftpswitch       : Activates/deactivates ftp server."
    echo "ftpwanswitch    : Activates/deactivates ftp wan server."
    echo "ftpwansslswitch : Activates/deactivates ssl only on ftp wan server."
    echo "smbswitch       : Activates/deactivates smb server."
    echo "nasswitch       : Activates/deactivates nas server (local ftp and smb)."
    echo "upnpmediainfo   : Information/Status of upnp media server."
    echo "upnpswitch      : Activates/deactivates upnp status messages."
    echo "mediaswitch     : Activates/deactivates media server."
    echo "taminfo         : Information/Status of answering machines."
    echo "tamcap          : Shows capacity of answering machines."
    echo "tamswitch <index> (*)"
    echo "                : Activates/Deactivates answering machine given by index 0-4"
    echo "alarminfo       : Information/Status of alarm clocks."
    echo "alarmswitch <index>"
    echo "                : Activates/Deactivates alarm clock given by index 0-2"
    echo "reconnect       : Reconnects to internet."
    echo "reboot          : Reboots the fritzbox."
    echo "savefbconfig    : Stores the fritzbox configuration to your home directory; default filename:"
    echo "                  \"fritzbox_<model>_<serialno>_<firmwareversion>_<date_time>.config\"."
    echo "                  Use (see below) --fbconffile* options to modify path and filename"
    echo "                  and set mandatory password. Command does not work on fritzboxes"
    echo "                  with enabled \"second factor authentication\"."
    echo "updateinfo      : Informations about fritzbox firmware updates."
    echo "tr69info        : Informations about provider managed updates via TR-069."
    echo "deviceinfo      : Informations about the fritzbox (model, firmware, ...)."
    echo "devicelog       : Shows fritzbox log formatted or raw."
    echo "downloadcert    : Downloads certificate from fritzbox."
    echo "certvalidity    : Shows validity data of fritzbox certificate."
    echo "listxmlfiles    : Lists all xml documents on fritzbox."
    echo "showxmlfile [<xmlfilename>]"
    echo "                : Shows xml documents on fritzbox."
    echo "createsoapfiles <fullpath>"
    echo "                : Creates soap files from xml documents on fritzbox."
    echo "mysoaprequest [<fullpath>/]<file>|<command line parameters>"
    echo "                : Makes SOAP request defined in <file> or from command line parameters."
    echo "writeconfig     : Writes sample configuration to default file \"${HOME}/.fbtr64toolbox\""
    echo "                  or to specific file defined by the \"--conffilesuffix\" option (see below)."
    echo "writesoapfile [<fullpath>/<file>]"
    echo "                : Writes sample SOAP request to specified file"
    echo "                  or to sample file \"${HOME}/fbtr64toolbox.samplesoap\"."
    echo "calcsecret      : Calculates hashed secret and stores it into the default configuration file"
    echo "                  \"${HOME}/.fbtr64toolbox\" or into specific configuration file defined by the"
    echo "                  \"--conffilesuffix\" option (see below)."
    echo
    echo "Optional or mandatory options/parameters:"
    echo "Option/Parameter                     Used by commands"
    echo "--conffilesuffix <text>              all but writesoapfile"
    echo "          Use of configuration file \"${HOME}/.fbtr64toolbox.text\""
    echo "          instead of default \"${HOME}/.fbtr64toolbox\"."
    echo "--fbip <ip address>|<fqdn>           all but writeconfig and writesoapfile"
    echo "--description \"<text>\"               add, enable, disable"
    echo "--extport <port number>              add, enable, disable, del"
    echo "--intclient <ip address>             add, enable, disable"
    echo "--intport <port number>              add, enable, disable"
    echo "--protocol <TCP|UDP>                 add, enable, disable, del"
    echo "--active                             add, *switch, hostsinfo"
    echo "--inactive                           add, *switch, hostsinfo"
    echo "          Either --active or --inactive is required on all switch commands."
    echo "--searchhomeautoain \"<text>\"         homeautoinfo"
    echo "--searchhomeautodeviceid \"<text>\"    homeautoinfo"
    echo "--searchhomeautodevicename \"<text>\"  homeautoinfo"
    echo "          \"<text>\" in search parameters could be text or Reg-Exp."
    echo "--showWANstatus                      hostsinfo"
    echo "--showWOLstatus                      hostsinfo"
    echo "--showhosts \"<active|inactive>\"      hostsinfo"
    echo "          Short form: \"<--active|--inactive>\""
    echo "--ftpwansslonlyon (**)               ftpwanswitch"
    echo "--ftpwansslonlyoff (**)              ftpwanswitch"
    echo "--ftpwanon (**)                      ftpwansslswitch"
    echo "--ftpwanoff (**)                     ftpwansslswitch"
    echo "--mediaon (**)                       upnpswitch"
    echo "--mediaoff (**)                      upnpswitch"
    echo "--upnpon (**)                        mediaswitch"
    echo "--upnpoff (**)                       mediaswitch"
    echo "          (**) Previous status will be preserved if"
    echo "               *on|off parameter is not given on the command line."
    echo "--showfritzindexes                   show, deflectionsinfo,"
    echo "                                     homeautoinfo, homepluginfo, hostsinfo"
    echo "--nowrap                             deviceinfo, devicelog"
    echo "--rawdevicelog                       devicelog"
    echo "--soapfilter                         showxmlfile"
    echo "--fbconffilepath \"<abs path>\"        savefbconfig"
    echo "--fbconffileprefix \"<text>\"          savefbconfig"
    echo "--fbconffilesuffix \"<text>\"          savefbconfig"
    echo "--fbconffilepassword \"<text>\"        savefbconfig"
    echo "--certpath \"<abs path>\"              downloadcert"
    echo
    echo "Explanations for these parameters could be found in the SOAP sample file."
    echo "--SOAPtype <https|http>              all but writeconfig and writesoapfile"
    echo "--SOAPdescfile <xmlfilename>         mysoaprequest"
    echo "--SOAPcontrolURL <URL>               mysoaprequest"
    echo "--SOAPserviceType <service type>     mysoaprequest"
    echo "--SOAPaction <function name>         mysoaprequest"
    echo "--SOAPdata \"<function data>\"         mysoaprequest"
    echo "--SOAPsearch \"<search text>|all\"     mysoaprequest"
    echo "--SOAPtitle \"<text>\"                 mysoaprequest"
    echo "Useable for special prepared SOAP files as created by the createsoapfiles command."
    echo "--SOAPparameterlist \"<parameter><separator>..<parameter><separator>\""
    echo "                                     mysoaprequest"
    echo
    echo "--experimental                       Enables experimental commands (*)."
    echo
    echo "--debugfb                            Activate debug output on fritzbox communication."
    echo "--verbose                            Print out return codes of all TR-064 function calls."
    echo
    echo "version|--version                    Prints version and copyright informations."
    echo "license|--license                    Prints license informations."
    echo "disclaimer|--disclaimer              Prints disclaimer."
    echo "help|--help|-h                       Prints help page."
    echo
    echo "Necessary parameters not given on the command line are taken from default values or the"
    echo "configuration file. The configuration file is read from your home directory on script"
    echo "startup overriding default values. By default it is named \".fbtr64toolbox\" but an extension"
    echo "can be added using the \"--conffilesuffix <text>\" parameter (see above)."
    if [ "${1}" = "fullhelp" ]
    then
        echo
        echo "If modifying an existing port forwarding entry with the add, enable or disable commands"
        echo "the values for extport, intclient and protocol has to be entered in exact the same"
        echo "way as they are stored in the port forwarding entry on the fritzbox! Differing values"
        echo "for intport, description and active/inactive status could be used and will change"
        echo "these values in the port forwarding entry on the fritzbox."
        echo
        echo "If deleting an port forwarding entry on the fritzbox the values for extport and protocol"
        echo "has to be entered in exact the same way as they are stored in the port forwarding entry"
        echo "on the fritzbox."
        echo
        echo "The script can use the fritzbox authentication data from \"${netrcfile}\""
        echo "which has to be readable/writable by the owner only (chmod 0600 ${netrcfile})."
        echo "Put into this file a line like:"
        echo "machine <address of fritzbox> login <username> password <password>"
        echo "f. e.: machine ${FBIP} login ${user} password ${password}"
        echo "The fritzbox address has to be given in the same type (ip or fqdn) in"
        echo "the configuration file or on command line parameter \"--fbip\" and \"${netrcfile}.\""
        echo "Saviest solution for authentication is the use of \"user\" and hashed \"secret\"."
        echo "Write down \"user\" and \"password\" into the configuration file an run"
        echo "\"fbtrtoolbox calcsecret\" which will calculate the \"secret\", stores it in the"
        echo "configuration file and removes the password from it."
        echo
        echo "Warning:"
        echo "If adding or deleting port forwardings in the webgui of your fritzbox please"
        echo "reboot it afterwards. Otherwise the script will see an incorrect port forwarding count"
        echo "through the TR-064 interface ending up in corrupted port forwarding entries."
    fi
}

commandline="${*}"
experimental="false"
debugfb="false"
verbose="false"
showfritzindexes="false"
showWANstatus="false"
showWOLstatus="false"
showhosts="all"
certpath=${fbconffilepath}
realm='F!Box SOAP-Auth'
soapauthfile="/tmp/fbtr64toolbox.soapauthfile"
FBINIT="<s:Header><h:InitChallenge xmlns:h=\"http://soap-authentication.org/digest/2001/10/\" s:mustUnderstand=\"1\"><UserID>\${user}</UserID></h:InitChallenge></s:Header>"
FBAUTH="<s:Header><h:ClientAuth xmlns:h=\"http://soap-authentication.org/digest/2001/10/\" s:mustUnderstand=\"1\"><Nonce>\${nonce}</Nonce><Auth>\${auth}</Auth><UserID>\${user}</UserID><Realm>${realm}</Realm></h:ClientAuth></s:Header>"

# Exit with errorlevel
# $1 : Errorlevel
# $2 : If given show help page
exit_with_error () {
    if [ -n "${2}" ]
    then
        usage commandline
    fi
    remove_debugfbfile
    exit_code="${1}"
    exit "${1}"
}

checksettings
readconfig "${1}"
checksettings ${configfile}
if [ -n "${secret}" ] && [ -n "${password}" ]
then
    password=""
    writeconfig >/dev/null
fi

commandlist="^(\
add|del|(en|dis)able|show|\
extip(v[46])?|connstat|wlancount|\
(alarm|autowol|conn|ddns|dect|deflections|device|homeauto|homeplug|hosts|host|storage|tam|time|tr69|update|upnpmedia|wanaccess|wlan[1234])info|\
(alarm|autowol|ftp|ftpwan|ftpwanssl|homeauto|media|nas|smb|tam|upnp|wanaccess|wlan[1234]?)switch|\
wolclient|tamcap|reconnect|reboot|savefbconfig|devicelog|downloadcert|certvalidity|\
listxmlfiles|showxmlfile|createsoapfiles|mysoaprequest|write(config|soapfile)|calcsecret|\
([-]{2})?version|\
([-]{2})?license|\
([-]{2})?disclaimer|\
([-]{2})?help|[-]h\
)$"

experimentallist="^(homeauto|tam|wlan[1234]?)switch$"

switchlist="^(alarm|autowol|ftp|ftpwan|ftpwanssl|homeauto|media|nas|smb|tam|upnp|wanaccess|wlan[1234]?)switch$"

needsfbconntypelist="^(add|enable|disable|del|show|extip|extipv4|conninfo|connstat|reconnect|deviceinfo)"

# Parse commands
if [ -z "${1}" ] || ! (echo "${1}" | grep -Eq "${commandlist}")
then
    if [ -n "${1}" ]
    then
        mecho --error "Wrong command \"${1}\" given!"
    else
        mecho --error "No command given!"
    fi
    exit_with_error 4 showhelp
else
    command="${1}"
    shift
    if [ "${command}" = "help" ] || [ "${command}" = "--help" ] || [ "${command}" = "-h" ] ||
       [ "${command}" = "version" ] || [ "${command}" = "--version" ] ||
       [ "${command}" = "license" ] || [ "${command}" = "--license" ] ||
       [ "${command}" = "disclaimer" ] || [ "${command}" = "--disclaimer" ]
    then
        if [ "${command}" = "help" ] || [ "${command}" = "--help" ] || [ "${command}" = "-h" ]
        then
            usage fullhelp
        else
            usage $(echo ${command} | sed 's/-//g')
        fi
        exit
    else
        if [ "${command}" = "writeconfig" ] || [ "${command}" = "writesoapfile" ] || [ "${command}" = "calcsecret" ]
        then
            if [ "${command}" = "writesoapfile" ]
            then
                if [ -n "${1}" ]
                then
                    soapfile="${1}"
                    if [ "${soapfile:0:1}" != "/" ]
                    then
                        mecho --error "File ${soapfile} has to be given with full path!"
                        exit_with_error 6 showhelp
                    fi
                fi
            fi
            if [ -n "${configfile}" ] && [ -n "${soapfile}" ]
            then
                if [ "${command}" = "calcsecret" ]
                then
                    if [ -n "${password}" ]
                    then
                        secret=$(echo -n "${user}:${realm}:${password}" | md5sum)
                        secret="${secret:0:-3}"
                        password=""
                        writeconfig
                    else
                        mecho --error "Unable to calculate \"secret\" because no password found in ${configfile}!"
                        exit_with_error 18
                    fi
                    exit
                else
                    ${command}
                    exit
                fi
            else
                if [ "${command}" = "writesoapfile" ]
                then
                    mecho --error "Command \"${command}\" aborted because \${HOME} is not set and target file not given!"
                else
                    mecho --error "Command \"${command}\" aborted because \${HOME} is not set!"
                fi
                exit_with_error 13
            fi
        else
            if (echo "${command}" | grep -Eq "${switchlist}")
            then
                if ! (echo "${*}" | grep -q "\--active" || echo "${*}" | grep -q "\--inactive")
                then
                    mecho --error "Necessary option \"--active\" or \"--inactive\" for command \"${command}\" not given!"
                    exit_with_error 6 showhelp
                fi
            fi
            if [ "${command}" = "mysoaprequest" ]
            then
                if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
                then
                    if [ -f "${1}" ]
                    then
                        mysoaprequestfile="${1}"
                        if [ "${mysoaprequestfile:0:1}" != "/" ]
                        then
                            . "./${mysoaprequestfile}"
                        else
                            . "${mysoaprequestfile}"
                        fi
                        checksettings "${mysoaprequestfile}"
                        shift
                    else
                        mecho --error "File ${1} not found for command \"${command}\"!"
                        exit_with_error 12 showhelp
                    fi
                fi
            else
                if [ "${command}" = "autowolswitch" ] || [ "${command}" = "autowolinfo" ] || [ "${command}" = "wolclient" ]
                then
                    if [ -n "${1}" ] && (echo "${1}" | grep -Eq "^[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$")
                    then
                        mac="${1}"
                        shift
                    else
                        if [ -n "${1}" ] && (echo "${1}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$")
                        then
                            ip="${1}"
                            shift
                        else
                            if [ -n "${1}" ]  && [ "${1:0:2}" != "--" ] && (echo "${1}" | grep -Eq "^[.a-zA-Z0-9-]+$")
                            then
                                name="${1}"
                                shift
                            else
                                mecho --error "Wrong or no value for ip address, mac address or name given!"
                                exit_with_error 6 showhelp
                            fi
                        fi
                    fi
                else
                    if [ "${command}" = "homeautoswitch" ]
                    then
                        if [ -n "${1}" ] && [ "${1:0:2}" != "--" ] && (echo "${1}" | grep -Eq "^(grp|tmp)?[ :0-9a-fA-F-]+$")
                        then
                            ain="${1}"
                            shift
                        else
                            mecho --error "Wrong or no value for ain given!"
                            exit_with_error 6 showhelp
                        fi
                    else
                        if [ "${command}" = "tamswitch" ]
                        then
                            if [ -n "${1}" ] && (echo "${1}" | grep -Eq "^[0-4]{1}$")
                            then
                                tamindex="${1}"
                                shift
                            else
                                mecho --error "Wrong or no value for index given!"
                                exit_with_error 6 showhelp
                            fi
                        else
                            if [ "${command}" = "showxmlfile" ]
                            then
                                if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
                                then
                                    descfile="${1}"
                                    shift
                                else
                                    descfile="tr64desc.xml"
                                fi
                            else
                                if [ "${command}" = "createsoapfiles" ]
                                then
                                    if [ -n "${1}" ] && [ "${1:0:1}" = "/" ] && [ "${1}" != "/" ] && [ -d "${1}" ]
                                    then
                                        soapfilestargetdir="${1}"
                                        shift
                                    else
                                        mecho --error "Full path (not equal to /) to target directory has to be given and must exists!"
                                        exit_with_error 6 showhelp
                                    fi
                                else
                                    if [ "${command}" = "wanaccessinfo" ] || [ "${command}" = "wanaccessswitch" ] || [ "${command}" = "hostinfo" ]
                                    then
                                        if [ -n "${1}" ] && (echo "${1}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$")
                                        then
                                            ip="${1}"
                                            shift
                                        else
                                            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ] && (echo "${1}" | grep -Eq "^[.a-zA-Z0-9-]+$")
                                            then
                                                name="${1}"
                                                shift
                                            else
                                                mecho --error "Wrong or no value for ip address or name given!"
                                                exit_with_error 6 showhelp
                                            fi
                                        fi
                                    else
                                        if [ "${command}" = "alarmswitch" ]
                                        then
                                            if [ -n "${1}" ] && (echo "${1}" | grep -Eq "^[0-2]{1}$")
                                            then
                                                alarmindex="${1}"
                                                shift
                                            else
                                                mecho --error "Wrong or no value for index given!"
                                                exit_with_error 6 showhelp
                                            fi
                                        else
                                            if [ "${command}" = "downloadcert" ] || [ "${command}" = "certvalidity" ]
                                            then
                                                if ! which openssl >/dev/null 2>/dev/null
                                                then
                                                    mecho --error "openssl not found!"
                                                    exit_with_error 3
                                                else
                                                    if [ -n "$(openssl version | sed 's/^openssl \([0-9.]*\).*$/\1/i' | grep "^0.")" ]
                                                    then
                                                        mecho --error "openssl too old!"
                                                        exit_with_error 3
                                                    fi
                                                fi
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

# Parse optional parameters
while [ -n "${1}" ]
do
    case "${1}" in
        --conffilesuffix)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                shift
            fi
        ;;
        --fbip)
            shift
            if (echo "${1}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$") ||
               (echo "${1}" | grep -Eq "^[[:alnum:]]([-]*[[:alnum:]])*(\.[[:alnum:]]([-]*[[:alnum:]])*)*$")
            then
                FBIP="${1}"
                shift
            else
                mecho --error "Wrong or no value for fritzbox address given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --description)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                new_port_mapping_description="${1}"
                shift
            else
                mecho --error "No description given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --extport)
            shift
            if  (echo "${1}" | grep -Eq "^[[:digit:]]{1,5}$") && [ "${1}" -ge 1 ] && [ "${1}" -le 65535 ]
            then
                new_external_port="${1}"
                shift
            else
                mecho --error "Wrong or no value for external port given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --intclient)
            shift
            if (echo "${1}" | grep -Eq "^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])){3}$")
            then
                new_internal_client="${1}"
                shift
            else
                mecho --error "Wrong or no value for internal client ip address given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --intport)
            shift
            if (echo "${1}" | grep -Eq "^[[:digit:]]{1,5}$") && [ "${1}" -ge 1 ]  && [ "${1}" -le 65535 ]
            then
                new_internal_port="${1}"
                shift
            else
                mecho --error "Wrong or no value for internal client port given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --protocol)
            shift
            new_protocol=$(echo "${1}" | tr [:lower:] [:upper:])
            shift
            if [ "${new_protocol}" != "TCP" ] && [ "${new_protocol}" != "UDP" ]
            then
                mecho --error "Wrong or no value for protocol given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --active)
            new_enabled="1"
            showhosts="yes"
            switch="On"
            shift
        ;;
        --inactive)
            new_enabled="0"
            showhosts="no"
            switch="Off"
            shift
        ;;
        --searchhomeautoain)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                searchhomeautoain="${1}"
                shift
            else
                searchhomeautoain=""
            fi
        ;;
        --searchhomeautodeviceid)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                searchhomeautodeviceid="${1}"
                shift
            else
                searchhomeautodeviceid=""
            fi
        ;;
        --searchhomeautodevicename)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                searchhomeautodevicename="${1}"
                shift
            else
                searchhomeautodevicename=""
            fi
        ;;
        --showhosts)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                showhosts="${1}"
                shift
                case "${showhosts}" in
                    active)
                        showhosts="yes"
                    ;;
                    inactive)
                        showhosts="no"
                    ;;
                    *)
                        showhosts="all"
                    ;;
                esac
            else
                showhosts="all"
            fi
        ;;
        --fbconffilepath)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ] && [ -d "${1}" ]
            then
                fbconffilepath="${1}"
                shift
            else
                mecho --error "No or unavailable path given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --fbconffileprefix)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                fbconffileprefix="${1}"
                shift
            else
                fbconffileprefix=""
            fi
        ;;
        --fbconffilesuffix)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                fbconffilesuffix="${1}"
                shift
            else
                fbconffilesuffix=""
            fi
        ;;
        --fbconffilepassword)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                fbconffilepassword="${1}"
                shift
            else
                fbconffilepassword=""
            fi
        ;;
        --certpath)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ] && [ -d "${1}" ]
            then
                certpath="${1}"
                shift
            else
                mecho --error "No or unavailable path given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --showWANstatus)
            showWANstatus="true"
            shift
        ;;
        --showWOLstatus)
            showWOLstatus="true"
            shift
        ;;
        --ftpwanon)
            ftpwanon="1"
            shift
        ;;
        --ftpwanoff)
            ftpwanon="0"
            shift
        ;;
        --ftpwansslonlyon)
            ftpwansslonlyon="1"
            shift
        ;;
        --ftpwansslonlyoff)
            ftpwansslonlyon="0"
            shift
        ;;
        --mediaon)
            mediaon="1"
            shift
        ;;
        --mediaoff)
            mediaon="0"
            shift
        ;;
        --upnpon)
            upnpon="1"
            shift
        ;;
        --upnpoff)
            upnpon="0"
            shift
        ;;
        --showfritzindexes)
            showfritzindexes="true"
            shift
        ;;
        --rawdevicelog)
            rawdevicelog="1"
            shift
        ;;
        --nowrap)
            nowrap="1"
            shift
        ;;
        --soapfilter)
            soapfilter="1"
            shift
        ;;
        --SOAPtype)
            shift
            if [ "${1}" = "http" ] || [ "${1}" = "https" ]
            then
                type="${1}"
                shift
            else
                mecho --error "Wrong or no value for SOAP type given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --SOAPdescfile)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                descfile="${1}"
                shift
            else
                mecho --error "No SOAP description file given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --SOAPcontrolURL)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                [ -z "${mysoaprequestfile}" ] && controlURL="${1}"
                shift
            else
                mecho --error "No SOAP control url given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --SOAPserviceType)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                [ -z "${mysoaprequestfile}" ] && serviceType="${1}"
                shift
            else
                mecho --error "No SOAP service type given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --SOAPaction)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                [ -z "${mysoaprequestfile}" ] && action="${1}"
                shift
            else
                mecho --error "No SOAP action given!"
                exit_with_error 6 showhelp
            fi
        ;;
        --SOAPdata)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                data="${1}"
                shift
            else
                [ -z "${mysoaprequestfile}" ] && data=""
            fi
        ;;
        --SOAPparameterlist)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                if [ -n "${mysoaprequestfile}" ]
                then
                    paramcount=1
                    paramsep="${1:${#1}-1}"
                    if (echo "${paramsep}" | egrep -q "[.:,;-_%/=+~#]")
                    then
                        param="${1}"
                        while [ -n "${param}" ]
                        do
                            eval 'P'${paramcount}=\"${param%%${paramsep}*}\"
                            param="${param#*${paramsep}}"
                            paramcount=$((paramcount + 1))
                        done
                        data=$(echo "${data@P}" | sed -r 's#<type>.*</type>##g')
                    else
                        mecho --error "Wrong separator \"${paramsep}\" used!"
                        exit_with_error 6 showhelp
                    fi
                fi
                shift
            else
                if [ -n "${mysoaprequestfile}" ]
                then
                    mecho --error "No parameter list for SOAP data given!"
                    exit_with_error 6 showhelp
                fi
            fi
        ;;
        --SOAPsearch)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                search="${1}"
                shift
            else
                search=""
            fi
        ;;
        --SOAPtitle)
            shift
            if [ -n "${1}" ] && [ "${1:0:2}" != "--" ]
            then
                title="${1}"
                shift
            else
                title=""
            fi
        ;;
        --experimental)
            experimental="true"
            shift
        ;;
        --debugfb)
            debugfb="true"
            debugfbfile="/tmp/fbtr64toolbox.sh."$(mktemp -u XXXXXXXX)
            shift
        ;;
        --verbose)
            verbose="true"
            verbosefile="/tmp/fbtr64toolbox.sh."$(mktemp -u XXXXXXXX)
            shift
        ;;
        -h|--help)
            shift
        ;;
        *)
            mecho --error "Wrong option \"${1}\" given!"
            exit_with_error 5 showhelp
        ;;
    esac
done

# Exit if experimental switch is not given on experimental commands
if [ "${experimental:-false}" = "false" ] && (echo "${command}" | grep -Eq "${experimentallist}")
then
    mecho --warn "Function \"${command}\" only available in experimental mode. Add --experimental switch to command line."
    exit_with_error 11
fi

for tool in awk bc curl grep ksh md5sum sed wget xmlstarlet
do
    toolwithfullpath=$(which ${tool} 2>/dev/null)
    if [ $? -ne 0 ] || [ ! -x ${toolwithfullpath} ]
    then
        missingtools="${missingtools} ${tool}"
    fi
done

if [ -z "${missingtools}" ]
then
    exit_code=0
    determineauthmethod

    # Check if host is reachable
    if wget -t 1 -T 3 --spider http://${FBIP}:${FBPORT}/tr64desc.xml >/dev/null 2>&1
    then
        # Host is reachable, go on...
        get_url_and_urn "tr64desc.xml" "deviceinfo" "DeviceInfo:1"
        # Read security port
        FBPORTSSL=$(execute_soap_request \
            "GetSecurityPort" \
            "" \
            "http")
        FBPORTSSL=$(parse_xml_response "${FBPORTSSL}" "NewSecurityPort")
        # FBPORTSSL=$(echo "${FBPORTSSL}" | grep "NewSecurityPort" | sed 's#^.*<NewSecurityPort>\(.*\)<.*$#\1#')
        if [ "${debugfb:-false}" = "true" ]
        then
            (
                echo "------------------------------------------------------------------"
                echo "Determine fritzbox security port"
                echo
                echo "fbportssl: ${FBPORTSSL}"
            ) >> ${debugfbfile}
        fi
        if [ "${FBPORTSSL}" = "" ]
        then
            mecho --error "Unable to get security port!"
            exit_code=1
            output_debugfbfile
            exit 1
        fi

        # Read fritzbox description
        get_url_and_urn "tr64desc.xml" "deviceinfo" "DeviceInfo:1"
        if [ -n "${secret}" ]
        then
            challenge="${FBINIT}"
            deviceinfo=$(execute_soap_request \
                "GetInfo" \
                "" \
                "${type}")
            challenge="${FBAUTH}"
        fi
        deviceinfo=$(execute_soap_request \
            "GetInfo" \
            "" \
            "${type}")
        if (echo "${deviceinfo}" | grep -q "GetInfoResponse")
        then
            device="("$(parse_xml_response "${deviceinfo}" "NewDescription")"@${FBIP})"
            firmware=$(parse_xml_response "${deviceinfo}" "NewSoftwareVersion" | awk -F "." '{print $(NF-1)$NF}')
            if [ "${verbose:-false}" = "true" ] || [ "${debugfb:-false}" = "true" ]
            then
                debugdevice="${device:1:-1}"
            fi
        else
            mecho --error "Unable to get device name!"
            exit_code=1
            output_debugfbfile
            exit 1
        fi

        # Detect wan connection type (IP or PPP) needed by commands from needsfbconntypelist
        if (echo "${command}" | grep -Eq "${needsfbconntypelist}")
        then
            # ppp or ip connection?
            # Alternativ:
            #   get_url_and_urn "tr64desc.xml" "layer3forwarding" "Layer3Forwarding:1"
            #   if (execute_soap_request "GetDefaultConnectionService" "" "${type}" | grep  -q "WANPPPConnection")
            get_url_and_urn "tr64desc.xml" "wanpppconn1" "WANPPPConnection:1"
            if (execute_soap_request "GetInfo" "" "${type}" | grep  -q "GetInfoResponse")
            then
                FBCONNTYPE="PPP"
                FBCONNTYPEdescfile="tr64desc.xml"
                FBCONNTYPEcontrolURL="wanpppconn1"
                FBCONNTYPEserviceType="WANPPPConnection:1"
            else
                FBCONNTYPE="IP"
                FBCONNTYPEdescfile="tr64desc.xml"
                FBCONNTYPEcontrolURL="wanipconnection1"
                FBCONNTYPEserviceType="WANIPConnection:1"
            fi
        fi

        case "${command}" in
            add|enable|disable)
                # Add, enable or disable port forward
                case "${command}" in
                    add)
                        mecho --info "Add port forwarding ${device}"
                    ;;
                    enable)
                        mecho --info "Enable port forwarding ${device}"
                    ;;
                    disable)
                        mecho --info "Disable port forwarding ${device}"
                    ;;
                esac
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                [ ${command} = "enable" ] && new_enabled="1"
                [ ${command} = "disable" ] && new_enabled="0"
                # clear currently unused variables
                new_remote_host=""
                new_lease_duration="0"
                execute_soap_request \
                    "AddPortMapping" \
                    "<NewRemoteHost>${new_remote_host}</NewRemoteHost>
                     <NewExternalPort>${new_external_port}</NewExternalPort>
                     <NewProtocol>${new_protocol}</NewProtocol>
                     <NewInternalPort>${new_internal_port}</NewInternalPort>
                     <NewInternalClient>${new_internal_client}</NewInternalClient>
                     <NewEnabled>${new_enabled}</NewEnabled>
                     <NewPortMappingDescription>${new_port_mapping_description}</NewPortMappingDescription>
                     <NewLeaseDuration>${new_lease_duration}</NewLeaseDuration>" \
                    "${type}" \
                    | grep -q "AddPortMappingResponse"
                    exit_code=$?
            ;;
            del)
                # Delete port forward
                mecho --info "Delete port forwarding ${device}"
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                # clear currently unused variable
                new_remote_host=""
                execute_soap_request \
                    "DeletePortMapping" \
                    "<NewRemoteHost>${new_remote_host}</NewRemoteHost>
                     <NewExternalPort>${new_external_port}</NewExternalPort>
                     <NewProtocol>${new_protocol}</NewProtocol>" \
                    "${type}" \
                    | grep -Eq "DeletePortMappingResponse|NoSuchEntryInArray"
                exit_code=$?
            ;;
            show)
                # Show port forwardings
                # Normal port forwardings set by authorized user
                mecho --info "Port forwardings ${device}"
                mecho --info "Port forwardings set by authorized users"
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                idx=0
                portmappingcount=$(execute_soap_request \
                    "GetPortMappingNumberOfEntries" \
                    "" \
                    "${type}")
                portmappingcount=$(parse_xml_response "${portmappingcount}" "NewPortMappingNumberOfEntries")
                if [ -n "${portmappingcount}" ] && [ "${portmappingcount}" -gt 0 ]
                then
                    techo --begin "4r 4 26 20 4 22"
                    techo --info --row "Idx" "Act" "Description" "Host IP:Port" "Pro" "Client IP:Port"
                    while [ "${idx}" -lt "${portmappingcount}" ]
                    do
                        if [ "${showfritzindexes:-false}" = "true" ]
                        then
                            count="${idx}"
                        else
                            count=$((idx + 1))
                        fi
                        portmappingentry=$(execute_soap_request \
                            "GetGenericPortMappingEntry" \
                            "<NewPortMappingIndex>${idx}</NewPortMappingIndex>" \
                            "${type}")
                        if (echo "${portmappingentry}" | grep -q "SpecifiedArrayIndexInvalid")
                        then
                            mecho --error "Invalid port forwarding index found!"
                            mecho --error "Please reboot your Fritzbox to fix the problem."
                            exit_code=1
                            break
                        else
                            portmappingenabled=$(parse_xml_response "${portmappingentry}" "NewEnabled")
                            portmappingdescription=$(parse_xml_response "${portmappingentry}" "NewPortMappingDescription")
                            portmappingremotehost=$(parse_xml_response "${portmappingentry}" "NewRemoteHost")
                            # maybe faulty in fritzbox; have to reverse parameters
                            if [ "${FBREVERSEPORTS}" = "true" ]
                            then
                                portmappingremoteport=$(parse_xml_response "${portmappingentry}" "NewInternalPort")
                                portmappinginternalport=$(parse_xml_response "${portmappingentry}" "NewExternalPort")
                            else
                                portmappingremoteport=$(parse_xml_response "${portmappingentry}" "NewExternalPort")
                                portmappinginternalport=$(parse_xml_response "${portmappingentry}" "NewInternalPort")
                            fi
                            portmappingprotocol=$(parse_xml_response "${portmappingentry}" "NewProtocol")
                            portmappinginternalclient=$(parse_xml_response "${portmappingentry}" "NewInternalClient")
                            portmappingleaseduration=$(parse_xml_response "${portmappingentry}" "NewLeaseDuration")
                            techo --row \
                                "${count}" \
                                "$(convert_yes_no ${portmappingenabled})" \
                                "${portmappingdescription}" \
                                "${portmappingremotehost}:${portmappingremoteport}" \
                                "${portmappingprotocol}" \
                                "${portmappinginternalclient}:${portmappinginternalport}"
                            idx=$((idx + 1))
                        fi
                    done
                    techo --end
                else
                    [ -z "${portmappingcount}" ] && exit_code=1
                fi
                # Port forwardings set by any user via upnp if allowed under "Internet|Freigaben|Portfreigaben"
                echo
                mecho --info "Port forwardings set by any user/device via upnp"
                get_url_and_urn "igddesc.xml" "WANIPConn1" "WANIPConnection:1"
                idx=0
                while [ true ]
                do
                    if [ "${showfritzindexes:-false}" = "true" ]
                    then
                        count="${idx}"
                    else
                        count=$((idx + 1))
                    fi
                    portmappingentry=$(execute_soap_request \
                        "GetGenericPortMappingEntry" \
                        "<NewPortMappingIndex>${idx}</NewPortMappingIndex>" \
                        "${type}")
                    if (echo "${portmappingentry}" | grep -q "Invalid Action")
                    then
                        mecho --warn "UPnP not activated in network settings, change in webgui or execute"
                        mecho --warn "\"$(basename ${0}) upnpmediaswitch --active\""
                        mecho --warn "if you want to see port forwardings set by any user/device."
                        exit_code=1
                        output_debugfbfile
                        exit 1
                    fi
                    # if ! (echo "${portmappingentry}" | grep -q "SpecifiedArrayIndexInvalid") &&
                    if (echo "${portmappingentry}" | grep -q "GetGenericPortMappingEntryResponse")
                    then
                        portmappingenabled=$(parse_xml_response "${portmappingentry}" "NewEnabled")
                        portmappingdescription=$(parse_xml_response "${portmappingentry}" "NewPortMappingDescription")
                        portmappingremotehost=$(parse_xml_response "${portmappingentry}" "NewRemoteHost")
                        if [ -z "${portmappingremotehost}" ]
                        then
                            portmappingremotehost="0.0.0.0"
                        fi
                        portmappingremoteport=$(parse_xml_response "${portmappingentry}" "NewExternalPort")
                        portmappingprotocol=$(parse_xml_response "${portmappingentry}" "NewProtocol")
                        portmappinginternalclient=$(parse_xml_response "${portmappingentry}" "NewInternalClient")
                        portmappinginternalport=$(parse_xml_response "${portmappingentry}" "NewInternalPort")
                        portmappingleaseduration=$(parse_xml_response "${portmappingentry}" "NewLeaseDuration")
                        if [ "${idx}" -eq 0 ]
                        then
                            techo --begin "4r 4 26 20 4 22"
                            techo --info --row "Idx" "Act" "Description" "Host IP:Port" "Pro" "Client IP:Port"
                        fi
                        techo --row \
                            "${count}" \
                            "$(convert_yes_no ${portmappingenabled})" \
                            "${portmappingdescription}" \
                            "${portmappingremotehost}:${portmappingremoteport}" \
                            "${portmappingprotocol}" \
                            "${portmappinginternalclient}:${portmappinginternalport}"
                        idx=$((idx + 1))
                    else
                        if [ "${idx}" -gt 0 ]
                        then
                            techo --end
                        fi
                        break
                    fi
                done
            ;;
            extip)
                # Print external ipv4 address
                mecho --info "External IPv4/v6 data ${device}"
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                extipv4address=$(execute_soap_request \
                    "GetExternalIPAddress" \
                    "" \
                    "${type}")
                extipv4address=$(parse_xml_response "${extipv4address}" "NewExternalIPAddress")
                if [ -n "${extipv4address}" ]
                then
                    mecho --info "External IPv4 address : ${extipv4address}"
                else
                    mecho -n --info "External IPv4 address : "
                    mecho --error "No external IPv4 address"
                    exit_code=9
                fi
                # Print external ipv6 address
                get_url_and_urn "igddesc.xml" "WANIPConn1" "WANIPConnection:1"
                extipv6address=$(execute_soap_request \
                    "X_AVM_DE_GetExternalIPv6Address" \
                    "" \
                    "${type}")
                extipv6address=$(parse_xml_response "${extipv6address}" "NewExternalIPv6Address")
                if [ -n "${extipv6address}" ]
                then
                    mecho --info "External IPv6 address : ${extipv6address}"
                    extipv6prefix=$(execute_soap_request \
                        "X_AVM_DE_GetIPv6Prefix" \
                        "" \
                        "${type}")
                    extipv6prefix=$(parse_xml_response "${extipv6prefix}" "NewIPv6Prefix")
                    if [ -n "${extipv6prefix}" ]
                    then
                        mecho --info "External IPv6 prefix  : ${extipv6prefix}"
                    else
                        mecho -n --info "External IPv6 prefix  : "
                        mecho --error "No external IPv6 prefix"
                        exit_code=10
                    fi
                else
                    mecho -n --info "External IPv6 address : "
                    mecho --error "No external IPv6 address"
                    exit_code=10
                fi
            ;;
            extipv4)
                # Print external ipv4 address
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                extipv4address=$(execute_soap_request \
                    "GetExternalIPAddress" \
                    "" \
                    "${type}")
                extipv4address=$(parse_xml_response "${extipv4address}" "NewExternalIPAddress")
                if [ -n "${extipv4address}" ]
                then
                    mecho --info "External IPv4 address ${device}: ${extipv4address}"
                else
                    mecho -n --info "External IPv4 address ${device}: "
                    mecho --error "No external IPv4 address"
                    exit_code=9
                fi
            ;;
            extipv6)
                # Print external ipv6 address
                mecho --info "External IPv6 data ${device}"
                get_url_and_urn "igddesc.xml" "WANIPConn1" "WANIPConnection:1"
                extipv6address=$(execute_soap_request \
                    "X_AVM_DE_GetExternalIPv6Address" \
                    "" \
                    "${type}")
                extipv6address=$(parse_xml_response "${extipv6address}" "NewExternalIPv6Address")
                if [ -n "${extipv6address}" ]
                then
                    mecho --info "External IPv6 address : ${extipv6address}"
                    extipv6prefix=$(execute_soap_request \
                        "X_AVM_DE_GetIPv6Prefix" \
                        "" \
                        "${type}")
                    extipv6prefix=$(parse_xml_response "${extipv6prefix}" "NewIPv6Prefix")
                    if [ -n "${extipv6prefix}" ]
                    then
                        mecho --info "External IPv6 prefix  : ${extipv6prefix}"
                    else
                        mecho -n --info "External IPv6 prefix  : "
                        mecho --error "No external IPv6 prefix"
                        exit_code=10
                    fi
                else
                    mecho -n --info "External IPv6 address : "
                    mecho --error "No external IPv6 address"
                    exit_code=10
                fi
            ;;
            conninfo)
                # Internet connection informations
                mecho --info "Internet connection informations ${device}"
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                conninfo=$(execute_soap_request \
                    "GetStatusInfo" \
                    "" \
                    "${type}")
                if (echo "${conninfo}" | grep -q "GetStatusInfoResponse")
                then
                    conninfoconnectionstatus=$(parse_xml_response "${conninfo}" "NewConnectionStatus")
                    conninfolastconnectionerror=$(parse_xml_response "${conninfo}" "NewLastConnectionError")
                    conninfouptime=$(parse_xml_response "${conninfo}" "NewUptime")
                    echo "Connection status     : ${conninfoconnectionstatus}"
                    echo "Last connection error : ${conninfolastconnectionerror}"
                    echo "Online time           : $(convert_seconds_to_time_string ${conninfouptime})"
                    if [ "${conninfoconnectionstatus}" != "Connected" ]
                    then
                        exit_code=8
                    fi
                else
                    exit_code=1
                fi
            ;;
            connstat)
                # Internet connection status
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                execute_soap_request \
                    "GetStatusInfo" \
                    "" \
                    "${type}" \
                    | grep -q "Connected"
                exit_code=$?
                if [ "${exit_code}" -eq 0 ]
                then
                    mecho --info "Internet connection established ${device}"
                else
                    mecho --error "No internet connection ${device}"
                    exit_code=8
                fi
            ;;
            ddnsinfo)
                # DDNS service informations
                mecho --info "Dynamic DNS service informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_remote" "X_AVM-DE_RemoteAccess:1"
                ddnsinfo=$(execute_soap_request \
                    "GetDDNSInfo" \
                    "" \
                    "${type}")
                if (echo "${ddnsinfo}" | grep -q "GetDDNSInfoResponse")
                then
                    ddnsinfoenabled=$(parse_xml_response "${ddnsinfo}" "NewEnabled")
                    ddnsinfoprovider=$(parse_xml_response "${ddnsinfo}" "NewProviderName")
                    ddnsinfoupdateurl=$(parse_xml_response "${ddnsinfo}" "NewUpdateURL")
                    ddnsinfoupdateurl=$(convert_html_entities "${ddnsinfoupdateurl}")
                    ddnsinfodomain=$(parse_xml_response "${ddnsinfo}" "NewDomain")
                    ddnsinfostatusipv4=$(parse_xml_response "${ddnsinfo}" "NewStatusIPv4")
                    ddnsinfostatusipv6=$(parse_xml_response "${ddnsinfo}" "NewStatusIPv6")
                    ddnsinfousername=$(parse_xml_response "${ddnsinfo}" "NewUsername")
                    ddnsinfomode=$(parse_xml_response "${ddnsinfo}" "NewMode")
                    ddnsinfoserveripv4=$(parse_xml_response "${ddnsinfo}" "NewServerIPv4")
                    ddnsinfoserveripv6=$(parse_xml_response "${ddnsinfo}" "NewServerIPv6")
                    echo "Enabled       : $(convert_yes_no ${ddnsinfoenabled})"
                    echo "Provider name : ${ddnsinfoprovider}"
                    echo "Update URL    : ${ddnsinfoupdateurl}"
                    echo "Domain        : ${ddnsinfodomain}"
                    echo "User name     : ${ddnsinfousername}"
                    case "${ddnsinfomode}" in
                        ddns_v4)
                            echo "Update mode   : Update only IPv4 address"
                        ;;
                        ddns_v6)
                            echo "Update mode   : Update only IPv6 address"
                        ;;
                        ddns_both)
                            echo "Update mode   : Update IPv4 and IPv6 addresses with separate requests"
                        ;;
                        ddns_both_together)
                            echo "Update mode   : Update IPv4 and IPv6 addresses with one request"
                        ;;
                    esac
                    echo "Status IPv4   : ${ddnsinfostatusipv4}"
                    echo "Status IPv6   : ${ddnsinfostatusipv6}"
                    echo "Server IPv4   : ${ddnsinfoserveripv4}"
                    echo "Server IPv6   : ${ddnsinfoserveripv6}"
                else
                    exit_code=1
                fi
            ;;
            timeinfo)
                # Time informations
                mecho --info "NTP Time Server informations ${device}"
                get_url_and_urn "tr64desc.xml" "time" "Time:1"
                timeinfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${timeinfo}" | grep -q "GetInfoResponse")
                then
                    timeinfontpserver1=$(parse_xml_response "${timeinfo}" "NewNTPServer1")
                    timeinfontpserver2=$(parse_xml_response "${timeinfo}" "NewNTPServer2")
                    timeinfocurrentlocaltime=$(parse_xml_response "${timeinfo}" "NewCurrentLocalTime")
                    timeinfolocaltimezone=$(parse_xml_response "${timeinfo}" "NewLocalTimeZone")
                    timeinfolocaltimezonename=$(parse_xml_response "${timeinfo}" "NewLocalTimeZoneName")
                    timeinfodaylightsavingsused=$(parse_xml_response "${timeinfo}" "NewDaylightSavingsUsed")
                    timeinfodaylightsavingsstart=$(parse_xml_response "${timeinfo}" "NewDaylightSavingsStart")
                    timeinfodaylightsavingsend=$(parse_xml_response "${timeinfo}" "NewDaylightSavingsEnd")
                    echo "NTP server 1             : ${timeinfontpserver1}"
                    echo "NTP server 2             : ${timeinfontpserver2}"
                    echo "Local time               : ${timeinfocurrentlocaltime}"
                    echo "Local time zone          : ${timeinfolocaltimezone}"
                    echo "Local time zone name     : ${timeinfolocaltimezonename}"
                    echo "Daylight savings enabled : $(convert_yes_no ${timeinfodaylightsavingsused})"
                    echo "Daylight savings start   : ${timeinfodaylightsavingsstart}"
                    echo "Daylight savings end     : ${timeinfodaylightsavingsend}"
                else
                    exit_code=1
                fi
            ;;
            wlancount)
                # Count and kind of WLANs
                defaultwlantypes
                mecho --info "Number and type of WLANs ${device}"
                mecho --info "(use number for wlan<n>info and wlan<n>switch commands)"
                case "${wlancount}" in
                    0)
                        echo "No WLAN available"
                    ;;
                    1|2|3|4)
                        for wlanidx in $(seq 1 1 ${wlancount})
                        do
                            detectwlantype ${wlanidx}
                            mecho -n --warn "${wlanidx}"
                            eval mecho --std ": "'$wlan'${wlanidx}'text'
                        done
                    ;;
                    *)
                        mecho --error "${wlancount} WLANs of unknown type"
                        exit_code=1
                    ;;
                esac
            ;;
            wlanswitch)
                # WLAN enable/disable switch; acts as button on fritzbox does
                mecho --info "Switching WLAN global \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "wlanconfig1" "WLANConfiguration:1"
                execute_soap_request \
                    "X_AVM-DE_SetWLANGlobalEnable" \
                    "<NewX_AVM-DE_WLANGlobalEnable>${new_enabled}</NewX_AVM-DE_WLANGlobalEnable>" \
                    "${type}" \
                    | grep -q "X_AVM-DE_SetWLANGlobalEnableResponse"
                exit_code=$?
            ;;
            wlan1switch|wlan2switch|wlan3switch|wlan4switch)
                # wlan1/wlan2/wlan3/wlan4 (2,4 GHz/5 GHz or guest/guest) enable/disable switch
                mecho --info "Switching WLAN ${command:4:1} \"${switch}\" ${device}"
                # Determine count of wlans
                wlancount=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/tr64desc.xml" | grep -Eo "WLANConfiguration:"'[[:digit:]]{1}'"</serviceType>" | wc -l)
                case "${command}" in
                    wlan1switch)
                        if [ "${wlancount}" -gt 0 ]
                        then
                            get_url_and_urn "tr64desc.xml" "wlanconfig1" "WLANConfiguration:1"
                        else
                            mecho --warn "No WLAN available ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan2switch)
                        if [ "${wlancount}" -gt 1 ]
                        then
                            get_url_and_urn "tr64desc.xml" "wlanconfig2" "WLANConfiguration:2"
                        else
                            mecho --warn "Fritzbox has no second wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan3switch)
                        if [ "${wlancount}" -gt 2 ]
                        then
                            get_url_and_urn "tr64desc.xml" "wlanconfig3" "WLANConfiguration:3"
                        else
                            mecho --warn "Fritzbox has no third wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan4switch)
                        if [ "${wlancount}" -gt 3 ]
                        then
                            get_url_and_urn "tr64desc.xml" "wlanconfig4" "WLANConfiguration:4"
                        else
                            mecho --warn "Fritzbox has no fourth wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                esac
                execute_soap_request \
                    "SetEnable" \
                    "<NewEnable>${new_enabled}</NewEnable>" \
                    "${type}" \
                    | grep -q "SetEnableResponse"
                exit_code=$?
            ;;
            wlan1info|wlan2info|wlan3info|wlan4info)
                # wlan1/wlan2/wlan3/wlan4 (2,4 GHz, 5 Ghz, guest wlan) informations
                defaultwlantypes
                case "${command}" in
                    wlan1info)
                        if [ "${wlancount}" -gt 0 ]
                        then
                            detectwlantype 1
                            mecho --info "${wlan1text} informations ${device}"
                            get_url_and_urn "tr64desc.xml" "wlanconfig1" "WLANConfiguration:1"
                        else
                            mecho --warn "No WLAN available ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan2info)
                        if [ "${wlancount}" -gt 1 ]
                        then
                            detectwlantype 2
                            mecho --info "${wlan2text} informations ${device}"
                            get_url_and_urn "tr64desc.xml" "wlanconfig2" "WLANConfiguration:2"
                        else
                            mecho --warn "Fritzbox has no second wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan3info)
                        if [ "${wlancount}" -gt 2 ]
                        then
                            detectwlantype 3
                            mecho --info "${wlan3text} informations ${device}"
                            get_url_and_urn "tr64desc.xml" "wlanconfig3" "WLANConfiguration:3"
                        else
                            mecho --warn "Fritzbox has no third wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                    wlan4info)
                        if [ "${wlancount}" -gt 3 ]
                        then
                            detectwlantype 4
                            mecho --info "${wlan4text} informations ${device}"
                            get_url_and_urn "tr64desc.xml" "wlanconfig4" "WLANConfiguration:4"
                        else
                            mecho --warn "Fritzbox has no fourth wlan ${device}"
                            exit_code=1
                            output_debugfbfile
                            exit 1
                        fi
                    ;;
                esac
                wlaninfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${wlaninfo}" | grep -q "GetInfoResponse")
                then
                    wlaninfoenabled=$(parse_xml_response "${wlaninfo}" "NewEnable")
                    wlaninfostatus=$(parse_xml_response "${wlaninfo}" "NewStatus")
                    wlaninfomaxbitrate=$(parse_xml_response "${wlaninfo}" "NewMaxBitRate")
                    wlaninfochannel=$(parse_xml_response "${wlaninfo}" "NewChannel")
                    wlaninfossid=$(parse_xml_response "${wlaninfo}" "NewSSID")
                    wlaninfobeacon=$(parse_xml_response "${wlaninfo}" "NewBeaconType")
                    wlaninfopossiblebeacon=$(parse_xml_response "${wlaninfo}" "NewX_AVM-DE_PossibleBeaconTypes")
                    wlaninfomaccontrol=$(parse_xml_response "${wlaninfo}" "NewMACAddressControlEnabled")
                    wlaninfostandard=$(parse_xml_response "${wlaninfo}" "NewStandard")
                    wlaninfobssid=$(parse_xml_response "${wlaninfo}" "NewBSSID")
                    wlaninfobasicencryp=$(parse_xml_response "${wlaninfo}" "NewBasicEncryptionModes")
                    wlaninfobasicauth=$(parse_xml_response "${wlaninfo}" "NewBasicAuthenticationMode")
                    wlaninfomaxcharsssid=$(parse_xml_response "${wlaninfo}" "NewMaxCharsSSID")
                    wlaninfomincharsssid=$(parse_xml_response "${wlaninfo}" "NewMinCharsSSID")
                    wlaninfoallowedcharsssid=$(parse_xml_response "${wlaninfo}" "NewAllowedCharsSSID")
                    wlaninfoallowedcharsssid1=$(echo "${wlaninfoallowedcharsssid}" | cut -d " " -f 1)
                    wlaninfoallowedcharsssid2=$(echo "${wlaninfoallowedcharsssid}" | cut -d "z" -f 2)
                    wlaninfoallowedcharsssid2=$(convert_html_entities "${wlaninfoallowedcharsssid2}")
                    wlaninfomaxcharspsk=$(parse_xml_response "${wlaninfo}" "NewMaxCharsPSK")
                    wlaninfomincharspsk=$(parse_xml_response "${wlaninfo}" "NewMinCharsPSK")
                    wlaninfoallowedcharspsk=$(parse_xml_response "${wlaninfo}" "NewAllowedCharsPSK")
                    wlaninfofrequencyband=$(parse_xml_response "${wlaninfo}" "NewX_AVM-DE_FrequencyBand")
                    wlaninfowlanglobalenable=$(parse_xml_response "${wlaninfo}" "NewX_AVM-DE_WLANGlobalEnable")
                    echo "Enabled                   : $(convert_yes_no ${wlaninfoenabled})"
                    echo "Status                    : ${wlaninfostatus}"
                    # Currently not supported
                    # echo "Max Bit Rate              : ${wlaninfomaxbitrate}"
                    echo "Channel                   : ${wlaninfochannel}"
                    echo "SSID                      : ${wlaninfossid}"
                    echo "Beacon Type               : ${wlaninfobeacon}"
                    echo "Possible Beacon Types     : ${wlaninfopossiblebeacon}"
                    echo "MAC Address Control       : $(convert_yes_no ${wlaninfomaccontrol})"
                    # Currently not supported
                    # echo "Standard                  : ${wlaninfostandard}"
                    echo "BSSID                     : ${wlaninfobssid}"
                    echo "Basic Encryption Modes    : ${wlaninfobasicencryp}"
                    # Currently not supported
                    # echo "Basic Authentication Mode : ${wlaninfobasicauth}"
                    echo "Max Chars SSID            : ${wlaninfomaxcharsssid}"
                    echo "Min Chars SSID            : ${wlaninfomincharsssid}"
                    echo "Allowed Chars SSID        : ${wlaninfoallowedcharsssid1}"
                    echo "                          : ${wlaninfoallowedcharsssid2}"
                    echo "Max Chars PSK             : ${wlaninfomaxcharspsk}"
                    echo "Min Chars PSK             : ${wlaninfomincharspsk}"
                    echo "Allowed Chars PSK         : ${wlaninfoallowedcharspsk}"
                    echo "Frequency band            : ${wlaninfofrequencyband}"
                    echo "WLan global enabled       : $(convert_yes_no ${wlaninfowlanglobalenable})"
                else
                    exit_code=1
                fi
            ;;
            dectinfo)
                # Show all dect devices
                # mecho --info "DECT telephone list ${device}"
                # get_url_and_urn "tr64desc.xml" "x_dect" "X_AVM-DE_Dect:1"
                # idx=0
                # dectcount=$(execute_soap_request \
                #     "GetNumberOfDectEntries" \
                #     "" \
                #     "${type}")
                # dectcount=$(parse_xml_response "${dectcount}" "NewNumberOfEntries")
                # if [ -n "${dectcount}" ] && [ "${dectcount}" -gt 0 ]
                # then
                #     techo --begin "4r 4 19 19 10r 11 13"
                #     techo --info --row "ID" "Act" "Name" "Model" "Upd:Avail" "Successfull" "Info"
                #     while [ "${idx}" -lt "${dectcount}" ]
                #     do
                #         dectentry=$(execute_soap_request \
                #             "GetGenericDectEntry" \
                #             "<NewIndex>${idx}</NewIndex>" \
                #             "${type}")
                #         if (echo "${dectentry}" | grep -q "GetGenericDectEntryResponse")
                #         then
                #             dectentryid=$(parse_xml_response "${dectentry}" "NewID")
                #             dectentryactive=$(parse_xml_response "${dectentry}" "NewActive")
                #             dectentryname=$(parse_xml_response "${dectentry}" "NewName")
                #             dectentrymodel=$(parse_xml_response "${dectentry}" "NewModel")
                #             dectentryupdateavailable=$(parse_xml_response "${dectentry}" "NewUpdateAvailable")
                #             dectentryupdatesuccessful=$(parse_xml_response "${dectentry}" "NewUpdateSuccessful")
                #             dectentryupdateinfo=$(parse_xml_response "${dectentry}" "NewUpdateInfo")
                #             techo --row \
                #                 "${dectentryid}" \
                #                 "$(convert_yes_no ${dectentryactive})" \
                #                 "${dectentryname}" \
                #                 "${dectentrymodel}" \
                #                 "$(convert_yes_no ${dectentryupdateavailable})" \
                #                 "${dectentryupdatesuccessful}" \
                #                 "${dectentryupdateinfo}"
                #             idx=$((idx + 1))
                #         else
                #             mecho --error "Invalid dect index found!"
                #             mecho --error "Please reboot your Fritzbox to fix the problem."
                #             exit_code=1
                #             break
                #         fi
                #     done
                #     techo --end
                # else
                #     [ -z "${dectcount}" ] && exit_code=1
                # fi
                mecho --info "DECT telephone list ${device}"
                get_url_and_urn "tr64desc.xml" "x_dect" "X_AVM-DE_Dect:1"
                dectfile=$(execute_soap_request \
                    "GetDectListPath" \
                    "" \
                    "${type}")
                dectfile=$(parse_xml_response "${dectfile}" "NewDectListPath")
                if [ -n "${dectfile}" ]
                then
                    if (echo ${dectfile} | grep "^http")
                    then
                        dectlist=$(wget -q --no-check-certificate -O - "${dectfile}")
                    else
                        dectlist=$(wget -q --no-check-certificate -O - "https://${FBIP}:${FBPORTSSL}${dectfile}")
                    fi
                    if [ -n "${dectlist}" ]
                    then
                        dectindexe=$(parse_singular_element_list_response "${dectlist}" "//Index")
                        if [ -n "${dectindexe}" ]
                        then
                            techo --begin "4r 4 19 19 10r 11 13"
                            techo --info --row "ID" "Act" "Name" "Model" "Upd:Avail" "Successfull" "Info"
                            dectelement="List/Item[Index='\${dectindex}']"
                            for dectindex in ${dectindexe}
                            do
                                dectentryid=$(parse_list_response "${dectlist}" "${dectelement@P}" "Id")
                                dectentryactive=$(parse_list_response "${dectlist}" "${dectelement@P}" "Active")
                                dectentryname=$(parse_list_response "${dectlist}" "${dectelement@P}" "Name")
                                dectentrymodel=$(parse_list_response "${dectlist}" "${dectelement@P}" "Model")
                                dectentryupdateavailable=$(parse_list_response "${dectlist}" "${dectelement@P}" "UpdateAvailable")
                                dectentryupdatesuccessful=$(parse_list_response "${dectlist}" "${dectelement@P}" "UpdateSuccessful")
                                dectentryupdateinfo=$(parse_list_response "${dectlist}" "${dectelement@P}" "UpdateInfo" | head -1)
                                techo --row \
                                    "${dectentryid}" \
                                    "$(convert_yes_no ${dectentryactive})" \
                                    "${dectentryname}" \
                                    "${dectentrymodel}" \
                                    "$(convert_yes_no ${dectentryupdateavailable})" \
                                    "${dectentryupdatesuccessful}" \
                                    "${dectentryupdateinfo}"
                            done
                            techo --end
                        fi
                    else
                        exit_code=1
                    fi
                else
                    exit_code=1
                fi
            ;;
            deflectionsinfo)
                # Show all telephone deflections
                # mecho --info "Telephone deflections ${device}"
                # get_url_and_urn "tr64desc.xml" "x_contact" "X_AVM-DE_OnTel:1"
                # idx=0
                # deflectionscount=$(execute_soap_request \
                #     "GetNumberOfDeflections" \
                #     "" \
                #     "${type}")
                # deflectionscount=$(parse_xml_response "${deflectionscount}" "NewNumberOfDeflections")
                # if [ -n "${deflectionscount}" ] && [ "${deflectionscount}" -gt 0 ]
                # then
                #     techo --begin "4r 4 13 15 34 4r 6r"
                #     techo --info --row "Idx" "Act" "Type" "Mode" "Incoming > Outgoing number" "Out" "PB-ID"
                #     while [ "${idx}" -lt "${deflectionscount}" ]
                #     do
                #         if [ "${showfritzindexes:-false}" = "true" ]
                #         then
                #             count="${idx}"
                #         else
                #             count=$((idx + 1))
                #         fi
                #         deflection=$(execute_soap_request \
                #             "GetDeflection" \
                #             "<NewDeflectionID>${idx}</NewDeflectionID>" \
                #             "${type}")
                #         if (echo "${deflection}" | grep -q "GetDeflectionResponse")
                #         then
                #             deflectionenabled=$(parse_xml_response "${deflection}" "NewEnable")
                #             deflectiontype=$(parse_xml_response "${deflection}" "NewType")
                #             deflectionnumber=$(parse_xml_response "${deflection}" "NewNumber")
                #             deflectiontonumber=$(parse_xml_response "${deflection}" "NewDeflectionToNumber")
                #             deflectionmode=$(parse_xml_response "${deflection}" "NewMode")
                #             deflectionoutgoing=$(parse_xml_response "${deflection}" "NewOutgoing")
                #             deflectionphonebookid=$(parse_xml_response "${deflection}" "NewPhonebookID")
                #             techo --row \
                #                 "${count}" \
                #                 "$(convert_yes_no ${deflectionenabled})" \
                #                 "${deflectiontype}" \
                #                 "${deflectionmode}" \
                #                 "${deflectionnumber} > ${deflectiontonumber:--}" \
                #                 "${deflectionoutgoing}" \
                #                 "${deflectionphonebookid}"
                #             idx=$((idx + 1))
                #         else
                #             mecho --error "Invalid deflection index found!"
                #             mecho --error "Please reboot your Fritzbox to fix the problem."
                #             exit_code=1
                #             break
                #         fi
                #     done
                #     techo --end
                # else
                #     [ -z "${deflectionscount}" ] && exit_code=1
                # fi
                mecho --info "Telephone deflections ${device}"
                get_url_and_urn "tr64desc.xml" "x_contact" "X_AVM-DE_OnTel:1"
                deflectionlist=$(execute_soap_request \
                    "GetDeflections" \
                    "" \
                    "${type}")
                if (echo "${deflectionlist}" | grep -q "GetDeflectionsResponse")
                then
                    deflectionlist=$(convert_html_entities "${deflectionlist}")
                    deflectionids=$(parse_singular_element_list_response "${deflectionlist}" "//DeflectionId")
                    if [ -n "${deflectionids}" ]
                    then
                        techo --begin "4r 4 13 15 34 4r 6r"
                        techo --info --row "Idx" "Act" "Type" "Mode" "Incoming > Outgoing number" "Out" "PB-ID"
                        deflectionelement="/s:Envelope/s:Body//List/Item[DeflectionId='\${deflectionid}']"
                        for deflectionid in ${deflectionids}
                        do
                            if [ "${showfritzindexes:-false}" = "true" ]
                            then
                                count="${deflectionid}"
                            else
                                count=$((deflectionid + 1))
                            fi
                            deflectionenabled=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "Enable")
                            deflectiontype=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "Type")
                            deflectionnumber=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "Number")
                            deflectiontonumber=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "DeflectionToNumber")
                            deflectionmode=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "Mode")
                            deflectionoutgoing=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "Outgoing")
                            deflectionphonebookid=$(parse_list_response "${deflectionlist}" "${deflectionelement@P}" "PhonebookID")
                            techo --row \
                                "${count}" \
                                "$(convert_yes_no ${deflectionenabled})" \
                                "${deflectiontype}" \
                                "${deflectionmode}" \
                                "${deflectionnumber} > ${deflectiontonumber:--}" \
                                "${deflectionoutgoing}" \
                                "${deflectionphonebookid}"
                        done
                        techo --end
                    fi
                else
                    exit_code=1
                fi
            ;;
            homeautoinfo)
                # Show home automation devices
                mecho --info "Home automation informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_homeauto" "X_AVM-DE_Homeauto:1"
                idx=0
                while [ true ]
                do
                    if [ "${showfritzindexes:-false}" = "true" ]
                    then
                        count="${idx}"
                    else
                        count=$((idx + 1))
                    fi
                    homeautoentry=$(execute_soap_request \
                        "GetGenericDeviceInfos" \
                        "<NewIndex>${idx}</NewIndex>" \
                        "${type}")
                    if (echo "${homeautoentry}" | grep -q "Invalid Action")
                    then
                        mecho --warn "Has user smart home rights on fritzbox? Proof in webgui!"
                        exit_code=1
                        output_debugfbfile
                        exit 1
                    fi
                    if (echo "${homeautoentry}" | grep -q "GetGenericDeviceInfosResponse")
                    then
                        homeautoain=$(parse_xml_response "${homeautoentry}" "NewAIN")
                        if [ -n "${searchhomeautoain}" ] && \
                           ! (echo "${homeautoain}" | grep -Eq "${searchhomeautoain}")
                        then
                            idx=$((idx + 1))
                            continue
                        fi
                        homeautodeviceid=$(parse_xml_response "${homeautoentry}" "NewDeviceId")
                        if [ -n "${searchhomeautodeviceid}" ] && \
                           ! (echo "${homeautodeviceid}" | grep -Eq "${searchhomeautodeviceid}")
                        then
                            idx=$((idx + 1))
                            continue
                        fi
                        homeautofunctionbitmask=$(parse_xml_response "${homeautoentry}" "NewFunctionBitMask")
                        homeautofirmwareversion=$(parse_xml_response "${homeautoentry}" "NewFirmwareVersion")
                        homeautomanufacturer=$(parse_xml_response "${homeautoentry}" "NewManufacturer")
                        homeautoproductname=$(parse_xml_response "${homeautoentry}" "NewProductName")
                        homeautodevicename=$(parse_xml_response "${homeautoentry}" "NewDeviceName")
                        if [ -n "${searchhomeautodevicename}" ] && \
                           ! (echo "${homeautodevicename}" | grep -Eq "${searchhomeautodevicename}")
                        then
                            idx=$((idx + 1))
                            continue
                        fi
                        homeautopresent=$(parse_xml_response "${homeautoentry}" "NewPresent")
                        homeautomultimeterisenabled=$(parse_xml_response "${homeautoentry}" "NewMultimeterIsEnabled")
                        homeautomultimeterisvalid=$(parse_xml_response "${homeautoentry}" "NewMultimeterIsValid")
                        homeautomultimeterpower=$(parse_xml_response "${homeautoentry}" "NewMultimeterPower")
                        homeautomultimeterenergy=$(parse_xml_response "${homeautoentry}" "NewMultimeterEnergy")
                        homeautotemperatureisenabled=$(parse_xml_response "${homeautoentry}" "NewTemperatureIsEnabled")
                        homeautotemperatureisvalid=$(parse_xml_response "${homeautoentry}" "NewTemperatureIsValid")
                        homeautotemperaturecelsius=$(parse_xml_response "${homeautoentry}" "NewTemperatureCelsius")
                        homeautotemperatureoffset=$(parse_xml_response "${homeautoentry}" "NewTemperatureOffset")
                        homeautoswitchisenabled=$(parse_xml_response "${homeautoentry}" "NewSwitchIsEnabled")
                        homeautoswitchisvalid=$(parse_xml_response "${homeautoentry}" "NewSwitchIsValid")
                        homeautoswitchstate=$(parse_xml_response "${homeautoentry}" "NewSwitchState")
                        homeautoswitchmode=$(parse_xml_response "${homeautoentry}" "NewSwitchMode")
                        homeautoswitchlock=$(parse_xml_response "${homeautoentry}" "NewSwitchLock")
                        homeautohkrisenabled=$(parse_xml_response "${homeautoentry}" "NewHkrIsEnabled")
                        homeautohkrisvalid=$(parse_xml_response "${homeautoentry}" "NewHkrIsValid")
                        homeautohkristemperature=$(parse_xml_response "${homeautoentry}" "NewHkrIsTemperature")
                        homeautohkrsetventilstatus=$(parse_xml_response "${homeautoentry}" "NewHkrSetVentilStatus")
                        homeautohkrsettemperature=$(parse_xml_response "${homeautoentry}" "NewHkrSetTemperature")
                        homeautohkrreduceventilstatus=$(parse_xml_response "${homeautoentry}" "NewHkrReduceVentilStatus")
                        homeautohkrreducetemperature=$(parse_xml_response "${homeautoentry}" "NewHkrReduceTemperature")
                        homeautohkrcomfortventilstatus=$(parse_xml_response "${homeautoentry}" "NewHkrComfortVentilStatus")
                        homeautohkrcomforttemperature=$(parse_xml_response "${homeautoentry}" "NewHkrComfortTemperature")
                        echo "${count}:AIN                         : ${homeautoain}"
                        echo "${count}:Device ID                   : ${homeautodeviceid}"
                        homeautotypearray=("HANFUN Gerät"           "?" \
                                           "?"                      "?" \
                                           "Alarm-Sensor"           "?" \
                                           "Heizkörperregler"       "Energie Messgerät" \
                                           "Temperatursensor"       "Schaltsteckdose" \
                                           "AVM DECT Repeater"      "Mikrofon" \
                                           "?"                      "HANFUN Unit" \
                                           "?"                      "?")
                        homeautotypebin=""
                        homeautotype=""
                        for typeidx in $(seq 15 -1 0)
                        do
                            homeautotypebit=$(((${homeautofunctionbitmask} >> ${typeidx}) & 1))
                            homeautotypebin=${homeautotypebin}${homeautotypebit}
                            if [ "${homeautotypebit}" -eq 1 ]
                            then
                                if [ -n "${homeautotype}" ]
                                then
                                    homeautotype="${homeautotype}; ${homeautotypearray[${typeidx}]}"
                                else
                                    homeautotype=${homeautotypearray[${idx}]}
                                fi
                            fi
                        done
                        echo "${count}:Functions (decimal/binary)  : ${homeautofunctionbitmask}/${homeautotypebin}"
                        echo "${count}:Functions (plain text)      : ${homeautotype}"
                        echo "${count}:Firmware version            : ${homeautofirmwareversion}"
                        echo "${count}:Manufacturer                : ${homeautomanufacturer}"
                        echo "${count}:Product name                : ${homeautoproductname}"
                        echo "${count}:Device name                 : ${homeautodevicename}"
                        echo "${count}:Connection status           : ${homeautopresent}"
                        echo "${count}:Multimeter enabled          : ${homeautomultimeterisenabled}"
                        echo "${count}:Multimeter valid            : ${homeautomultimeterisvalid}"
                        echo "${count}:Multimeter power (W)        : $(echo "scale=2; ${homeautomultimeterpower} / 100" | bc)"
                        echo "${count}:Multimeter energy (Wh)      : ${homeautomultimeterenergy}"
                        echo "${count}:Temperature enabled         : ${homeautotemperatureisenabled}"
                        echo "${count}:Temperature valid           : ${homeautotemperatureisvalid}"
                        echo "${count}:Temperature (C)             : $(echo "scale=1; ${homeautotemperaturecelsius} / 10" | bc)"
                        echo "${count}:Temperature offset (C)      : $(echo "scale=1; ${homeautotemperatureoffset} / 10" | bc)"
                        echo "${count}:Switch enabled              : ${homeautoswitchisenabled}"
                        echo "${count}:Switch valid                : ${homeautoswitchisvalid}"
                        echo "${count}:Switch status               : ${homeautoswitchstate}"
                        echo "${count}:Switch mode                 : ${homeautoswitchmode}"
                        echo "${count}:Switch lock                 : $(convert_yes_no ${homeautoswitchlock})"
                        echo "${count}:Hkr enabled                 : ${homeautohkrisenabled}"
                        echo "${count}:Hkr valid                   : ${homeautohkrisvalid}"
                        echo "${count}:Hkr temperature (C)         : $(echo "scale=1; ${homeautohkristemperature} / 10" | bc)"
                        echo "${count}:Hkr valve status set        : ${homeautohkrsetventilstatus}"
                        echo "${count}:Hkr temperature set (C)     : $(echo "scale=1; ${homeautohkrsettemperature} / 10" | bc)"
                        echo "${count}:Hkr valve status reduced    : ${homeautohkrreduceventilstatus}"
                        echo "${count}:Hkr temperature reduced (C) : $(echo "scale=1; ${homeautohkrreducetemperature} / 10" | bc)"
                        echo "${count}:Hkr valve status comfort    : ${homeautohkrcomfortventilstatus}"
                        echo "${count}:Hkr temperature comfort (C) : $(echo "scale=1; ${homeautohkrcomforttemperature} / 10" | bc)"
                        idx=$((idx + 1))
                    else
                        break
                    fi
                done
            ;;
            homeautoswitch)
                # Switch home automation switch to on or off
                mecho --info "Switching home automation device ${ain} \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_homeauto" "X_AVM-DE_Homeauto:1"
                if [ "${new_enabled}" = "1" ]
                then
                    switchstate="ON"
                else
                    switchstate="OFF"
                fi
                execute_soap_request \
                    "SetSwitch" \
                    "<NewAIN>${ain}</NewAIN> \
                     <NewSwitchState>${switchstate}</NewSwitchState>" \
                    "${type}" \
                    | grep -q "SetSwitchResponse"
                exit_code=$?
            ;;
            homepluginfo)
                # Show all homeplug/powerline devices
                mecho --info "Homeplug/Powerline devices list ${device}"
                get_url_and_urn "tr64desc.xml" "x_homeplug" "X_AVM-DE_Homeplug:1"
                idx=0
                homeplugcount=$(execute_soap_request \
                    "GetNumberOfDeviceEntries" \
                    "" \
                    "${type}")
                homeplugcount=$(parse_xml_response "${homeplugcount}" "NewNumberOfEntries")
                if [ -n "${homeplugcount}" ] && [ "${homeplugcount}" -gt 0 ]
                then
                    techo --begin "4r 4 15 15 18 14r 10"
                    techo --info --row "Idx" "Act" "Name" "Model" "MAC address" "Update: Avail" "Successful"
                    while [ "${idx}" -lt "${homeplugcount}" ]
                    do
                        if [ "${showfritzindexes:-false}" = "true" ]
                        then
                            count="${idx}"
                        else
                            count=$((idx + 1))
                        fi
                        homeplugentry=$(execute_soap_request \
                            "GetGenericDeviceEntry" \
                            "<NewIndex>${idx}</NewIndex>" \
                            "${type}")
                        if (echo "${homeplugentry}" | grep -q "GetGenericDeviceEntryResponse")
                        then
                            homeplugentrymacaddress=$(parse_xml_response "${homeplugentry}" "NewMACAddress")
                            homeplugentryactive=$(parse_xml_response "${homeplugentry}" "NewActive")
                            homeplugentryname=$(parse_xml_response "${homeplugentry}" "NewName")
                            homeplugentrymodel=$(parse_xml_response "${homeplugentry}" "NewModel")
                            homeplugentryupdateavailable=$(parse_xml_response "${homeplugentry}" "NewUpdateAvailable")
                            homeplugentryupdatesuccessful=$(parse_xml_response "${homeplugentry}" "NewUpdateSuccessful")
                            techo --row \
                                "${count}" \
                                "$(convert_yes_no ${homeplugentryactive})" \
                                "${homeplugentryname}" \
                                "${homeplugentrymodel}" \
                                "${homeplugentrymacaddress}" \
                                "$(convert_yes_no ${homeplugentryupdateavailable})" \
                                "${homeplugentryupdatesuccessful}"
                            idx=$((idx + 1))
                        else
                            mecho --error "Invalid homeplug index found!"
                            mecho --error "Please reboot your Fritzbox to fix the problem."
                            exit_code=1
                            break
                        fi
                    done
                    techo --end
                else
                    [ -z "${homeplugcount}" ] && exit_code=1
                fi
            ;;
            hostsinfo)
                # Show all hosts
                mecho --info "Hosts list ${device}"
                get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                idx=0
                hostscount=$(execute_soap_request \
                    "GetHostNumberOfEntries" \
                    "" \
                    "${type}")
                hostscount=$(parse_xml_response "${hostscount}" "NewHostNumberOfEntries")
                if [ -n "${hostscount}" ] && [ "${hostscount}" -gt 0 ]
                then
                    header="false"
                    while [ "${idx}" -lt "${hostscount}" ]
                    do
                        if [ "${showfritzindexes:-false}" = "true" ]
                        then
                            count="${idx}"
                        else
                            count=$((idx + 1))
                        fi
                        get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                        hostentry=$(execute_soap_request \
                            "GetGenericHostEntry" \
                            "<NewIndex>${idx}</NewIndex>" \
                            "${type}")
                        if (echo "${hostentry}" | grep -q "GetGenericHostEntryResponse")
                        then
                            hostentryipaddress=$(parse_xml_response "${hostentry}" "NewIPAddress")
                            hostentryaddresssource=$(parse_xml_response "${hostentry}" "NewAddressSource")
                            hostentryleasetimeremaining=$(parse_xml_response "${hostentry}" "NewLeaseTimeRemaining")
                            hostentrymacaddress=$(parse_xml_response "${hostentry}" "NewMACAddress")
                            hostentryinterfacetype=$(parse_xml_response "${hostentry}" "NewInterfaceType")
                            if [ "${hostentryinterfacetype}" = "802.11" ]
                            then
                                hostentryinterfacetype="WLAN"
                            fi
                            hostentryactive=$(parse_xml_response "${hostentry}" "NewActive")
                            hostentryhostname=$(parse_xml_response "${hostentry}" "NewHostName")
                            if [ -n "${hostentryipaddress}" ]
                            then
                                if [ "${hostentryaddresssource}" = "DHCP" ]
                                then
                                    if [ "${hostentryleasetimeremaining}" -eq 0 ]
                                    then
                                        hostentryip="${hostentryipaddress}:${hostentryaddresssource}:${hostentryleasetimeremaining}"
                                    else
                                        if [ "$((hostentryleasetimeremaining / 3600))" -eq 0 ]
                                        then
                                            if [ "$((hostentryleasetimeremaining / 60))" -eq 0 ]
                                            then
                                                hostentryip="${hostentryipaddress}:${hostentryaddresssource}:${hostentryleasetimeremaining}s"
                                            else
                                                hostentryip="${hostentryipaddress}:${hostentryaddresssource}:$((hostentryleasetimeremaining / 60))m"
                                            fi
                                        else
                                            hostentryip="${hostentryipaddress}:${hostentryaddresssource}:$((hostentryleasetimeremaining / 3600))h"
                                        fi
                                    fi
                                else
                                    hostentryip="${hostentryipaddress}:${hostentryaddresssource}"
                                fi
                                if [ "${showWANstatus}" = "true" ]
                                then
                                    get_url_and_urn "tr64desc.xml" "x_hostfilter" "X_AVM-DE_HostFilter:1"
                                    hostentrywan=$(execute_soap_request \
                                        "GetWANAccessByIP" \
                                        "<NewIPv4Address>${hostentryipaddress}</NewIPv4Address>" \
                                        "${type}")
                                    if (echo "${hostentrywan}" | grep -q "GetWANAccessByIPResponse")
                                    then
                                        hostentrywandisallow=$(parse_xml_response "${hostentrywan}" "NewDisallow")
                                        hostentrywanaccess=$(parse_xml_response "${hostentrywan}" "NewWANAccess")
                                        hostentrywan="no"
                                        if [ "${hostentrywanaccess}" = "error" ]
                                        then
                                            hostentrywan="?"
                                        else
                                            if [ "${hostentrywandisallow}" = "0" ] && [ "${hostentrywanaccess}" = "granted" ]
                                            then
                                                hostentrywan="yes"
                                            fi
                                        fi
                                    else
                                        if [ "${idx}" = "0" ] && (echo "${hostentrywan}" | grep -q "Invalid Action")
                                        then
                                            mecho --warn "Disabled \"--showWANstatus\": Fritzbox does not support this function."
                                            showWANstatus="false"
                                        else
                                            hostentrywan="?"
                                        fi
                                        exit_code=1
                                    fi
                                fi
                            else
                                hostentryip=""
                                hostentrywan="?"
                            fi
                            if [ "${showWOLstatus}" = "true" ] && [ -n "${hostentrymacaddress}" ]
                            then
                                get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                                hostentrywol=$(execute_soap_request \
                                    "X_AVM-DE_GetAutoWakeOnLANByMACAddress" \
                                    "<NewMACAddress>${hostentrymacaddress}</NewMACAddress>" \
                                    "${type}")
                                hostentrywol=$(parse_xml_response "${hostentrywol}" "NewAutoWOLEnabled")
                                if [ -z "${hostentrywol}" ]
                                then
                                    exit_code=1
                                fi
                            else
                                hostentrywol="0"
                            fi
                            hostentryactive=$(convert_yes_no ${hostentryactive})
                            case "${showWANstatus},${showWOLstatus}" in
                                false,false)
                                    if ! [ "${header}" = "true" ]
                                    then
                                        techo --begin "4r 4 23 6 18 25"
                                        techo --info --row "Idx" "Act" "Host name" "Inter" "Mac address" "IP:Type:RemainLeaseTime"
                                        header="true"
                                    fi
                                    if [ "${showhosts}" = "${hostentryactive}" ] || [ "${showhosts}" = "all" ]
                                    then
                                        techo --row \
                                            "${count}" \
                                            "${hostentryactive}" \
                                            "${hostentryhostname}" \
                                            "${hostentryinterfacetype}" \
                                            "${hostentrymacaddress}" \
                                            "${hostentryip}"
                                    fi
                                ;;
                                true,false)
                                    if ! [ "${header}" = "true" ]
                                    then
                                        techo --begin "4r 4 4 19 6 18 25"
                                        techo --info --row "Idx" "Act" "WAN" "Host name" "Inter" "Mac address" "IP:Type:RemainLeaseTime"
                                        header="true"
                                    fi
                                    if [ "${showhosts}" = "${hostentryactive}" ] || [ "${showhosts}" = "all" ]
                                    then
                                        techo --row \
                                            "${count}" \
                                            "${hostentryactive}" \
                                            "${hostentrywan}" \
                                            "${hostentryhostname}" \
                                            "${hostentryinterfacetype}" \
                                            "${hostentrymacaddress}" \
                                            "${hostentryip}"
                                    fi
                                ;;
                                false,true)
                                    if ! [ "${header}" = "true" ]
                                    then
                                        techo --begin "4r 4 4 19 6 18 25"
                                        techo --info --row "Idx" "Act" "WOL" "Host name" "Inter" "Mac address" "IP:Type:RemainLeaseTime"
                                        header="true"
                                    fi
                                    if [ "${showhosts}" = "${hostentryactive}" ] || [ "${showhosts}" = "all" ]
                                    then
                                        techo --row \
                                            "${count}" \
                                            "${hostentryactive}" \
                                            "$(convert_yes_no ${hostentrywol})" \
                                            "${hostentryhostname}" \
                                            "${hostentryinterfacetype}" \
                                            "${hostentrymacaddress}" \
                                            "${hostentryip}"
                                    fi
                                ;;
                                true,true)
                                    if ! [ "${header}" = "true" ]
                                    then
                                        techo --begin "4r 4 4 4 15 6 18 25"
                                        techo --info --row "Idx" "Act" "WAN" "WOL" "Host name" "Inter" "Mac address" "IP:Type:RemainLeaseTime"
                                        header="true"
                                    fi
                                    if [ "${showhosts}" = "${hostentryactive}" ] || [ "${showhosts}" = "all" ]
                                    then
                                        techo --row \
                                            "${count}" \
                                            "${hostentryactive}" \
                                            "${hostentrywan}" \
                                            "$(convert_yes_no ${hostentrywol})" \
                                            "${hostentryhostname}" \
                                            "${hostentryinterfacetype}" \
                                            "${hostentrymacaddress}" \
                                            "${hostentryip}"
                                    fi
                                ;;
                            esac
                            idx=$((idx + 1))
                        else
                            mecho --error "Invalid host index found!"
                            mecho --error "Please reboot your Fritzbox to fix the problem."
                            exit_code=1
                            break
                        fi
                    done
                    techo --end
                else
                    [ -z "${hostscount}" ] && exit_code=1
                fi
            ;;
            hostinfo)
                # Information about host given by ip
                if [ -n "${name}" ]
                then
                    mecho --info "Informations about host ${name} ${device}"
                    ip=$(determine_ip_or_mac_from_name "${name}" "IPAddress")
                fi
                if [ -n "${ip}" ] && ! (echo ${ip} | grep -q "Unable") && ! (echo ${ip} | grep -q "not found")
                then
                    if [ -n "${name}" ]
                    then
                        echo "IP address ${ip} for host ${name} determined."
                    else
                        mecho --info "Informations about host ${ip} ${device}"
                    fi
                    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                    hostbyipinfo=$(execute_soap_request \
                        "X_AVM-DE_GetSpecificHostEntryByIP" \
                        "<NewIPAddress>${ip}</NewIPAddress>" \
                        "${type}")
                    if (echo "${hostbyipinfo}" | grep -q "X_AVM-DE_GetSpecificHostEntryByIPResponse")
                    then
                        hostbyipinfomacaddress=$(parse_xml_response "${hostbyipinfo}" "NewMACAddress")
                        hostbyipinfohostname=$(parse_xml_response "${hostbyipinfo}" "NewHostName")
                        hostbyipinfoactive=$(parse_xml_response "${hostbyipinfo}" "NewActive")
                        hostbyipinfointerfacetype=$(parse_xml_response "${hostbyipinfo}" "NewInterfaceType")
                        hostbyipinfoport=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Port")
                        hostbyipinfospeed=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Speed")
                        hostbyipinfoupdateavail=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_UpdateAvailable")
                        hostbyipinfoupdatesuccessful=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_UpdateSuccessful")
                        hostbyipinfoinfourl=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_InfoURL")
                        hostbyipinfomodel=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Model")
                        hostbyipinfourl=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_URL")
                        if [ ${firmware} -ge 750 ]
                        then
                            hostbyipinfomacaddresslist=$(parse_xml_response "${hostbyipinfo}" "NewMACAddressList")
                            hostbyipinfoguest=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Guest")
                            hostbyipinforequestclient=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_RequestClient")
                            hostbyipinfovpn=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_VPN")
                            hostbyipinfowanaccess=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_WANAccess")
                            hostbyipinfodisallow=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Disallow")
                            hostbyipinfoismeshable=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_IsMeshable")
                            hostbyipinfopriority=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_Priority")
                            hostbyipinfofriendlyname=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_FriendlyName")
                            hostbyipinfofriendlynamewritable=$(parse_xml_response "${hostbyipinfo}" "NewX_AVM-DE_FriendlyNameIsWriteable")
                        fi
                        echo "Host name                  : ${hostbyipinfohostname}"
                        if [ ${firmware} -ge 750 ]
                        then
                            echo "Friendly name              : ${hostbyipinfofriendlyname}"
                            echo "Friendly name writable     : $(convert_yes_no ${hostbyipinfofriendlynamewritable})"
                        fi
                        echo "Model                      : ${hostbyipinfomodel}"
                        echo "MAC address                : ${hostbyipinfomacaddress}"
                        if [ ${firmware} -ge 750 ]
                        then
                            echo "MAC address list           : ${hostbyipinfomacaddresslist}"
                        fi
                        echo "Active                     : $(convert_yes_no ${hostbyipinfoactive})"
                        echo "Interface type             : ${hostbyipinfointerfacetype}"
                        echo "Port                       : ${hostbyipinfoport}"
                        echo "Speed                      : ${hostbyipinfospeed}"
                        if [ ${firmware} -ge 750 ]
                        then
                            echo "Guest                      : $(convert_yes_no ${hostbyipinfoguest})"
                            echo "VPN                        : $(convert_yes_no ${hostbyipinfovpn})"
                            case "${hostbyipinfowanaccess}" in
                                granted)
                                    hostbyipinfowanaccess="yes"
                                ;;
                                denied)
                                    hostbyipinfowanaccess="no"
                                ;;
                            esac
                            echo "WAN access                 : ${hostbyipinfowanaccess}"
                            echo "Disallowed                 : $(convert_yes_no ${hostbyipinfodisallow})"
                            echo "Meshable                   : $(convert_yes_no ${hostbyipinfoismeshable})"
                            echo "Priorised                  : $(convert_yes_no ${hostbyipinfopriority})"
                        fi
                        echo "Update available           : $(convert_yes_no ${hostbyipinfoupdateavail})"
                        echo "Update successful          : ${hostbyipinfoupdatesuccessful}"
                        echo "Info URL                   : ${hostbyipinfoinfourl}"
                        echo "URL                        : ${hostbyipinfourl}"
                        if [ ${firmware} -ge 750 ]
                        then
                            echo "Function requested by host : $(convert_yes_no ${hostbyipinforequestclient})"
                        fi
                    else
                        mecho --error "Host with IP ${ip} not found!"
                        exit_code=1
                    fi
                else
                    mecho --error "${ip}"
                    exit_code=1
                fi
            ;;
            wanaccessinfo)
                # Informations about wan access of host given by mac
                if [ -n "${name}" ]
                then
                    mecho --info "WAN Access informations about host ${name} ${device}"
                    ip=$(determine_ip_or_mac_from_name "${name}" "IPAddress")
                fi
                if [ -n "${ip}" ] && ! (echo ${ip} | grep -q "Unable") && ! (echo ${ip} | grep -q "not found")
                then
                    if [ -n "${name}" ]
                    then
                        echo "IP address ${ip} for host ${name} determined."
                    else
                        mecho --info "WAN Access informations about host ${ip} ${device}"
                    fi
                    get_url_and_urn "tr64desc.xml" "x_hostfilter" "X_AVM-DE_HostFilter:1"
                    wanaccessinfo=$(execute_soap_request \
                        "GetWANAccessByIP" \
                        "<NewIPv4Address>${ip}</NewIPv4Address>" \
                        "${type}")
                    if (echo "${wanaccessinfo}" | grep -q "GetWANAccessByIPResponse")
                    then
                        wanaccessinfodisallow=$(parse_xml_response "${wanaccessinfo}" "NewDisallow")
                        wanaccessinfoallow=$(convert_yes_no $((! wanaccessinfodisallow)))
                        wanaccessinfowanaccess=$(parse_xml_response "${wanaccessinfo}" "NewWANAccess")
                        case "${wanaccessinfowanaccess}" in
                            granted)
                                wanaccessinfowanaccess="yes"
                            ;;
                            denied)
                                wanaccessinfowanaccess="no"
                            ;;
                            error)
                                wanaccessinfowanaccess="unknown"
                            ;;
                        esac
                        if [ "${wanaccessinfowanaccess}" = "unknown" ]
                        then
                            wanaccessstatus="WAN access for host ${ip} enabled : unknown"
                        else
                            if [ "${wanaccessinfowanaccess}" = "no" ] || [ "${wanaccessinfoallow}" = "no" ]
                            then
                                wanaccessstatus="WAN access for host ${ip} enabled : no"
                            else
                                wanaccessstatus="WAN access for host ${ip} enabled : yes"
                            fi
                        fi
                        echo "${wanaccessstatus} (Switch: ${wanaccessinfoallow} ; Profile: ${wanaccessinfowanaccess})"
                    else
                        mecho --error "Host with IP ${ip} not found!"
                        exit_code=1
                    fi
                else
                    mecho --error "${ip}"
                    exit_code=1
                fi
            ;;
            wanaccessswitch)
                # Wan access enable/disable switch for host given by ip or name
                if [ -n "${name}" ]
                then
                    mecho --info "Switching WAN access for host ${name} \"${switch}\" ${device}"
                    ip=$(determine_ip_or_mac_from_name "${name}" "IPAddress")
                fi
                if [ -n "${ip}" ] && ! (echo ${ip} | grep -q "Unable") && ! (echo ${ip} | grep -q "not found")
                then
                    if [ -n "${name}" ]
                    then
                        echo "IP address ${ip} for host ${name} determined."
                    else
                        mecho --info "Switching WAN access for host ${ip} ${device}"
                    fi
                    get_url_and_urn "tr64desc.xml" "x_hostfilter" "X_AVM-DE_HostFilter:1"
                    execute_soap_request \
                        "DisallowWANAccessByIP" \
                        "<NewIPv4Address>${ip}</NewIPv4Address> \
                         <NewDisallow>$((! new_enabled))</NewDisallow>" \
                        "${type}" \
                        | grep -q "DisallowWANAccessByIPResponse"
                    exit_code=$?
                    if [ "${exit_code}" != "0" ]
                    then
                        mecho --error "Host with IP ${ip} not found!"
                    fi
                else
                    mecho --error "${ip}"
                    exit_code=1
                fi
            ;;
            autowolinfo)
                # Informations about auto wol configuration of host given by ip, mac or name
                if [ -n "${ip}" ]
                then
                    mecho --info "Auto WOL informations about host ${ip} ${device}"
                    determine_mac_from_ip
                else
                    if [ -n "${name}" ]
                    then
                        mecho --info "Auto WOL informations about host ${name} ${device}"
                        mac=$(determine_ip_or_mac_from_name "${name}" "MACAddress")
                    fi
                fi
                if [ -n "${mac}" ] && ! (echo ${mac} | grep -q "Unable") && ! (echo ${mac} | grep -q "not found")
                then
                    if [ -n "${ip}" ]
                    then
                        echo "MAC address ${mac} for IP ${ip} determined."
                    else
                        if [ -n "${name}" ]
                        then
                            echo "MAC address ${mac} for host ${name} determined."
                        else
                            mecho --info "Auto WOL informations about host ${mac} ${device}"
                        fi
                    fi
                    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                    autowolinfo=$(execute_soap_request \
                        "X_AVM-DE_GetAutoWakeOnLANByMACAddress" \
                        "<NewMACAddress>${mac}</NewMACAddress>" \
                        "${type}")
                    if (echo "${autowolinfo}" | grep -q "X_AVM-DE_GetAutoWakeOnLANByMACAddressResponse")
                    then
                        autowolinfoenable=$(parse_xml_response "${autowolinfo}" "NewAutoWOLEnabled")
                        if [ -n "${ip}" ]
                        then
                            echo "Auto WOL for host ${ip} enabled : $(convert_yes_no ${autowolinfoenable})"
                        else
                            echo "Auto WOL for host ${mac} enabled : $(convert_yes_no ${autowolinfoenable})"
                        fi
                    else
                        mecho --error "Host with MAC ${mac} not found!"
                        exit_code=1
                    fi
                else
                    if [ -n "${mac}" ]
                    then
                        mecho --error "${mac}"
                        exit_code=1
                    fi
                fi
            ;;
            autowolswitch)
                # Auto wol enable/disable switch for host given by ip, mac or name
                if [ -n "${ip}" ]
                then
                    mecho --info "Switching Auto WOL for host ${ip} \"${switch}\" ${device}"
                    determine_mac_from_ip
                else
                    if [ -n "${name}" ]
                    then
                        mecho --info "Switching Auto WOL for host ${name} \"${switch}\" ${device}"
                        mac=$(determine_ip_or_mac_from_name "${name}" "MACAddress")
                    fi
                fi
                if [ -n "${mac}" ] && ! (echo ${mac} | grep -q "Unable") && ! (echo ${mac} | grep -q "not found")
                then
                    if [ -n "${ip}" ]
                    then
                        echo "MAC address ${mac} for IP ${ip} determined."
                    else
                        if [ -n "${name}" ]
                        then
                            echo "MAC address ${mac} for host ${name} determined."
                        else
                            mecho --info "Switching Auto WOL for host ${mac} \"${switch}\" ${device}"
                        fi
                    fi
                    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                    execute_soap_request \
                        "X_AVM-DE_SetAutoWakeOnLANByMACAddress" \
                        "<NewMACAddress>${mac}</NewMACAddress> \
                         <NewAutoWOLEnabled>${new_enabled}</NewAutoWOLEnabled>" \
                        "${type}" \
                        | grep -q "X_AVM-DE_SetAutoWakeOnLANByMACAddressResponse"
                    exit_code=$?
                    if [ "${exit_code}" != "0" ]
                    then
                        mecho --error "Host with MAC ${mac} not found!"
                    fi
                else
                    if [ -n "${mac}" ]
                    then
                        mecho --error "${mac}"
                        exit_code=1
                    fi
                fi
            ;;
            wolclient)
                # Wake on lan client given by ip, mac or name
                if [ -n "${ip}" ]
                then
                    mecho --info "WOL host ${ip} ${device}"
                    determine_mac_from_ip
                else
                    if [ -n "${name}" ]
                    then
                        mecho --info "WOL host ${name} ${device}"
                        mac=$(determine_ip_or_mac_from_name "${name}" "MACAddress")
                    fi
                fi
                if [ -n "${mac}" ] && ! (echo ${mac} | grep -q "Unable") && ! (echo ${mac} | grep -q "not found")
                then
                    if [ -n "${ip}" ]
                    then
                        echo "MAC address ${mac} for IP ${ip} determined."
                    else
                        if [ -n "${name}" ]
                        then
                            echo "MAC address ${mac} for host ${name} determined."
                        else
                            mecho --info "WOL host ${mac} ${device}"
                        fi
                    fi
                    get_url_and_urn "tr64desc.xml" "hosts" "Hosts:1"
                    execute_soap_request \
                        "X_AVM-DE_WakeOnLANByMACAddress" \
                        "<NewMACAddress>${mac}</NewMACAddress>" \
                        "${type}" \
                        | grep -q "X_AVM-DE_WakeOnLANByMACAddressResponse"
                    exit_code=$?
                    if [ "${exit_code}" != "0" ]
                    then
                        mecho --error "Host with MAC ${mac} not found!"
                    fi
                else
                    if [ -n "${mac}" ]
                    then
                        mecho --error "${mac}"
                        exit_code=1
                    fi
                fi
            ;;
            ftpswitch|smbswitch|nasswitch)
                # FTP/SMB/NAS server enable/disable switch
                # On nasswitch command do SMB first
                mecho --info "Switching storage access (ftp, smb or both) \"${switch}\" ${device}"
                if [ "${command}" = "ftpswitch" ]
                then
                    servertype="FTP"
                else
                    servertype="SMB"
                fi
                get_url_and_urn "tr64desc.xml" "x_storage" "X_AVM-DE_Storage:1"
                execute_soap_request \
                    "Set${servertype}Server" \
                    "<New${servertype}Enable>${new_enabled}</New${servertype}Enable>" \
                    "${type}" \
                    | grep -q "Set${servertype}ServerResponse"
                exit_code=$?
                if [ "${command}" = "nasswitch" ] && [ "${exit_code}" = "0" ]
                then
                    execute_soap_request \
                        "SetFTPServer" \
                        "<NewFTPEnable>${new_enabled}</NewFTPEnable>" \
                        "${type}" \
                        | grep -q "SetFTPServerResponse"
                    exit_code=$?
                fi
                # check media server/nas server dependencies
                storageinfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${storageinfo}" | grep -q "GetInfoResponse")
                then
                    get_url_and_urn "tr64desc.xml" "x_upnp" "X_AVM-DE_UPnP:1"
                    upnpmediainfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${upnpmediainfo}" | grep -q "GetInfoResponse")
                    then
                        if ([ "$(parse_xml_response "${storageinfo}" "NewFTPEnable")" -eq 0 ] ||
                            [ "$(parse_xml_response "${storageinfo}" "NewSMBEnable")" -eq 0 ]) &&
                           [ "$(parse_xml_response "${upnpmediainfo}" "NewUPnPMediaServer")" -eq 1 ]
                        then
                            mecho -warn "NAS server is disabled in fritzbox therefore Media server will not work."
                            mecho -warn "Activate NAS server in webgui or use: ${0} nasswitch --active"
                        fi
                    else
                        exit_code=1
                    fi
                else
                    exit_code=1
                fi
            ;;
            ftpwanswitch)
                # FTP wan enable/disable switch
                mecho --info "Switching FTP WAN access \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_storage" "X_AVM-DE_Storage:1"
                if [ -z "${ftpwansslonlyon}" ]
                then
                    storageinfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${storageinfo}" | grep -q "GetInfoResponse")
                    then
                        ftpwansslonlystatus=$(parse_xml_response "${storageinfo}" "NewFTPWANSSLOnly")
                    fi
                else
                    ftpwansslonlystatus="${ftpwansslonlyon}"
                fi
                if [ -n "${ftpwansslonlystatus}" ]
                then
                    # maybe faulty in fritzbox; have to reverse parameters
                    if [ "${FBREVERSEFTPWAN}" = "true" ]
                    then
                        execute_soap_request \
                            "SetFTPServerWAN" \
                            "<NewFTPWANEnable>${ftpwansslonlystatus}</NewFTPWANEnable>
                             <NewFTPWANSSLOnly>${new_enabled}</NewFTPWANSSLOnly>" \
                            "${type}" \
                            | grep -q "SetFTPServerWANResponse"
                    else
                        execute_soap_request \
                            "SetFTPServerWAN" \
                            "<NewFTPWANEnable>${new_enabled}</NewFTPWANEnable>
                             <NewFTPWANSSLOnly>${ftpwansslonlystatus}</NewFTPWANSSLOnly>" \
                            "${type}" \
                            | grep -q "SetFTPServerWANResponse"
                    fi
                    exit_code=$?
                else
                    exit_code=1
                fi
            ;;
            ftpwansslswitch)
                # SSL only on ftp wan enable/disable switch
                mecho --info "Switching FTP WLAN SSL only access \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_storage" "X_AVM-DE_Storage:1"
                if [ -z "${ftpwanon}" ]
                then
                    storageinfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${storageinfo}" | grep -q "GetInfoResponse")
                    then
                        ftpwanstatus=$(parse_xml_response "${storageinfo}" "NewFTPWANEnable")
                    fi
                else
                    ftpwanstatus="${ftpwanon}"
                fi
                if [ -n "${ftpwanstatus}" ]
                then
                    # maybe faulty in fritzbox; have to reverse parameters
                    if [ "${FBREVERSEFTPWAN}" = "true" ]
                    then
                        execute_soap_request \
                            "SetFTPServerWAN" \
                            "<NewFTPWANEnable>${new_enabled}</NewFTPWANEnable>
                             <NewFTPWANSSLOnly>${ftpwanstatus}</NewFTPWANSSLOnly>" \
                            "${type}" \
                            | grep -q "SetFTPServerWANResponse"
                    else
                        execute_soap_request \
                            "SetFTPServerWAN" \
                            "<NewFTPWANEnable>${ftpwanstatus}</NewFTPWANEnable>
                             <NewFTPWANSSLOnly>${new_enabled}</NewFTPWANSSLOnly>" \
                            "${type}" \
                            | grep -q "SetFTPServerWANResponse"
                    fi
                    exit_code=$?
                else
                    exit_code=1
                fi
            ;;
            storageinfo)
                # Informations about storage
                mecho --info "Storage informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_storage" "X_AVM-DE_Storage:1"
                storageinfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${storageinfo}" | grep -q "GetInfoResponse")
                then
                    storageinfoftpenable=$(parse_xml_response "${storageinfo}" "NewFTPEnable")
                    storageinfoftpstatus=$(parse_xml_response "${storageinfo}" "NewFTPStatus")
                    storageinfosmbenable=$(parse_xml_response "${storageinfo}" "NewSMBEnable")
                    storageinfoftpwanenable=$(parse_xml_response "${storageinfo}" "NewFTPWANEnable")
                    storageinfoftpwansslonly=$(parse_xml_response "${storageinfo}" "NewFTPWANSSLOnly")
                    storageinfoftpwanport=$(parse_xml_response "${storageinfo}" "NewFTPWANPort")
                    echo "FTP enabled      : $(convert_yes_no ${storageinfoftpenable})"
                    echo "FTP status       : ${storageinfoftpstatus}"
                    echo "FTP WAN enabled  : $(convert_yes_no ${storageinfoftpwanenable})"
                    echo "FTP WAN SSL only : $(convert_yes_no ${storageinfoftpwansslonly})"
                    echo "FTP WAN port     : ${storageinfoftpwanport}"
                    echo "SMB enabled      : $(convert_yes_no ${storageinfosmbenable})"
                else
                    exit_code=1
                fi
            ;;
            upnpswitch)
                # UPNP status messages enable/disable switch
                mecho --info "Switching UPNP status messages \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_upnp" "X_AVM-DE_UPnP:1"
                if [ -z "${mediaon}" ]
                then
                    upnpmediainfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${upnpmediainfo}" | grep -q "GetInfoResponse")
                    then
                        mediastatus=$(parse_xml_response "${upnpmediainfo}" "NewUPnPMediaServer")
                    fi
                else
                    mediastatus="${mediaon}"
                fi
                if [ -n "${mediastatus}" ]
                then
                    execute_soap_request \
                        "SetConfig" \
                        "<NewEnable>${new_enabled}</NewEnable>
                         <NewUPnPMediaServer>${mediastatus}</NewUPnPMediaServer>" \
                        "${type}" \
                        | grep -q "SetConfigResponse"
                    exit_code=$?
                else
                    exit_code=1
                fi
            ;;
            mediaswitch)
                # Media server enable/disable switch
                mecho --info "Switching upnp media server \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_upnp" "X_AVM-DE_UPnP:1"
                if [ -z "${upnpon}" ]
                then
                    upnpmediainfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${upnpmediainfo}" | grep -q "GetInfoResponse")
                    then
                        upnpstatus=$(parse_xml_response "${upnpmediainfo}" "NewEnable")
                    fi
                else
                    upnpstatus="${upnpon}"
                fi
                if [ -n "${upnpstatus}" ]
                then
                    execute_soap_request \
                        "SetConfig" \
                        "<NewEnable>${upnpstatus}</NewEnable>
                         <NewUPnPMediaServer>${new_enabled}</NewUPnPMediaServer>" \
                        "${type}" \
                        | grep -q "SetConfigResponse"
                    exit_code=$?
                else
                    exit_code=1
                fi
                # check if nas server is enabled
                if [ "${new_enabled}" -eq 1 ] && [ "${exit_code}" -eq 0 ]
                then
                    get_url_and_urn "tr64desc.xml" "x_storage" "X_AVM-DE_Storage:1"
                    storageinfo=$(execute_soap_request \
                        "GetInfo" \
                        "" \
                        "${type}")
                    if (echo "${storageinfo}" | grep -q "GetInfoResponse")
                    then
                        if [ "$(parse_xml_response "${storageinfo}" "NewFTPEnable")" -eq 0 ] ||
                           [ "$(parse_xml_response "${storageinfo}" "NewSMBEnable")" -eq 0 ]
                        then
                            mecho -warn "NAS server is disabled in fritzbox therefore Media server will not work."
                            mecho -warn "Activate NAS server in webgui or use: ${0} nasswitch --active"
                        fi
                    else
                        exit_code=1
                    fi
                fi
            ;;
            upnpmediainfo)
                # Informations about upnp media server storage
                mecho --info "UPnP media server informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_upnp" "X_AVM-DE_UPnP:1"
                upnpmediainfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${upnpmediainfo}" | grep -q "GetInfoResponse")
                then
                    upnpmediainfoenable=$(parse_xml_response "${upnpmediainfo}" "NewEnable")
                    upnpmediainfomediaserver=$(parse_xml_response "${upnpmediainfo}" "NewUPnPMediaServer")
                    echo "UPnP status messages      : $(convert_yes_no ${upnpmediainfoenable})"
                    echo "UPnP Media Server enabled : $(convert_yes_no ${upnpmediainfomediaserver})"
                else
                    exit_code=1
                fi
            ;;
            taminfo)
                # Informations about tam
                mecho --info "Answering machines informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_tam" "X_AVM-DE_TAM:1"
                tamfile=$(execute_soap_request \
                    "GetMessageList" \
                    "<NewIndex>0</NewIndex>" \
                    "${type}")
                tamfile=$(parse_xml_response "${tamfile}" "NewURL")
                if [ -n "${tamfile}" ]
                then
                    tamfile="${tamfile:0:${#tamfile}-1}"
                fi
                idx=0
                while [ true ]
                do
                    taminfo=$(execute_soap_request \
                        "GetInfo" \
                        "<NewIndex>${idx}</NewIndex>" \
                        "${type}")
                    if (echo "${taminfo}" | grep -q "GetInfoResponse")
                    then
                        taminfoenabled=$(parse_xml_response "${taminfo}" "NewEnable")
                        taminfoname=$(parse_xml_response "${taminfo}" "NewName")
                        taminfotamrunning=$(parse_xml_response "${taminfo}" "NewTAMRunning")
                        taminfostick=$(parse_xml_response "${taminfo}" "NewStick")
                        taminfostatus=$(parse_xml_response "${taminfo}" "NewStatus")
                        taminfocapacity=$(parse_xml_response "${taminfo}" "NewCapacity")
                        if (echo "${taminfo}" | grep -q "NewMode")
                        then
                            taminfomode=$(parse_xml_response "${taminfo}" "NewMode")
                            case "${taminfomode}" in
                                record_message)
                                    taminfomode="Record message"
                                ;;
                                play_announcement)
                                    taminfomode="Play message"
                                ;;
                                timeprofile)
                                    taminfomode="Time profile"
                                ;;
                                "")
                                    taminfomode="?"
                                ;;
                            esac
                            taminforingseconds=$(parse_xml_response "${taminfo}" "NewRingSeconds")
                            if [ "${taminforingseconds}" = "" ]
                            then
                                taminforingseconds="?"
                            fi
                            taminfophonenumbers=$(parse_xml_response "${taminfo}" "NewPhoneNumbers")
                            if [ "${taminfophonenumbers}" = "" ]
                            then
                                taminfophonenumbers="all"
                            fi
                        else
                            taminfomode="_not_available"
                        fi
                        if [ "${idx}" -eq 0 ]
                        then
                            echo "Running         : $(convert_yes_no ${taminfotamrunning})"
                            if [ $((taminfostatus & 2)) -eq 0 ]
                            then
                                echo "Capacity        : ${taminfocapacity} minute(s)"
                            else
                                echo "Capacity        : ${taminfocapacity} minute(s); No space left!"
                            fi
                            echo -n "Using USB stick : "
                            case "${taminfostick}" in
                                0|1)
                                    echo "$(convert_yes_no ${taminfostick})"
                                ;;
                                2)
                                    echo  "USB stick available but folder avm_tam missing!"
                                ;;
                            esac
                            if [ "${taminfomode}" = "_not_available" ]
                            then
                                techo --begin "4r 4 36 17r 15r 4r"
                                techo --info --row "Idx" "Act" "Name" "Visible in UI" "Messages total" "new"
                            else
                                techo --begin "4r 4 27 15 5r 10r 11r 4r"
                                techo --info --row "Idx" "Act" "Name" "Mode" "Ring" "Vsb in UI" "Msgs total" "new"
                            fi
                        fi
                        if [ -n "${tamfile}" ]
                        then
                            if (echo ${result} | grep "^http")
                            then
                                tammessagelist=$(wget -q --no-check-certificate -O - "${tamfile}${idx}")
                            else
                                tammessagelist=$(wget -q --no-check-certificate -O - "https://${FBIP}:${FBPORTSSL}${tamfile}${idx}")
                            fi
                            if [ -n "${tammessagelist}" ]
                            then
                                tammessagestotal=$(echo "${tammessagelist}" | grep -o "<Message>" | wc -l)
                                tammessagesnew=$(echo "${tammessagelist}" | grep -o "<New>0</New>" | wc -l)
                            else
                                tammessagestotal="?"
                                tammessagesnew="?"
                            fi
                        else
                            tammessagestotal="?"
                            tammessagesnew="?"
                        fi
                        if [ "${taminfomode}" = "_not_available" ]
                        then
                            techo --row \
                                "${idx}" \
                                "$(convert_yes_no ${taminfoenabled})" \
                                "${taminfoname}" \
                                "$(convert_yes_no $((${taminfostatus} >> 15)))" \
                                "${tammessagestotal}" \
                                "${tammessagesnew}"
                        else
                            techo --row \
                                "${idx}" \
                                "$(convert_yes_no ${taminfoenabled})" \
                                "${taminfoname}" \
                                "${taminfomode}" \
                                "${taminforingseconds} s" \
                                "$(convert_yes_no $((${taminfostatus} >> 15)))" \
                                "${tammessagestotal}" \
                                "${tammessagesnew}"
                            echo "        (Accepted phone numbers: ${taminfophonenumbers})"
                        fi
                        idx=$((idx + 1))
                    else
                        if [ "${idx}" -gt 0 ]
                        then
                            techo --end
                        fi
                        break
                    fi
                done
            ;;
            tamcap)
                # Informations tam capacity
                get_url_and_urn "tr64desc.xml" "x_tam" "X_AVM-DE_TAM:1"
                taminfo=$(execute_soap_request \
                    "GetInfo" \
                    "<NewIndex>0</NewIndex>" \
                    "${type}")
                taminfocapacity=$(parse_xml_response "${taminfo}" "NewCapacity")
                if [ -n "${taminfocapacity}" ]
                then
                    mecho --info "Answering machines capacity ${device}: ${taminfocapacity} minute(s)"
                else
                    mecho --info "Answering machines capacity ${device}: not determined"
                    exit_code=1
                fi
            ;;
            tamswitch)
                # Tam enable/disable switch
                mecho --info "Switching TAM ${tamindex} \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_tam" "X_AVM-DE_TAM:1"
                execute_soap_request \
                    "SetEnable" \
                    "<NewIndex>${tamindex}</NewIndex>
                     <NewEnable>${new_enabled}</NewEnable>" \
                    "${type}" \
                    | grep -q "SetEnableResponse"
                exit_code=$?
            ;;
            alarminfo)
                # Informations about alarm clocks
                mecho --info "Alarm clocks informations ${device}"
                get_url_and_urn "tr64desc.xml" "x_voip" "X_VoIP:1"
                idx=0
                alarmcount=$(execute_soap_request \
                    "X_AVM-DE_GetNumberOfAlarmClocks" \
                    "" \
                    "${type}")
                alarmcount=$(parse_xml_response "${alarmcount}" "NewX_AVM-DE_NumberOfAlarmClocks")
                if [ -n "${alarmcount}" ] && [ "${alarmcount}" -gt 0 ]
                then
                    techo --begin "4r 4 18 6 24 24"
                    techo --info --row "Idx" "Act" "Name" "Time" "Weekdays" "Phone name"
                    while [ "${idx}" -lt "${alarmcount}" ]
                    do
                        alarminfo=$(execute_soap_request \
                            "X_AVM-DE_GetAlarmClock" \
                            "<NewIndex>${idx}</NewIndex>" \
                            "${type}")
                        if (echo "${alarminfo}" | grep -q "X_AVM-DE_GetAlarmClockResponse")
                        then
                            alarminfoenabled=$(parse_xml_response "${alarminfo}" "NewX_AVM-DE_AlarmClockEnable")
                            alarminfoname=$(parse_xml_response "${alarminfo}" "NewX_AVM-DE_AlarmClockName")
                            alarminfotime=$(parse_xml_response "${alarminfo}" "NewX_AVM-DE_AlarmClockTime")
                            alarminfotime=${alarminfotime:0:2}:${alarminfotime:2:2}
                            alarminfoweekdays=$(parse_xml_response "${alarminfo}" "NewX_AVM-DE_AlarmClockWeekdays")
                            if [ -z "${alarminfoweekdays}" ]
                            then
                                alarminfoweekdays="No repetition"
                            fi
                            alarminfophonename=$(parse_xml_response "${alarminfo}" "NewX_AVM-DE_AlarmClockPhoneName")
                            techo --row \
                                "${idx}" \
                                "$(convert_yes_no ${alarminfoenabled})" \
                                "${alarminfoname}" \
                                "${alarminfotime}" \
                                "${alarminfoweekdays}" \
                                "${alarminfophonename}"
                            idx=$((idx + 1))
                        else
                            mecho --error "Invalid alarm clock index found!"
                            mecho --error "Please reboot your Fritzbox to fix the problem."
                            exit_code=1
                            break
                        fi
                    done
                    techo --end
                else
                    [ -z "${alarmcount}" ] && exit_code=1
                fi
            ;;
            alarmswitch)
                # Alarm clock enable/disable switch
                mecho --info "Switching alarm ${alarmindex} \"${switch}\" ${device}"
                get_url_and_urn "tr64desc.xml" "x_voip" "X_VoIP:1"
                execute_soap_request \
                    "X_AVM-DE_SetAlarmClockEnable" \
                    "<NewIndex>${alarmindex}</NewIndex>
                     <NewX_AVM-DE_AlarmClockEnable>${new_enabled}</NewX_AVM-DE_AlarmClockEnable>" \
                    "${type}" \
                    | grep -q "X_AVM-DE_SetAlarmClockEnableResponse"
                exit_code=$?
            ;;
            reconnect)
                # Reconnect to internet
                mecho --info "Reconnecting ${device}"
                get_url_and_urn "${FBCONNTYPEdescfile}" "${FBCONNTYPEcontrolURL}" "${FBCONNTYPEserviceType}"
                execute_soap_request \
                    "ForceTermination" \
                    "" \
                    "${type}" \
                    | grep  -q "DisconnectInProgress"
                exit_code=$?
                sleep 3
                execute_soap_request \
                    "RequestConnection" \
                    "" \
                    "${type}" > /dev/null
            ;;
            reboot)
                # Reboot fritzbox
                mecho --info "Rebooting ${device}"
                get_url_and_urn "tr64desc.xml" "deviceconfig" "DeviceConfig:1"
                execute_soap_request \
                    "Reboot" \
                    "" \
                    "${type}" \
                    | grep  -q "RebootResponse"
                exit_code=$?
            ;;
            savefbconfig)
                # Save configuration of fritzbox
                mecho --info "Saving configuration ${device}"
                # Commented out because this info is read before (see above at "read fritzbox description" part)
                # get_url_and_urn "tr64desc.xml" "deviceinfo" "DeviceInfo:1"
                # deviceinfo=$(execute_soap_request \
                #     "GetInfo" \
                #    "" \
                #    "${type}")
                # if (echo "${deviceinfo}" | grep -q "GetInfoResponse")
                # then
                    deviceinfomodel=$(parse_xml_response "${deviceinfo}" "NewModelName" | tr " " "_")
                    deviceinfoserial=$(parse_xml_response "${deviceinfo}" "NewSerialNumber")
                    deviceinfosoftware=$(parse_xml_response "${deviceinfo}" "NewSoftwareVersion")
                    get_url_and_urn "tr64desc.xml" "deviceconfig" "DeviceConfig:1"
                    conffile=$(execute_soap_request \
                        "X_AVM-DE_GetConfigFile" \
                        "<NewX_AVM-DE_Password>${fbconffilepassword}</NewX_AVM-DE_Password>" \
                        "${type}")
                    conffile=$(parse_xml_response "${conffile}" "NewX_AVM-DE_ConfigFileUrl")
                    if [ -n "${conffile}" ]
                    then
                        if [ -n "${fbconffileprefix}" ]
                        then
                            fbconffileprefix="${fbconffileprefix}_"
                        fi
                        if [ -n "${fbconffilesuffix}" ]
                        then
                            fbconffilesuffix=".${fbconffilesuffix}"
                        fi
                        fbconffile="${fbconffilepath}/${fbconffileprefix}${deviceinfomodel}_${deviceinfoserial}_${deviceinfosoftware}_$(date +'%Y%m%d_%H%M%S')${fbconffilesuffix}"
                        echo "Writing Fritzbox configuration to file:"
                        echo "     ${fbconffile}"
                        if [ "${debugfb:-false}" = "true" ]
                        then
                            wget -v --no-check-certificate -O ${fbconffile} ${conffile} > ${debugfbfile}.wget 2>&1
                            wget_errorcode=$?
                            (
                                echo "------------------------------------------------------------------"
                                echo "Download fritzbox configuration file"
                                echo
                                echo "conffile        : ${conffile}"
                                echo
                                echo "fbconffile      : ${fbconffile}"
                                echo
                                echo "wget error code : ${wget_errorcode}"
                                echo
                                cat ${debugfbfile}.wget
                            ) >> ${debugfbfile}
                            rm -f "${debugfbfile}.wget"
                        else
                            wget -q --no-check-certificate -O ${fbconffile} ${conffile}
                            wget_errorcode=$?
                        fi
                        if [ ${wget_errorcode} -ne 0 ]
                        then
                            exit_code=15
                        fi
                    else
                        exit_code=1
                    fi
                # else
                #     exit_code=1
                # fi
            ;;
            updateinfo)
                # Informations about firmware update available
                mecho --info "Firmware update informations ${device}"
                get_url_and_urn "tr64desc.xml" "userif" "UserInterface:1"
                updateinfo=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}" ; \
                    execute_soap_request \
                    "X_AVM-DE_GetInfo" \
                    "" \
                    "${type}")
                if (echo "${updateinfo}" | grep -q "GetInfoResponse") &&
                   (echo "${updateinfo}" | grep -q "X_AVM-DE_GetInfoResponse")
                then
                    updateinfoavail=$(parse_xml_response "${updateinfo}" "NewUpgradeAvailable")
                    updateinfopasswordreq=$(parse_xml_response "${updateinfo}" "NewPasswordRequired")
                    updateinfopasswordusersel=$(parse_xml_response "${updateinfo}" "NewPasswordUserSelectable")
                    # updateinfowarrantydate=$(parse_xml_response "${updateinfo}" "NewWarrantyDate")
                    updateinfoversion=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_Version")
                    updateinfodownloadurl=$(parse_xml_response "${updateinfo}" "NewX-AVM-DE_DownloadURL")
                    updateinfoinfourl=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_InfoURL")
                    updateinfostate=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_UpdateState")
                    updateinfolaborversion=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_LaborVersion")
                    updateinfobuildtype=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_BuildType")
                    updateinfosetupassistentstatus=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_SetupAssistentStatus")
                    updateinfoautoupdatemode=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_AutoUpdateMode")
                    updateinfoupdatetime=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_UpdateTime")
                    updateinfolastfwversion=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_LastFwVersion")
                    updateinfolastinfourl=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_LastInfoUrl")
                    updateinfocurrentfwversion=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_CurrentFwVersion")
                    updateinfoupdatesuccessful=$(parse_xml_response "${updateinfo}" "NewX_AVM-DE_UpdateSuccessful")
                    echo "Upgrade available : $(convert_yes_no ${updateinfoavail})"
                    echo "Password required : $(convert_yes_no ${updateinfopasswordreq})"
                    echo "User selectable   : $(convert_yes_no ${updateinfopasswordusersel})"
                    # Currently not supported
                    # echo "Warranty date     : ${updateinfowarrantydate}"
                    echo "Version           : ${updateinfoversion}"
                    echo "Download URL      : ${updateinfodownloadurl}"
                    echo "Info URL          : ${updateinfoinfourl}"
                    echo "Update state      : ${updateinfostate}"
                    if [ -n "${updateinfobuildtype}" ]
                    then
                        echo "Build type        : ${updateinfobuildtype}"
                    else
                        echo "Labor version     : ${updateinfolaborversion}"
                    fi
                    echo "Setup Assistent   : $(convert_active_inactive ${updateinfosetupassistentstatus})"
                    echo "Auto update mode  : ${updateinfoautoupdatemode}"
                    echo "Update time       : ${updateinfoupdatetime}"
                    echo "Previous firmware : ${updateinfolastfwversion}"
                    echo "Current firmware  : ${updateinfocurrentfwversion}"
                    # Allways pointing to the current firmware not to the previous installed firmware
                    echo "Firmware info url : ${updateinfolastinfourl}"
                    echo "Update successful : ${updateinfoupdatesuccessful}"
                else
                    exit_code=1
                fi
            ;;
            tr69info)
                # Informations about provider initiated updates via tr69 protocol
                mecho --info "TR-069 management informations ${device}"
                get_url_and_urn "tr64desc.xml" "mgmsrv" "ManagementServer:1"
                tr69info=$(execute_soap_request \
                    "GetInfo" \
                    "" \
                    "${type}")
                if (echo "${tr69info}" | grep -q "GetInfoResponse")
                then
                    tr69infourl=$(parse_xml_response "${tr69info}" "NewURL")
                    tr69infousername=$(parse_xml_response "${tr69info}" "NewUsername")
                    tr69infoperiodicinformenable=$(parse_xml_response "${tr69info}" "NewPeriodicInformEnable")
                    tr69infoperiodicinforminterval=$(parse_xml_response "${tr69info}" "NewPeriodicInformInterval")
                    tr69infoperiodicinformtime=$(parse_xml_response "${tr69info}" "NewPeriodicInformTime")
                    tr69infoparameterkey=$(parse_xml_response "${tr69info}" "NewParameterKey")
                    tr69infoparameterhash=$(parse_xml_response "${tr69info}" "NewParameterHash")
                    tr69infoconnectionrequesturl=$(parse_xml_response "${tr69info}" "NewConnectionRequestURL")
                    tr69infoconnectionrequestusername=$(parse_xml_response "${tr69info}" "NewConnectionRequestUsername")
                    tr69infoupgradesmanaged=$(parse_xml_response "${tr69info}" "NewUpgradesManaged")
                    echo "URL                                  : ${tr69infourl}"
                    echo "User name                            : ${tr69infousername}"
                    echo "Periodic update information          : $(convert_yes_no ${tr69infoperiodicinformenable})"
                    echo "Periodic update information interval : ${tr69infoperiodicinforminterval}"
                    echo "Periodic update information time     : ${tr69infoperiodicinformtime}"
                    echo "Parameter key                        : ${tr69infoparameterkey}"
                    echo "Parameter hash                       : ${tr69infoparameterhash}"
                    echo "Connection request URL               : ${tr69infoconnectionrequesturl}"
                    echo "Connection request user name         : ${tr69infoconnectionrequestusername}"
                    echo "Upgrades managed                     : $(convert_yes_no ${tr69infoupgradesmanaged})"
                else
                    exit_code=1
                fi
            ;;
            deviceinfo)
                # Informations about fritzbox
                mecho --info "Fritzbox informations ${device}"
                # Commented out because this info is read before (see above at "read fritzbox description" part)
                # get_url_and_urn "tr64desc.xml" "deviceinfo" "DeviceInfo:1"
                # deviceinfo=$(execute_soap_request \
                #     "GetInfo" \
                #     "" \
                #     "${type}")
                # if (echo "${deviceinfo}" | grep -q "GetInfoResponse")
                # then
                    deviceinfomanufacturer=$(parse_xml_response "${deviceinfo}" "NewManufacturerName")
                    deviceinfomanufactureroui=$(parse_xml_response "${deviceinfo}" "NewManufacturerOUI")
                    deviceinfodescription=$(parse_xml_response "${deviceinfo}" "NewDescription")
                    deviceinfoproductclass=$(parse_xml_response "${deviceinfo}" "NewProductClass")
                    deviceinfomodel=$(parse_xml_response "${deviceinfo}" "NewModelName")
                    deviceinfoserial=$(parse_xml_response "${deviceinfo}" "NewSerialNumber")
                    deviceinfosoftware=$(parse_xml_response "${deviceinfo}" "NewSoftwareVersion")
                    deviceinfohardware=$(parse_xml_response "${deviceinfo}" "NewHardwareVersion")
                    deviceinfospec=$(parse_xml_response "${deviceinfo}" "NewSpecVersion")
                    deviceinfoprovisioning=$(parse_xml_response "${deviceinfo}" "NewProvisioningCode")
                    deviceinfouptime=$(parse_xml_response "${deviceinfo}" "NewUpTime")
                    deviceinfodevicelog=$(parse_xml_response "${deviceinfo}" "NewDeviceLog" | head -1)
                    deviceinfodevicelog=$(convert_html_entities "${deviceinfodevicelog}")
                    echo "Manufacturer               : ${deviceinfomanufacturer}"
                    echo "Manufacturer OUI           : ${deviceinfomanufactureroui}"
                    echo "Model                      : ${deviceinfomodel}"
                    echo "Description                : ${deviceinfodescription}"
                    echo "Product class              : ${deviceinfoproductclass}"
                    echo "Serial number              : ${deviceinfoserial}"
                    echo "Software version           : ${deviceinfosoftware}"
                    echo "Hardware version           : ${deviceinfohardware}"
                    echo "Spec version               : ${deviceinfospec}"
                    echo "Provisioning code          : ${deviceinfoprovisioning}"
                    echo "Uptime                     : $(convert_seconds_to_time_string ${deviceinfouptime})"
                    if [ -z "${nowrap}" ]
                    then
                        multilineoutput "Device log (last event)    :" \
                                        "                           :" \
                                        "${deviceinfodevicelog}"
                    else
                        echo "Device log (last event)    : ${deviceinfodevicelog}"
                    fi
                    if [ "${FBCONNTYPE:-IP}" = "PPP" ]
                    then
                        echo "Connection to internet via : PPPoE"
                    else
                        echo "Connection to internet via : IP network"
                    fi
                # else
                #     exit_code=1
                # fi
            ;;
            devicelog)
                # Shows log formatted or raw
                if [ -z "${rawdevicelog}" ]
                then
                    mecho --info "Fritzbox log ${device}"
                fi
                get_url_and_urn "tr64desc.xml" "deviceinfo" "DeviceInfo:1"
                devicelog=$(execute_soap_request \
                    "GetDeviceLog" \
                    "" \
                    "${type}")
                if (echo "${devicelog}" | grep -q "GetDeviceLogResponse")
                then
                    devicelog=$(echo "${devicelog}" | sed -E 's/<[/]?NewDeviceLog>//g' | grep -Ev "^[ \t]*<")
                    if [ -z "${rawdevicelog}" ] && [ -z "${nowrap}" ]
                    then
                        while read devicelogline
                        do
                            deviceloglinetimestamp="$(echo ${devicelogline} | cut -d ' ' -f 1-2)"
                            deviceloglineremaining="$(echo ${devicelogline} | cut -d ' ' -f 3-)"
                            multilineoutput "${deviceloglinetimestamp}" \
                                            "" \
                                            "${deviceloglineremaining}"
                        done <<< "${devicelog}"
                    else
                        echo "${devicelog}"
                    fi
                else
                    exit_code=1
                fi
            ;;
            downloadcert|certvalidity)
                if  [ "${command}" = "downloadcert" ]
                then
                    mecho --info "Certificate download ${device}"
                else
                    mecho --info "Validity of certificate ${device}"
                fi
                cert=$(echo "GET / HTTP/1.0" | openssl s_client -showcerts -servername "${FBIP}" -connect "${FBIP}:${FBPORTSSL}" 2>&1 | \
                    sed -n '/-BEGIN/,/-END/p')
                subject=$(echo "${cert}" | openssl x509 -noout -subject 2>/dev/null | tr -d '"')
                subject_hash=$(echo "${cert}" | openssl x509 -noout -subject_hash 2>/dev/null)
                if (echo ${subject} | grep -q "CN *=")
                then
                    anchor="CN"
                else
                    if (echo ${subject} | grep -q "OU *=")
                    then
                        anchor="OU"
                    fi
                fi
                if [ -n "${cert}" ] && [ -n "${subject}" ] && [ -n "${subject_hash}" ] && [ -n "${anchor}" ]
                then
                    startdate=$(echo "${cert}" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//g')
                    enddate=$(echo "${cert}" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//g')
                    if  [ "${command}" = "downloadcert" ]
                    then
                        certname="$(echo "${subject}" | sed -e "s#^subject=.*${anchor} *=##g" \
                            -e 's/\*\.//' -e 's/^ *//' -e 's/ *$//' -e 's#^\(.*\)/.*$#\1#' \
                            -e 's/[^A-Za-z0-9 _.-]//g' -e 's/ /_/g' | tr '[:upper:]' '[:lower:]')"
                        echo "Writing Fritzbox certificate to file:"
                        echo "     ${certpath}/${certname}.pem"
                        echo "${cert}" > ${certpath}/${certname}.pem
                        echo "Validity of certificate:"
                    fi
                    echo "Startdate: ${startdate}"
                    echo "Enddate  : ${enddate}"
                else
                    exit_code=17
                fi
            ;;
            listxmlfiles)
                # List of  all xml files
                mecho --info "Available xml files ${device}"
                for descfile in ${mainxmlfiles}
                do
                    xmlfile=$(curl -s -m 5 "http://${FBIP}:${FBPORT}/${descfile}")
                    if [ -n "${xmlfile}" ]
                    then
                        if ! (echo "${xmlfile}" | grep -q "404 Not Found")
                        then
                            echo "${descfile}"
                            echo "${xmlfile}" | \
                                grep -Eo "<SCPDURL>"'([a-zA-Z0-9/\._]*)'"</SCPDURL>" | \
                                sed -e 's/^<SCPDURL>//' -e 's/<\/SCPDURL>.*$//' | \
                                sort -u | sed 's#/#    #g'
                        else
                            if [ -n "${error_14_pre}" ]
                            then
                                error_14_pre="${error_14_pre}, ${descfile}"
                            else
                                error_14_pre="${descfile}"
                            fi
                        fi
                    else
                        exit_code=1
                    fi
                done
                if [ -n "${error_14_pre}" ]
                then
                    error_14="$(echo ${error_14_pre} | sed -r 's/(.*),(.*)/\1 and\2/g') ${error_14}"
                    exit_code=14
                fi
            ;;
            showxmlfile)
                # Content of single desc file downloaded from fritzbox
                showxmlfile "${descfile}"
            ;;
            createsoapfiles)
                # Create soap files for all TR-064 functions on fritzbox
                mecho --info "Creating SOAP files ${device}"
                createsoapfiles
            ;;
            mysoaprequest)
                # Execute request defined in soap file and/or command line parameters
                # soap file is read in "parse commands" part of this script
                mecho --info "Executed SOAP request ${device}"
                mecho --warn "Function: ${action} (${controlURL} ${serviceType})"
                if [ -n "${controlURL}" ] && [ -n "${serviceType}" ] && [ -n "${action}" ]
                then
                    get_url_and_urn "${descfile:-tr64desc.xml}" "${controlURL}" "${serviceType}"
                    response=$(execute_soap_request \
                        "${action}" \
                        "${data}" \
                        "${type}")
                    if [ -n "${title}" ]
                    then
                        mecho --info "${title} ${device}"
                    fi
                    if [ -n "${search}" ]
                    then
                        if [ "${search}" = "all" ]
                        then
                            echo "${response}" | grep -Po "^[ \t]*<[a-zA-Z0-9_-]*>[^<]*([ \t]*</[a-zA-Z0-9_-]*>)?" | \
                                sed -e "s#[ \t]*</[a-zA-Z0-9_-]*>[ \t]*##g" | \
                                sed -e "s#^[ \t]*##g" | sed "s#<##1" | sed "s#>#|#1"
                        else
                            for s in ${search}
                            do
                                echo ${s}"|"$(parse_xml_response "${response}" "${s}")
                            done
                        fi
                    else
                        echo "${response}"
                    fi
                    echo "${response}" | grep  -q "${action}Response"
                    exit_code=$?
                else
                    mecho --error "Necessary file not given or not existing or not all needed"
                    mecho --error "parameters given on the command line for command \"${command}\"!"
                    exit_with_error 12 showhelp
                fi
            ;;
        esac
    else
        # Fritzbox not available
        exit_code=2
    fi
else
    # Tools missing
    mecho --error "Missing Tools:${missingtools}"
    exit_code=3
fi

if [ "${exit_code}" -gt 0 ] && [ "${exit_code}" -ne 8 ] && [ "${exit_code}" -ne 9 ] && [ "${exit_code}" -ne 10 ]
then
    eval error='$'error_"${exit_code}"
    mecho --error ${error}
fi

if [ -f "${soapauthfile}" ]
then
    rm -f "${soapauthfile}"
fi

output_debugfbfile

exit ${exit_code}
