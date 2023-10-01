<h4 align="center">
  <br>
  <a href="https://github.com/benwhite1987/bash-valheim-discord-bot">
  <picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://i.imgur.com/4rSNfSC.png">
  <img alt="bash-valheim-discord-bot" src="https://i.imgur.com/4rSNfSC.png">
	</picture>
</a>
  <br>
  <br>
</h4>

# Valheim Discord Notifier in Bash
Simple Bash script that reads Valheim server logs to send Discord messages on Raids, Deaths, Joins, and Disconnects.  Written by a hobbyist with zero professional programming training or experience, so use as-is and feel free to make improvements.

## Benefits
+ Only requires Bash and a vanilla Valheim server installation.  Nicer solutions exist, but most require Python, Bepinex on the server (which consistently breaks with updates), or other frameworks.
+ Run on a vanilla Linux installation (Ubuntu recommended) running a [Linux Gaming Server Managers (LGSM) Valheim server](https://linuxgsm.com/servers/vhserver/).
+ Point it at the server log, put in your Discord Web Hook link, and it just works.
+ Create a systemd service to make the script persistent and enable on boot

## Usage
+ Install LGSM Valheim server.  Default user is `vhserver`.
+ Place the script in the LGSM Valheim server user home folder. Default is `/home/vhserver`
+ Ensure script is executable and has sufficient permission to read server logs.  
+ Replace `SERVERLOG=` with the path to your server log.
+ Replace `DISCORDWEBHOOK=` with the hyperlink to your Discord channel's webhook.
+ Start script with `./discordevent.sh`.  For persistence, create a systemd service and enable it to start on boot.  See this [systemd service guide](https://linuxhandbook.com/create-systemd-services/) for more details.
