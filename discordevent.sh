#!/bin/bash

# LGSM Valheim Server log.  Default username is 'vhserver' and default log location is below.
SERVERLOG="/home/vhserver/log/console/vhserver-console.log"
# Replace with your own discord server webhook
DISCORDWEBHOOK="==YOUR DISCORD WEBHOOK HERE=="
# Make our own logfile for debug and see historic data during development.  Script is pretty verbose and echos to stdout for systemd too because I'm lazy
LOGFILE="/home/vhserver/log/dea.log"

LOGTIME="[$(date +"%Y%b%d %H:%M:%S")]"

declare -A players

# Random events names as defined by Valheim wiki at https://valheim.fandom.com/wiki/Events
declare -A raids
raids[army_eikthyr]="Eikthyr rallies the creatures of the forest against you!"
raids[army_theelder]="The forest is moving with blue eyes gleaming!"
raids[army_bonemass]="A foul smell from the swamp brings the undead to your door!"
raids[army_moder]="A cold wind blows from the mountains as the skies fill with screeching!"
raids[army_goblin]="The Fuling horde is hell bent on destruction!"
raids[foresttrolls]="The ground is shaking as big blue bastards begin breaking shit!"
raids[blobs]="A foul smell from the swamp brings green blobs!"
raids[skeletons]="There's a Skeleton Surprise!  Time to break some bones!"
raids[surtlings]="There's a smell of sulfur in the air as surtlings reign fire!"
raids[wolves]="You are being hunted by wolves!"
raids[bats]="Batting wings, shrieks, and fangs whirl around your home!"
raids[army_gjall]="Gjall reigns his ticks and bile upon your dwelling!"
raids[army_seekers]="They seek those that threaten their Queen!"
raids[hildirboss1]="Brenna seeks her fiery revenge!"
raids[hildirboss2]="Geirrhafa seeks his chilly revenge!"
raids[hildirboss3]="Zil and Thungr seek their brotherly revenge!"

echo "$LOGTIME Starting Valheim Discord Event Log" >> $LOGFILE
init () {
	if [ -e $SERVERLOG ]
	then
		echo "$LOGTIME Found Server Log" >> $LOGFILE
		readlog
	else
		echo "$LOGTIME Server Log NOT Found, Exiting Now" >> $LOGFILE
		return 1
	fi
}

