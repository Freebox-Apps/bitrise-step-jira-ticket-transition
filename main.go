package main

import (
	"encoding/json"
	"os"
	"strings"
)

const (
	TransitionListEnv  = "TRANSITION_LIST"
	TicketListEnv      = "TICKET_LIST"
	TicketDelimiterEnv = "TICKET_DELIMITER"
)

func getTransitionList() map[string][]string {
	in := []byte(os.Getenv(TransitionListEnv))
	var transitionList map[string][]string
	json.Unmarshal(in, &transitionList)
	return transitionList
}

func getTicketIds() []string {
	return strings.Split(os.Getenv(TicketListEnv), os.Getenv(TicketDelimiterEnv))
}

func main() {
	ticketIds := getTicketIds()
	ticketTransitions := getTransitionList()
	moveTickets(ticketIds, ticketTransitions)
}
