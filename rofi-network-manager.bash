#!/bin/bash
# Default Values
QRCODE_LOCATION=$LOCATION
QRCODE_DIR="/tmp/"

NOTIFICATIONS="off"

LOCATION=0
Y_AXIS=0
X_AXIS=0

WIDTH_FIX_MAIN=1
WIDTH_FIX_STATUS=10

devices=$(nmcli device)

WIRELESS_INTERFACES=("$(echo "$devices" | awk '$2=="wifi" {print $1}')")
WIRED_INTERFACES=("$(echo "$devices" | awk '$2=="ethernet" {print $1}')")
WIRELESS_INTERFACES_PRODUCT=()
WIRED_INTERFACES_PRODUCT=()

SIGNAL_STRENGTH_0="0"
SIGNAL_STRENGTH_1="1"
SIGNAL_STRENGTH_2="12"
SIGNAL_STRENGTH_3="123"
SIGNAL_STRENGTH_4="1234"

IF_PWD_IS_STORED_MESSAGE="if connection is stored, hit enter/esc."
VPN_PATTERN='(wireguard|vpn)'
CHANGE_BARS=false
ASCII_OUT=false
WLAN_INT=0

log_with_exit_2() {
	printf "\e[0;31m%s\e[0m\n" "$1"
	exit 2
}

init() {
	DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

	if [[ -f "$DIR/rofi-network-manager.conf" ]]; then
		source "$DIR/rofi-network-manager.conf"
	elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.conf" ]]; then
		source "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.conf"
	fi

	if [[ -f "$DIR/rofi-network-manager.rasi" ]]; then
		RASI_DIR="$DIR/rofi-network-manager.rasi"
	elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi" ]]; then
		RASI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi"
	else
		log_with_exit_2 "unable to find rasi configuration file"
	fi

	for i in "${WIRELESS_INTERFACES[@]}"; do
		WIRELESS_INTERFACES_PRODUCT+=("$(nmcli -f general.product device show "$i" | awk '{print $2}')")
	done

	for i in "${WIRED_INTERFACES[@]}"; do
		WIRED_INTERFACES_PRODUCT+=("$(nmcli -f general.product device show "$i" | awk '{print $2}')")
	done

	wireless_interface_state && ethernet_interface_state
}

notify() {
	echo "$2"

	[[ "$NOTIFICATIONS" == "true" && -x "$(command -v notify-send)" ]] && notify-send -r "5" -u "normal" "$1" "$2"
}