readlog () {
	# Set all initial variables to null
	LAST=""
	LATEST=""
	LASTRAID=""
	LASTDEATH=""
	LASTJOIN=""
	STEAMID=()
	NICK=""
	LASTNICK=""
	while true; do
 		LOGTIME="[$(date +"%Y%b%d %H:%M:%S")]"
		# Get latest information from LGSM Valheim server log and check to see if there are new events
		LATEST=$(tail -n 10 $SERVERLOG)
		if [[ $LATEST != $LAST ]]
		then
			# RegEx to pull a Raid Event line, parse event variable, log time to prevent repeat messages, and send Discord message
			RAIDLINE=$(echo $LATEST | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2}\: Random event set:\w+)')
			RAIDVAR=$(echo $RAIDLINE | grep -oP '(?<=Random event set:)(\w+)')
			RAIDTIME=$(echo $RAIDLINE | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2})')
			if [[ $RAIDVAR != "" ]]
			then
				RAIDVAR=$(echo "${RAIDVAR##*$'\n'}")
				if [[ $LASTRAID != $RAIDTIME ]]; then
					RAIDMSG=${raids[$RAIDVAR]}
					JSON='{"username": "RAID EVENT", "content": "'$RAIDMSG'"}'
					echo "$LOGTIME Found $RAIDVAR and sent ${raids[$RAIDVAR]}" >> $LOGFILE
					echo "Found $RAIDVAR and sent ${raids[$RAIDVAR]} from last raid"
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$JSON" "$DISCORDWEBHOOK"
					LASTRAID=$RAIDTIME
				fi
			fi
			# RegEx to pull a Player Death line, parse player name, log time to prevent repeat messages, and send Discord message
			DEATHLINE=$(echo $LATEST | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2}\:\s)(Got character ZDOID from \S+ : 0:0)')
			DEATHVAR=$(echo $DEATHLINE | grep -oP '(?<=Got character ZDOID from )(\S+)(?= : 0:0)')
			DEATHTIME=$(echo $DEATHLINE | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2})')
			if [[ $DEATHVAR != "" ]]
			then
				DEATHVAR=$(echo "${DEATHVAR##*$'\n'}")
				echo "Death name is $DEATHVAR"
				if [[ $LASTDEATH != $DEATHTIME ]]; then
					LASTDEATH=$DEATHTIME
					DEATHMSG=$DEATHVAR' has met their demise!'
					DEATHJSON='{"username": "DEATH EVENT", "content": "'$DEATHMSG'"}'
					echo "$LOGTIME Found $DEATHVAR and sent $DEATHMSG" >> $LOGFILE
					echo "Found $DEATHVAR and sent $DEATHMSG"
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$DEATHJSON" "$DISCORDWEBHOOK"
					DEATHMSG=""
					DEATHJSON=""
				fi
			fi
			# RegEx to identify a new connection, get SteamID of new player and put into an array to handle multiple connections and player nicks
			NEWCONNECT=$(echo $LATEST | grep -oP '(?<=Got connection SteamID )(\w+)')
			if [[ $NEWCONNECT != "" ]]
			then
				NEWCONNECT=$(echo "${NEWCONNECT##*$'\n'}")
				if [ ${players[$NEWCONNECT]+_} ]; then
					echo "User $NEWCONNECT already exists"
				else
					if [[ $LASTJOIN != $NEWCONNECT ]];then
						LASTJOIN=$NEWCONNECT
						STEAMID+=("$NEWCONNECT")
						echo "$LOGTIME ${STEAMID[-1]}"' new connection!' >> $LOGFILE
						echo "${STEAMID[-1]}"' new connection!'
					fi
				fi
			fi
			# If we have a SteamID in the array, then use RegEx to start looking for a player name.
			# This is assumes first in first out as the server logs don't associate SteamIDs with names for us.
			# Send new player Discord message, add name and SteamID to player array, then unset SteamID in SteamID array
			if [[ ${#STEAMID[@]} != 0 ]]; then
				NICK=$(echo $LATEST | grep -oP '(?<=Got character ZDOID from )(\S+)')
				NICK=$(echo "${NICK##*$'\n'}")
				echo "$LOGTIME $NICK join name found" >> $LOGFILE
				echo "$NICK join name found"
				if [[ $NICK != "" && $LASTNICK != $NICK ]]; then
					LASTNICK=$NICK
					players[${STEAMID[0]}]=$NICK
					echo "$LOGTIME SteamID $STEAMID connected as ${players[${STEAMID[0]}]}" >> $LOGFILE
					echo "SteamID $STEAMID connected as ${players[${STEAMID[0]}]}"
					CONNECTMSG='{"username": "NEW VIKING", "content": "'${players[${STEAMID[0]}]}' has joined."}'
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$CONNECTMSG" "$DISCORDWEBHOOK"
					CONNECTMSG=""
					NICK=""
					STEAMID=("${STEAMID[@]:1}")
					echo "Join array ${STEAMID[@]} after unset"
					echo "$LOGTIME Join array ${STEAMID[@]} after unset" >> $LOGFILE
					LASTJOIN=""
				fi
			fi
			# RegEx to identify player disconnect, send disconnect Discord message, and remove player name and SteamID from player array
			DISCONNECT=$(echo $LATEST | grep -oP '(?<=Closing socket )(\w+)')
			if [[ $DISCONNECT != "" ]]
			then
				DISCONNECT=$(echo "${DISCONNECT##*$'\n'}")
				echo "$LOGTIME SteamID $DISCONNECT ${players[$DISCONNECT]} disconnected" >> $LOGFILE
				echo "SteamID $DISCONNECT ${players[$DISCONNECT]} disconnected"
				if [ ${players[$DISCONNECT]+_} ]; then
					DISCONNECTMSG='{"username": "TIL VALHALLA", "content": "'${players[$DISCONNECT]}' has disconnected."}'
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$DISCONNECTMSG" "$DISCORDWEBHOOK"
					if [[ $LASTNICK == ${players[$DISCONNECT]} ]]; then
						echo "LASTNICK still holds disconnecting player $LASTNICK, reset to null"
						echo "$LOGTIME LASTNICK still holds disconnecting player $LASTNICK, reset to null" >> $LOGFILE
						LASTNICK=""
					fi
					unset players[$DISCONNECT]
					DISCONNECTMSG=""
				else
					echo "$DISCONNECT not found"
					echo "$LOGTIME $DISCONNECT not found" >> $LOGFILE
				fi
			fi
			# Reset all event variables to null so we can test again, then sleep for 1 second
			RAIDVAR=""
			DEATHVAR=""
			NEWCONNECT=""
			DISCONNECT=""
			LAST=$LATEST
		fi
		sleep 1
	done
}

init
