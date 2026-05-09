#!/bin/bash

################################################################################
# LGSM Valheim Server Event Logger - Refactored
# Monitors server log and sends Discord notifications for events
################################################################################

# Configuration
SERVERLOG="/home/vhserver/log/console/vhserver-console.log"
DISCORDWEBHOOK="==YOUR DISCORD WEBHOOK HERE=="
LOGFILE="/home/vhserver/log/dea.log"

# State tracking
declare -A players
declare -A raid_last_time
declare -A death_last_time
last_processed_line=0

################################################################################
# Event Definitions
# See: https://valheim.fandom.com/wiki/Events for detailed information
################################################################################

declare -A raids=(
	[army_eikthyr]=":deer::boar: Eikthyr rallies the creatures of the forest against you! :boar::deer:"
	[army_theelder]=":evergreen_tree::wood: The forest is moving with blue eyes gleaming! :wood::evergreen_tree:"
	[army_bonemass]=":pirate_flag: A foul smell from the swamp brings the undead to your door! :pirate_flag:"
	[army_moder]=":cloud_snow: A cold wind blows from the mountains as the skies fill with screeching! :snowflake:"
	[army_goblin]=":smiling_imp: The Fuling horde is hell bent on destruction! :smiling_imp:"
	[army_gjall]=":beetle::fire: Gjall reigns his ticks and bile upon your dwelling! :fire::beetle:"
	[army_seekers]=":fly: They seek those that threaten their Queen! :fly:"
	[army_charred]=":skull::hot_face: The undead army of ash marches. :hot_face::skull"
	[army_charredspawners]=":skull::hot_face: The ashen undead have been summoned! :hot_face::skull"
	[foresttrolls]=":troll: The ground is shaking as big blue bastards begin breaking shit! :troll:"
	[blobs]=":microbe: A foul smell from the swamp brings green blobs! :microbe:"
	[ghosts]=":ghost: You feel a chill down your spine... :ghost:"
	[skeletons]=":skull_crossbones: There's a Skeleton Surprise!  Time to break some bones! :skull_crossbones:"
	[surtlings]=":fire: There's a smell of sulfur in the air as surtlings reign fire! :fire:"
	[wolves]=":wolf: You are being hunted by wolves! :wolf:"
	[bats]=":bat: Batting wings, shrieks, and fangs whirl around your home! :bat:"
	[hildirboss1]=":fire::skull_crossbones: Brenna seeks her fiery revenge! :skull_crossbones::fire:"
	[hildirboss2]=":cold_face: Geirrhafa seeks his chilly revenge! :cold_face:"
	[hildirboss3]=":imp::mage: Zil and Thungr seek their brotherly revenge! :mage::imp:"
)

################################################################################
# Utility Functions
################################################################################

log_script() {
	local timestamp="[$(date +"%Y%b%d %H:%M:%S")]"
	echo "$timestamp $*" | tee -a "$LOGFILE"
}

log_file_only() {
	local timestamp="[$(date +"%Y%b%d %H:%M:%S")]"
	echo "$timestamp $*" >> "$LOGFILE"
}

send_discord() {
	local username="$1"
	local message="$2"
	local json="{\"username\": \"$username\", \"content\": \"$message\"}"
	
	if curl --connect-timeout 10 -sSL -H "Content-Type: application/json" \
		-X POST -d "$json" "$DISCORDWEBHOOK" 2>/dev/null; then
		log_file_only "Discord sent: $username - $message"
	else
		log_script "ERROR: Failed to send Discord message: $message"
	fi
}

################################################################################
# Event Processing Functions
################################################################################

process_raid_events() {
	local latest="$1"
	
	# Extract raid information using original regex
	local raid_line
	raid_line=$(echo "$latest" | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2}\: Random event set:\w+)')
	
	if [[ -z "$raid_line" ]]; then
		return
	fi
	
	local raid_var raid_time
	raid_var=$(echo "$raid_line" | grep -oP '(?<=Random event set:)(\w+)')
	raid_time=$(echo "$raid_line" | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2})')
	
	# Prevent duplicate messages within same second
	if [[ -z "${raid_last_time[$raid_var]}" ]] || [[ "${raid_last_time[$raid_var]}" != "$raid_time" ]]; then
		local raid_msg="${raids[$raid_var]}"
		if [[ -n "$raid_msg" ]]; then
			send_discord "RAID EVENT" ":crossed_swords: RAID: $raid_msg"
			raid_last_time[$raid_var]="$raid_time"
			log_script "Raid detected: $raid_var"
		fi
	fi
}

