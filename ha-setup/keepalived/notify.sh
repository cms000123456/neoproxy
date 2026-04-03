#!/bin/bash
# Keepalived notification script
# Called on state transitions

TYPE=$1
HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="/var/log/keepalived-notify.log"

# Optional: Send notifications (Slack, email, etc.)
# SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# EMAIL="admin@yourdomain.com"

case $TYPE in
    master)
        echo "[$DATE] $HOST became MASTER" >> $LOGFILE
        # Send alert - this controller is now active
        # curl -X POST -H 'Content-type: application/json' \
        #   --data "{\"text\":\"🟢 NeoProxy HA: $HOST is now MASTER\"}" \
        #   $SLACK_WEBHOOK
        
        # Optional: Ensure services are running
        # docker compose -f /opt/neoproxy/docker-compose.ha.yml up -d
        ;;
    
    backup)
        echo "[$DATE] $HOST became BACKUP" >> $LOGFILE
        # This controller is now standby
        # curl -X POST -H 'Content-type: application/json' \
        #   --data "{\"text\":\"⚪ NeoProxy HA: $HOST is now BACKUP\"}" \
        #   $SLACK_WEBHOOK
        ;;
    
    fault)
        echo "[$DATE] $HOST entered FAULT state" >> $LOGFILE
        # Something is wrong - check health
        # curl -X POST -H 'Content-type: application/json' \
        #   --data "{\"text\":\"🔴 NeoProxy HA: $HOST entered FAULT state\"}" \
        #   $SLACK_WEBHOOK
        ;;
    
    stop)
        echo "[$DATE] $HOST stopped keepalived" >> $LOGFILE
        ;;
    
    *)
        echo "[$DATE] $HOST unknown state: $TYPE" >> $LOGFILE
        ;;
esac

# Log to syslog as well
logger -t keepalived "NeoProxy HA state change on $HOST: $TYPE"
