package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"

	jira "github.com/andygrunwald/go-jira"
)

const (
	JiraDomainEnv = "JIRA_DOMAIN"
	JiraTokenEnv  = "JIRA_TOKEN"
	JiraUserEnv   = "JIRA_USER"
)

func getJiraAccessToken() string {
	return os.Getenv(JiraTokenEnv)
}

func getJiraUser() string {
	return os.Getenv(JiraUserEnv)
}

func getJiraBaseUrl() string {
	return "https://" + os.Getenv(JiraDomainEnv)
}

type JiraTicket struct {
	key    string
	typeId string
}

type BulkIssuesBody struct {
	Fields    []string `json:"fields"`
	TicketIds []string `json:"issueIdsOrKeys"`
}

func getJiraClient() *jira.Client {

	tp := jira.BasicAuthTransport{
		Username: getJiraUser(),
		Password: getJiraAccessToken(),
	}

	jiraClient, err := jira.NewClient(tp.Client(), getJiraBaseUrl())
	if err != nil {
		panic(err)
	}
	return jiraClient
}

func getJiraTicketsByType(ticketIds []string) map[string][]string {
	fmt.Println("\n# get jira tickets")

	body := BulkIssuesBody{[]string{"issuetype", "summary"}, ticketIds}

	out, _ := json.Marshal(body)
	fmt.Println("--> " + string(out))

	jiraClient := getJiraClient()
	req, _ := jiraClient.NewRequest("POST", "rest/api/3/issue/bulkfetch", body)

	issues := new(jira.IssuesInSprintResult)
	_, err := jiraClient.Do(req, issues)
	if err != nil {
		panic(err)
	}

	out, _ = json.Marshal(issues)
	fmt.Println("<-- " + string(out))

	tickets := make(map[string][]string)

	for _, issue := range issues.Issues {
		tickets[issue.Fields.Type.ID] = append(tickets[issue.Fields.Type.ID], issue.Key)
	}

	return tickets
}

func moveTickets(ticketIds []string, ticketTransitions map[string][]string) {
	tickets := getJiraTicketsByType(ticketIds)

	if len(tickets) > 0 {
		fmt.Println("\n# move jira tickets")

		for ticketType, tickets := range tickets {
			transitionId := ticketTransitions[ticketType][0]
			moveTicketsById(tickets, transitionId)
		}
	}
}

func moveTicketsById(ticketIds []string, transitionId string) {
	jiraClient := getJiraClient()
	for _, ticket := range ticketIds {
		fmt.Println("--> " + ticket + " [" + transitionId + "]")

		response, err := jiraClient.Issue.DoTransition(ticket, transitionId)

		buf := new(bytes.Buffer)
		buf.ReadFrom(response.Body)
		if err != nil {
			fmt.Println("<-- [!] " + err.Error())
		} else {
			fmt.Println("<-- OK")
		}
	}
}

type BulkTransitionInput struct {
	TicketIds    []string `json:"selectedIssueIdsOrKeys"`
	TransitionId string   `json:"transitionId"`
}

type BulkTransitionBody struct {
	Inputs []BulkTransitionInput `json:"bulkTransitionInputs"`
}

// need jira global bulk edit permission ...
func bulkMoveTicketsById(ticketIds []string, transitionId string) {
	if len(ticketIds) > 0 {
		body := BulkTransitionBody{Inputs: []BulkTransitionInput{}}
		body.Inputs = append(body.Inputs, BulkTransitionInput{ticketIds, transitionId})

		out, _ := json.Marshal(body)
		fmt.Println("--> " + string(out))

		jiraClient := getJiraClient()
		req, _ := jiraClient.NewRequest("POST", "rest/api/3/bulk/issues/transition", body)

		response, err := jiraClient.Do(req, nil)

		buf := new(bytes.Buffer)
		buf.ReadFrom(response.Body)
		resBody := buf.String()
		fmt.Println("<-- " + string(resBody))

		if err != nil {
			panic(err)
		}
	}
}
