package tests_main_test

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"reflect"
	"testing"
)

func TestHomePage(t *testing.T) {
	resp, err := http.Get("http://localhost:8080/")
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected HTTP 200, got %d", resp.StatusCode)
	}

	body, _ := ioutil.ReadAll(resp.Body)
	expectedBody := "Welcome to the Web API!"
	if string(body) != expectedBody {
		t.Errorf("Expected body: %s, got: %s", expectedBody, string(body))
	}
}

func TestAboutMe(t *testing.T) {
	resp, err := http.Get("http://localhost:8080/aboutme")
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected HTTP 200, got %d", resp.StatusCode)
	}

	body, _ := ioutil.ReadAll(resp.Body)
	expectedBody := "A little bit about me..."
	if string(body) != expectedBody {
		t.Errorf("Expected body: %s, got: %s", expectedBody, string(body))
	}
}

func TestWhoAmI(t *testing.T) {
	resp, err := http.Get("http://localhost:8080/whoami")
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected HTTP 200, got %d", resp.StatusCode)
	}

	body, _ := ioutil.ReadAll(resp.Body)

	var actual []map[string]string
	expected := []map[string]string{
		{
			"Name":  "Group 6",
			"Title": "Team for DevOps and Continous Deployment",
			"State": "FR",
		},
	}

	if err := json.Unmarshal(body, &actual); err != nil {
		t.Fatalf("Failed to unmarshal JSON: %v", err)
	}

	if !reflect.DeepEqual(actual, expected) {
		t.Errorf("Expected JSON: %v, got: %v", expected, actual)
	}
}