process_death_events() {
	local latest="$1"
	
	# Extract death information using original regex
	local death_line
	death_line=$(echo "$latest" | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2}\:\s)(Got character ZDOID from )(.+?(?=:))(: 0:0)')
	
	if [[ -z "$death_line" ]]; then
		return
	fi
	
	local death_var death_time
	death_var=$(echo "$death_line" | grep -oP '(?<=Got character ZDOID from )(.+?(?=\s: 0:0))')
	death_time=$(echo "$death_line" | grep -oP '(\d{2}\/\d{2}\/\d{4}\s\d{2}\:\d{2}\:\d{2})')
	
	if [[ -n "$death_var" ]]; then
		# Prevent duplicate messages within same second
		if [[ -z "${death_last_time[$death_var]}" ]] || [[ "${death_last_time[$death_var]}" != "$death_time" ]]; then
			local death_msg=":headstone::skull_crossbones: $death_var has met their demise!"
			send_discord "DEATH EVENT" "$death_msg"
			death_last_time[$death_var]="$death_time"
			log_script "Death detected: $death_var"
		fi
	fi
}

process_join_events() {
	local latest="$1"
	
	# Extract connection information using original regex
	local new_connect
	new_connect=$(echo "$latest" | grep -oP '(?<=Got character ZDOID from )(.+?(?=:)): (\S+(?=:))')
	
	if [[ -z "$new_connect" ]]; then
		return
	fi
	
	local new_name playfab_id
	new_name=$(echo "$new_connect" | grep -oP '.+?(?= :)')
	playfab_id=$(echo "$new_connect" | grep -oP '(?<=: )(\S+)')
	
	# Check if player already tracked
	if [[ -z "${players[$playfab_id]}" ]]; then
		players[$playfab_id]="$new_name"
		send_discord "NEW VIKING" ":crossed_swords: $new_name has joined."
		log_script "Join detected: $new_name ($playfab_id)"
	else
		log_file_only "Player already tracked: $playfab_id -> $new_name"
	fi
}

process_disconnect_events() {
	local latest="$1"
	
	# Extract disconnect information using original regex
	local disconnect
	disconnect=$(echo "$latest" | grep -oP '(?<=Destroying abandoned non persistent zdo ).+?(?=:)')
	
	if [[ -z "$disconnect" ]]; then
		return
	fi
	
	# Get last match only
	disconnect=$(echo "${disconnect##*$'\n'}")
	
	if [[ -n "${players[$disconnect]}" ]]; then
		local player_name="${players[$disconnect]}"
		send_discord "TIL VALHALLA" ":shield: $player_name has disconnected."
		unset "players[$disconnect]"
		log_script "Disconnect detected: $player_name ($disconnect)"
	else
		log_file_only "Disconnect warning: $disconnect not found in player array"
	fi
}

################################################################################
# Main Processing
################################################################################

process_log_changes() {
	local latest
	latest=$(tail -n 50 "$SERVERLOG")  # Increased from 10 to 50 lines for better event coverage
	
	# Use wc -l to detect actual changes (more reliable than string comparison)
	local current_lines
	current_lines=$(wc -l < "$SERVERLOG")
	
	if [[ $current_lines -le $last_processed_line ]]; then
		return
	fi
	
	log_file_only "Processing log lines from $last_processed_line to $current_lines"
	
	# Process all event types
	process_raid_events "$latest"
	process_death_events "$latest"
	process_join_events "$latest"
	process_disconnect_events "$latest"
	
	last_processed_line=$current_lines
}

main() {
	log_script "Starting Valheim Discord Event Log"
	
	if [[ ! -e "$SERVERLOG" ]]; then
		log_script "ERROR: Server log not found at $SERVERLOG - exiting"
		exit 1
	fi
	
	log_script "Found server log at $SERVERLOG"
	last_processed_line=$(wc -l < "$SERVERLOG")
	
	# Main event loop
	while true; do
		process_log_changes
		sleep 1
	done
}

################################################################################
# Execution
################################################################################

main "$@"
