#!/bin/bash
set -e
# make pipelines' return status equal the last command to exit with a non-zero status, or zero if all commands exit successfully
set -o pipefail

# --- Split lists into arrays ---
IFS=$TICKET_DELIMITER read -ra TICKETS <<< "$TICKET_LIST"

# --- Loop over tickets ---
for ISSUE_KEY in "${TICKETS[@]}"; do

  ISSUE_TYPE_ID=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
  -H "Accept: application/json" \
  "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY" \
  | jq -r '.fields.issuetype.id')

  # Parse transition payload
  TRANSITIONS=()
  while IFS= read -r line; do
    TRANSITIONS+=("$line")
  done < <(echo "$TRANSITION_LIST" | jq -r --arg ISSUE_TYPE_ID "$ISSUE_TYPE_ID" '.[$ISSUE_TYPE_ID][]?')

  LAST_TRANSITION=""
  # Loop over requested transitions
  for TRANSITION in "${TRANSITIONS[@]}"; do

    # Fetch available transitions for this ticket
    AVAILABLE_TRANSITIONS=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Accept: application/json" \
      "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY/transitions")

    # Find transition id: either by name or directly if it's a numeric id
    TRANSITION_LINE=$(echo "$AVAILABLE_TRANSITIONS" | jq -r --arg TRANS "$TRANSITION" '
      .transitions[]
      | select((.name == $TRANS) or (.id == $TRANS))
      | "\(.id) \(.name)"
    ' | head -n 1 || true)

    read -r TRANSITION_ID TRANSITION_NAME <<< "$TRANSITION_LINE"

    if [ -z "$TRANSITION_ID" ]; then
      continue
    fi

    # Apply the transition
    APPLY_RESPONSE=$(curl -s -w "%{http_code}" \
      -u "$JIRA_USER:$JIRA_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST \
      "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY/transitions" \
      -d "{\"transition\": { \"id\": \"$TRANSITION_ID\" }}")

    if [ "$APPLY_RESPONSE" == "204" ]; then
      LAST_TRANSITION="$TRANSITION_NAME"
    fi
  done

  if [ -n "$LAST_TRANSITION" ]; then
    echo "| ✓ Moved ticket $ISSUE_KEY to $LAST_TRANSITION"
  else
    echo "|  X Failed to move ticket $ISSUE_KEY"
  fi
done