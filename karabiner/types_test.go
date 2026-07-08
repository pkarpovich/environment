package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestSetVariableValueZeroSurvives(t *testing.T) {
	out, err := json.Marshal(setVariable{Name: "command-q", Value: 0})
	if err != nil {
		t.Fatalf("marshal set_variable: %v", err)
	}
	if !strings.Contains(string(out), `"value":0`) {
		t.Errorf("expected zero value to survive, got %s", out)
	}
}

func TestConditionValueOmittedWhenNil(t *testing.T) {
	out, err := json.Marshal(condition{
		Type:         "input_source_if",
		InputSources: []inputSource{{InputSourceID: "en"}},
	})
	if err != nil {
		t.Fatalf("marshal condition: %v", err)
	}
	if strings.Contains(string(out), `"value"`) {
		t.Errorf("expected no value key for input_source_if, got %s", out)
	}
}

func TestConditionValueEmittedWhenSet(t *testing.T) {
	zero := 0
	out, err := json.Marshal(condition{Type: "variable_if", Name: "command-q", Value: &zero})
	if err != nil {
		t.Fatalf("marshal condition: %v", err)
	}
	if !strings.Contains(string(out), `"value":0`) {
		t.Errorf("expected value 0 to be emitted for variable_if, got %s", out)
	}
}
