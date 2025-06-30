#!/bin/bash
set -e

REQUEST_RESPONSE="/tmp/jira_transition_response.json"

# --- Split lists into arrays ---
IFS=$TICKET_DELIMITER read -ra TRANSITIONS <<< "$TRANSITION_LIST"
IFS=$TICKET_DELIMITER read -ra TICKETS <<< "$TICKET_LIST"

# --- Loop over tickets ---
for ISSUE_KEY in "${TICKETS[@]}"; do

  LAST_TRANSITION=""
  # Loop over requested transitions
  for TRANSITION in "${TRANSITIONS[@]}"; do

    # Fetch available transitions for this ticket
    AVAILABLE_TRANSITIONS=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Accept: application/json" \
      "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY/transitions")


    # Find transition id: either by name or directly if it's a numeric id
    TRANSITION_ID=$(echo "$AVAILABLE_TRANSITIONS" | jq -r --arg TRANS "$TRANSITION" '.transitions[] | select((.name==$TRANS) or (.id==$TRANS)) | .id' | head -n 1)

    if [ -z "$TRANSITION_ID" ]; then
      echo "|  X Failed to move ticket $ISSUE_KEY to '$TRANSITION'. Transition not found. Skipping ticket."
      break
    fi


    # Apply the transition
    APPLY_RESPONSE=$(curl -s -w "%{http_code}" -o $REQUEST_RESPONSE \
      -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST \
      "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY/transitions" \
      -d "{\"transition\": { \"id\": \"$TRANSITION_ID\" }}")

    if [ "$APPLY_RESPONSE" == "204" ]; then
	   LAST_TRANSITION="$TRANSITION"
    else
      echo "|  X Failed to move ticket $ISSUE_KEY to '$TRANSITION' (HTTP code: $APPLY_RESPONSE). Skipping ticket."
      cat $REQUEST_RESPONSE
      echo
      echo
      break
    fi
  done

  if [ -n "$LAST_TRANSITION" ]; then
    echo "| ✓ Moved ticket $ISSUE_KEY to $LAST_TRANSITION"
  fi
done

# Cleanup
rm -f $REQUEST_RESPONSE