wireless_interface_state() {
	if [[ ${#WIRELESS_INTERFACES[@]} -eq "0" ]]; then
		return
	fi

	device_status=$(nmcli device status)

	ACTIVE_SSID=$(echo "$device_status" | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $4}')
	WIFI_CON_STATE=$(echo "$device_status" | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')

	if [[ "$WIFI_CON_STATE" == "unavailable" ]]; then
		WIFI_LIST="***Wi-Fi Disabled***"
		WIFI_SWITCH="~Wi-Fi On"
		OPTIONS="${WIFI_LIST}\n${WIFI_SWITCH}\n~Scan\n"
	else
		if [[ "$WIFI_CON_STATE" =~ "connected" ]]; then
			PROMPT=${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]
			WIFI_LIST=$(nmcli --fields SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}")
			wifi_list

			if [[ "$ACTIVE_SSID" == "--" ]]; then
				WIFI_SWITCH="~Scan\n~Manual/Hidden\n~Wi-Fi Off"
			else
				WIFI_SWITCH="~Scan\n~Disconnect\n~Manual/Hidden\n~Wi-Fi Off"
			fi
			OPTIONS="${WIFI_LIST}\n${WIFI_SWITCH}\n"
		fi
	fi
}

ethernet_interface_state() {
	if [[ ${#WIRED_INTERFACES[@]} -ne "0" ]]; then
		WIRED_CON_STATE=$(nmcli device status | grep "ethernet" | head -1 | awk '{print $3}')
		case "$WIRED_CON_STATE" in
		"disconnected")
			WIRED_SWITCH="~Eth On"
			;;
		"connected")
			WIRED_SWITCH="~Eth Off"
			;;
		"unavailable")
			WIRED_SWITCH="***Wired Unavailable***"
			;;
		"connecting")
			WIRED_SWITCH="***Wired Initializing***"
			;;
		esac
		OPTIONS="${OPTIONS}${WIRED_SWITCH}\n"
	fi
}

rofi_menu() {
	if [[ ${#WIRELESS_INTERFACES[@]} -gt "1" ]]; then
		OPTIONS="${OPTIONS}~Change Wifi Interface\n~More Options"
	else
		OPTIONS="${OPTIONS}~More Options"
	fi

	if [[ "$WIRED_CON_STATE" == "connected" ]]; then
		PROMPT="${WIRELESS_INTERFACES_PRODUCT[0]}[${WIRED_INTERFACES[0]}]"
	else
		PROMPT="${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]"
	fi

	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" $WIDTH_FIX_MAIN "-a 0")
	SSID=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}

rofi_cmd() {
	if [[ -n "${1}" ]]; then
		WIDTH=$(echo -e "$1" | awk '{print length}' | sort -n | tail -1)
		((WIDTH += $2))
		((WIDTH = WIDTH / 2))
	else
		((WIDTH = $2 / 2))
	fi

	rofi -dmenu -i -location "$LOCATION" \
		-yoffset "$Y_AXIS" -xoffset "$X_AXIS" "$3" \
		-theme "$RASI_DIR" -theme-str 'window{width: '"$WIDTH"'em;}textbox-prompt-colon{str:"'"$PROMPT"':";}'"$4"''
}

change_wireless_interface() {
	{ [[ ${#WIRELESS_INTERFACES[@]} -eq "2" ]] && { [[ $WLAN_INT -eq "0" ]] && WLAN_INT=1 || WLAN_INT=0; }; } || {
		LIST_WLAN_INT=""
		for i in "${!WIRELESS_INTERFACES[@]}"; do LIST_WLAN_INT=("${LIST_WLAN_INT[@]}${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]\n"); done
		LIST_WLAN_INT[-1]=${LIST_WLAN_INT[-1]::-2}
		CHANGE_WLAN_INT=$(echo -e "${LIST_WLAN_INT[@]}" | rofi_cmd "${LIST_WLAN_INT[@]}" $WIDTH_FIX_STATUS)
		for i in "${!WIRELESS_INTERFACES[@]}"; do [[ $CHANGE_WLAN_INT == "${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]" ]] && WLAN_INT=$i && break; done
	}
	wireless_interface_state && ethernet_interface_state
	rofi_menu
}

scan() {
	[[ "$WIFI_CON_STATE" =~ "unavailable" ]] && change_wifi_state "Wi-Fi" "Enabling Wi-Fi connection" "on" && sleep 2
	notify "-t 0 Wifi" "Please Wait Scanning"
	WIFI_LIST=$(nmcli --fields SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" --rescan yes)
	wifi_list
	wireless_interface_state && ethernet_interface_state
	notify "-t 1 Wifi" "Please Wait Scanning"
	rofi_menu
}

wifi_list() {
	# Remove duplicate entries, empty entries, and the active SSID
	WIFI_LIST=$(echo -e "$WIFI_LIST" | awk -F'  +' '!seen[$1]++ && $1 != "--" && $1 != "'"${ACTIVE_SSID}"'"')

	if [[ $ASCII_OUT == "true" ]]; then
		# Replace signal strength indicators with ASCII characters
		WIFI_LIST=$(echo -e "$WIFI_LIST" | sed 's/\(..*\)\*\{4,4\}/\1▂▄▆█/g' | sed 's/\(..*\)\*\{3,3\}/\1▂▄▆_/g' | sed 's/\(..*\)\*\{2,2\}/\1▂▄__/g' | sed 's/\(..*\)\*\{1,1\}/\1▂___/g')
	fi

	if [[ $CHANGE_BARS == "true" ]]; then
		# Replace signal strength indicators with custom characters
		WIFI_LIST=$(echo -e "$WIFI_LIST" | sed 's/\(.*\)▂▄▆█/\1'"$SIGNAL_STRENGTH_4"'/' |
			sed 's/\(.*\)▂▄▆_/\1'"$SIGNAL_STRENGTH_3"'/' |
			sed 's/\(.*\)▂▄__/\1'"$SIGNAL_STRENGTH_2"'/' |
			sed 's/\(.*\)▂___/\1'"$SIGNAL_STRENGTH_1"'/' |
			sed 's/\(.*\)____/\1'"$SIGNAL_STRENGTH_0"'/')
	fi
}

change_wifi_state() {
	notify "$1" "$2"
	nmcli radio wifi "$3"
}
change_wired_state() {
	notify "$1" "$2"
	nmcli device "$3" "$4"
}
net_restart() {
	notify "$1" "$2"
	nmcli networking off && sleep 3 && nmcli networking on
}
disconnect() {
	ACTIVE_SSID=$(nmcli -t -f GENERAL.CONNECTION dev show "${WIRELESS_INTERFACES[WLAN_INT]}" | cut -d ':' -f2)
	notify "$1" "You're now disconnected from Wi-Fi network '$ACTIVE_SSID'"
	nmcli con down id "$ACTIVE_SSID"
}
check_wifi_connected() {
	[[ "$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')" == "connected" ]] && disconnect "Connection_Terminated"
}

connect() {
	check_wifi_connected

	notify "-t 0 Wi-Fi" "Connecting to $1"
	# printf "SSID: %s  PWD: %s etc: %s\n" "$1" "$2" "${WIRELESS_INTERFACES[WLAN_INT]}"

	# Error: Connection activation failed: Secrets were required, but not provided.
	if [[ $(nmcli dev wifi connect "$1" password "$2" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") -eq "1" ]]; then
		notify "Connection_Established" "You're now connected to Wi-Fi network '$1'"
	else
		notify "Connection_Error" "Connection cannot be established"
	fi
}

enter_password() {
	PROMPT="Enter_Password" && PASS=$(echo "$IF_PWD_IS_STORED_MESSAGE" | rofi_cmd "$IF_PWD_IS_STORED_MESSAGE" 4 "-password")
}

enter_ssid() {
	PROMPT="Enter_SSID" && SSID=$(rofi_cmd "" 40)
}

stored_connection() {
	check_wifi_connected
	notify "-t 0 Wi-Fi" "Connecting to $1"
	{ [[ $(nmcli dev wifi connect "$1" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") -eq "1" ]] && notify "Connection_Established" "You're now connected to Wi-Fi network '$1'"; } || notify "Connection_Error" "Connection can not be established"
}

ssid_manual() {
	enter_ssid
	[[ -n $SSID ]] && {
		enter_password
		{ [[ -n "$PASS" ]] && [[ "$PASS" != "$IF_PWD_IS_STORED_MESSAGE" ]] && connect "$SSID" "$PASS"; } || stored_connection "$SSID"
	}
}

ssid_hidden() {
	enter_ssid
	[[ -n $SSID ]] && {
		enter_password && check_wifi_connected
		[[ -n "$PASS" ]] && [[ "$PASS" != "$IF_PWD_IS_STORED_MESSAGE" ]] && {
			nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
			nmcli con modify "$SSID" wifi-sec.key-mgmt wpa-psk
			nmcli con modify "$SSID" wifi-sec.psk "$PASS"
		} || [[ $(nmcli -g NAME con show | grep -c "$SSID") -eq "0" ]] && nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
		notify "-t 0 Wifi" "Connecting to $SSID"
		{ [[ $(nmcli con up id "$SSID" | grep -c "successfully activated") -eq "1" ]] && notify "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"; } || notify "Connection_Error" "Connection can not be established"
	}
}

interface_status() {
	local -n INTERFACES=$1
	local -n INTERFACES_PRODUCT=$2
	for i in "${!INTERFACES[@]}"; do
		CON_STATE=$(nmcli device status | grep "^${INTERFACES[$i]}." | awk '{print $3}')
		INT_NAME=${INTERFACES_PRODUCT[$i]}[${INTERFACES[$i]}]

		if [[ "$CON_STATE" == "connected" ]]; then
			GENERAL_CONNECTION=$(nmcli -t -f GENERAL.CONNECTION dev show "${INTERFACES[$i]}" | awk -F '[:]' '{print $2}')
			IP4_ADDRESS=$(nmcli -t -f IP4.ADDRESS dev show "${INTERFACES[$i]}" | awk -F '[:/]' '{print $2}')
			STATUS="$INT_NAME:\n\t$GENERAL_CONNECTION ~ $IP4_ADDRESS"
		else
			STATUS="$INT_NAME: ${CON_STATE^}"
		fi

		echo -e "${STATUS}"
	done
}

status() {
	OPTIONS=""
	if [[ ${#WIRED_INTERFACES[@]} -ne "0" ]]; then
		ETH_STATUS="$(interface_status WIRED_INTERFACES WIRED_INTERFACES_PRODUCT)"
		OPTIONS="${OPTIONS}${ETH_STATUS}"
	fi

	if [[ ${#WIRELESS_INTERFACES[@]} -ne "0" ]]; then
		WLAN_STATUS="$(interface_status WIRELESS_INTERFACES WIRELESS_INTERFACES_PRODUCT)"
		if [[ -n ${OPTIONS} ]]; then
			OPTIONS="${OPTIONS}\n${WLAN_STATUS}"
		else
			OPTIONS="${OPTIONS}${WLAN_STATUS}"
		fi
	fi

	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:'$VPN_PATTERN'/ {sub(/:'$VPN_PATTERN'.*/, ""); print}')
	if [[ -n $ACTIVE_VPN ]]; then
		OPTIONS="${OPTIONS}\n${ACTIVE_VPN}[VPN]: $(nmcli -g ip4.address con show "${ACTIVE_VPN}" | awk -F '[:/]' '{print $1}')"
	fi

	echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" $WIDTH_FIX_STATUS "" "mainbox{children:[listview];}"
}

share_pass() {
	SSID=$(nmcli dev wifi show-password | grep -oP '(?<=SSID: ).*' | head -1)
	PASSWORD=$(nmcli dev wifi show-password | grep -oP '(?<=Password: ).*' | head -1)
	OPTIONS="SSID: ${SSID}\nPassword: ${PASSWORD}"
	if [[ -x "$(command -v qrencode)" ]]; then
		OPTIONS="${OPTIONS}\n~QrCode"
	fi

	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" $WIDTH_FIX_STATUS "-a -1" "mainbox{children:[listview];}")
	selection_action
}

gen_qrcode() {
	DIRECTIONS=("Center" "Northwest" "North" "Northeast" "East" "Southeast" "South" "Southwest" "West")
	TMP_SSID="${SSID// /_}"

	if [[ ! -e $QRCODE_DIR$TMP_SSID.png ]]; then
		qrencode -t png -o $QRCODE_DIR"$TMP_SSID".png -l H -s 25 -m 2 --dpi=192 "WIFI:S:""$SSID"";T:""$(nmcli dev wifi show-password | grep -oP '(?<=Security: ).*' | head -1)"";P:""$PASSWORD"";;"
	fi

	rofi_cmd "" "0" "" "entry{enabled:false;}window{location:""${DIRECTIONS[QRCODE_LOCATION]}"";border-radius:6mm;padding:1mm;width:100mm;height:100mm;
        background-image:url(\"$QRCODE_DIR$TMP_SSID.png\",both);}"
}

manual_hidden() {
	OPTIONS="~Manual\n~Hidden"
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" $WIDTH_FIX_STATUS "" "mainbox{children:[listview];}")
	selection_action
}

vpn() {
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:'$VPN_PATTERN'/ {sub(/:'$VPN_PATTERN'.*/, ""); print}')

	if [[ $ACTIVE_VPN ]]; then
		OPTIONS="~Deactivate $ACTIVE_VPN"
	else
		OPTIONS="$(nmcli -g NAME,TYPE connection | awk '/:'$VPN_PATTERN'/ {sub(/:'$VPN_PATTERN'.*/, ""); print}')"
	fi

	VPN_ACTION=$(echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" "$WIDTH_FIX_STATUS" "" "mainbox {children:[listview];}")

	if [[ -n "$VPN_ACTION" ]]; then
		if [[ "$VPN_ACTION" =~ "~Deactivate" ]]; then
			nmcli connection down "$ACTIVE_VPN"
			notify "VPN_Deactivated" "$ACTIVE_VPN"
		else
			notify "-t 0 Activating_VPN" "$VPN_ACTION"
			VPN_OUTPUT=$(nmcli connection up "$VPN_ACTION" 2>/dev/null)
			if [[ $(echo "$VPN_OUTPUT" | grep -c "Connection successfully activated") -eq "1" ]]; then
				notify "VPN_Successfully_Activated" "$VPN_ACTION"
			else
				notify "Error_Activating_VPN" "Check your configuration for $VPN_ACTION"
			fi
		fi
	fi
}

more_options() {
	OPTIONS=""

	if [[ "$WIFI_CON_STATE" == "connected" ]]; then
		OPTIONS="~Share Wifi Password\n"
	fi

	OPTIONS="${OPTIONS}~Status\n~Restart Network"

	if [[ $(nmcli -g NAME,TYPE connection | awk '/:'$VPN_PATTERN'/ {sub(/:'$VPN_PATTERN'.*/, ""); print}') ]]; then
		OPTIONS="${OPTIONS}\n~VPN"
	fi

	if [[ -x "$(command -v nm-connection-editor)" ]]; then
		OPTIONS="${OPTIONS}\n~Open Connection Editor"
	fi

	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "$OPTIONS" "$WIDTH_FIX_STATUS" "" "mainbox {children:[listview];}")
	selection_action
}

selection_action() {
	case "$SELECTION" in
	"~Disconnect") disconnect "Connection_Terminated" ;;
	"~Scan") scan ;;
	"~Status") status ;;
	"~Share Wifi Password") share_pass ;;
	"~Manual/Hidden") manual_hidden ;;
	"~Manual") ssid_manual ;;
	"~Hidden") ssid_hidden ;;
	"~Wi-Fi On") change_wifi_state "Wi-Fi" "Enabling Wi-Fi connection" "on" ;;
	"~Wi-Fi Off") change_wifi_state "Wi-Fi" "Disabling Wi-Fi connection" "off" ;;
	"~Eth Off") change_wired_state "Ethernet" "Disabling Wired connection" "disconnect" "${WIRED_INTERFACES[0]}" ;;
	"~Eth On") change_wired_state "Ethernet" "Enabling Wired connection" "connect" "${WIRED_INTERFACES[0]}" ;;
	"***Wi-Fi Disabled***") ;;
	"***Wired Unavailable***") ;;
	"***Wired Initializing***") ;;
	"~Change Wifi Interface") change_wireless_interface ;;
	"~Restart Network") net_restart "Network" "Restarting Network" ;;
	"~QrCode") gen_qrcode ;;
	"~More Options") more_options ;;
	"~Open Connection Editor") nm-connection-editor ;;
	"~VPN") vpn ;;
	*)
		if [[ -n "$SELECTION" ]] && [[ "$WIFI_LIST" =~ .*"$SELECTION".* ]]; then
			if [[ "$SSID" == "*" ]]; then
				SSID=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g " | awk -F "|" '{print $3}')
			fi

			set_identifier=""

			if [[ "$SSID" =~ ^[A-Za-z0-9_-]+$ ]]; then
				set_identifier="$SSID"
			else
				BSSID=$(nmcli device wifi list | grep "$SSID" | awk '{print $1}')
				set_identifier="$BSSID"
			fi

			if [[ "$ACTIVE_SSID" == "$SSID" ]]; then
				nmcli con up "$set_identifier" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
			else
				if [[ "$SELECTION" =~ "WPA2" || "$SELECTION" =~ "WEP" ]]; then
					enter_password
				fi

				if [[ -n "$PASS" && "$PASS" != "$IF_PWD_IS_STORED_MESSAGE" ]]; then
					connect "$set_identifier" "$PASS"
				else
					stored_connection "$SSID"
				fi
			fi
		fi
		;;
	esac
}

main() {
	init && rofi_menu
}
main
