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
raids[army_eikthyr]=":deer::boar: Eikthyr rallies the creatures of the forest against you! :boar::deer:"
raids[army_theelder]=":evergreen_tree::wood: The forest is moving with blue eyes gleaming! :wood::evergreen_tree:"
raids[army_bonemass]=":pirate_flag: A foul smell from the swamp brings the undead to your door! :pirate_flag:"
raids[army_moder]=":cloud_snow: A cold wind blows from the mountains as the skies fill with screeching! :snowflake:"
raids[army_goblin]=":smiling_imp: The Fuling horde is hell bent on destruction! :smiling_imp:"
raids[army_gjall]=":beetle::fire: Gjall reigns his ticks and bile upon your dwelling! :fire::beetle:"
raids[army_seekers]=":fly: They seek those that threaten their Queen! :fly:"
raids[army_charred]=":skull::hot_face: The undead army of ash marches. :hot_face::skull"
raids[army_charredspawners]=":skull::hot_face: The ashen undead have been summoned! :hot_face::skull"
raids[foresttrolls]=":troll: The ground is shaking as big blue bastards begin breaking shit! :troll:"
raids[blobs]=":microbe: A foul smell from the swamp brings green blobs! :microbe:"
raids[ghosts]=":ghost: You feel a chill down your spine... :ghost:"
raids[skeletons]=":skull_crossbones: There's a Skeleton Surprise!  Time to break some bones! :skull_crossbones:"
raids[surtlings]=":fire: There's a smell of sulfur in the air as surtlings reign fire! :fire:"
raids[wolves]=":wolf: You are being hunted by wolves! :wolf:"
raids[bats]=":bat: Batting wings, shrieks, and fangs whirl around your home! :bat:"
raids[hildirboss1]=":fire::skull_crossbones: Brenna seeks her fiery revenge! :skull_crossbones::fire:"
raids[hildirboss2]=":cold_face: Geirrhafa seeks his chilly revenge! :cold_face:"
raids[hildirboss3]=":imp::mage: Zil and Thungr seek their brotherly revenge! :mage::imp:"

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
					JSON='{"username": "RAID EVENT", "content": ":crossed_swords: RAID: '$RAIDMSG'"}'
					echo "$LOGTIME Found $RAIDVAR and sent ${raids[$RAIDVAR]}" >> $LOGFILE
					echo "Found $RAIDVAR and sent ${raids[$RAIDVAR]} from last raid"
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$JSON" "$DISCORDWEBHOOK"
					LASTRAID=$RAIDTIME
				fi
			fi
			# RegEx to pull a Player Death line, parse player name, log time to prevent repeat messages, and send Discord message
			DEATHLINE=$(echo $LATEST | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2}\:\s)(Got character ZDOID from )(.+?(?=:))(: 0:0)')
			DEATHVAR=$(echo $DEATHLINE | grep -oP '(?<=Got character ZDOID from )(.+?(?= : 0:0))')
			DEATHTIME=$(echo $DEATHLINE | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2})')
			if [[ $DEATHVAR != "" ]]
			then
				DEATHVAR=$(echo "${DEATHVAR##*$'\n'}")
				echo "Death name is $DEATHVAR"
				if [[ $LASTDEATH != $DEATHTIME ]]; then
					LASTDEATH=$DEATHTIME
					DEATHMSG=':headstone::skull_crossbones: '$DEATHVAR' has met their demise!'
					DEATHJSON='{"username": "DEATH EVENT", "content": "'$DEATHMSG'"}'
					echo "$LOGTIME Found $DEATHVAR and sent $DEATHMSG" >> $LOGFILE
					echo "Found $DEATHVAR and sent $DEATHMSG"
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$DEATHJSON" "$DISCORDWEBHOOK"
					DEATHMSG=""
					DEATHJSON=""
				fi
			fi
			# RegEx to identify a new connection, get PlayFabID of new player and put into an array to handle multiple connections and player nicks
			NEWCONNECT=$(echo $LATEST | grep -oP '(?<=Got character ZDOID from )(.+?(?=:)): (\S+(?=:))')
			if [[ $NEWCONNECT != "" ]];
			then
				NEWNAME=$(echo $NEWCONNECT | grep -oP '.+?(?= :)')
				PLAYFABID=$(echo $NEWCONNECT | grep -oP '(?<=: )(\S+)')
				if [ ${players[$PLAYFABID]+_} ]; then
					echo "User $PLAYFABID already exists"
				else
					players[${PLAYFABID}]=$NEWNAME
					CONNECTMSG='{"username": "NEW VIKING", "content": ":crossed_swords: '${players[${PLAYFABID}]}' has joined."}'
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$CONNECTMSG" "$DISCORDWEBHOOK"
					CONNECTMSG=""
					PLAYFABID=""
					NEWNAME=""
				fi
			fi
			# RegEx to identify player disconnect, send disconnect Discord message, and remove player name and PlayFabID from player array
			DISCONNECT=$(echo $LATEST | grep -oP '(?<=Destroying abandoned non persistent zdo ).+?(?=:)')
			if [[ $DISCONNECT != "" ]]
			then
				DISCONNECT=$(echo "${DISCONNECT##*$'\n'}")
				echo "$LOGTIME PlayFabID $DISCONNECT ${players[$DISCONNECT]} disconnected" >> $LOGFILE
				echo "PlayFabID $DISCONNECT ${players[$DISCONNECT]} disconnected"
				if [ ${players[$DISCONNECT]+_} ]; then
					DISCONNECTMSG='{"username": "TIL VALHALLA", "content": ":shield: '${players[$DISCONNECT]}' has disconnected."}'
					curl --connect-timeout 10 -sSL -H "Content-Type: application/json" -X POST -d "$DISCONNECTMSG" "$DISCORDWEBHOOK"
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
