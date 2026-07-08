package main

import (
	"encoding/json"
	"testing"
)

func TestAppShellCommand(t *testing.T) {
	cmd := app("Finder")

	if len(cmd.to) != 1 {
		t.Fatalf("expected 1 to entry, got %d", len(cmd.to))
	}
	want := `open -a "Finder" && sleep 0.1 && osascript -e 'tell application "System Events" to set frontmost of process "Finder" to true'`
	if cmd.to[0].ShellCommand != want {
		t.Errorf("shell_command mismatch:\n got %q\nwant %q", cmd.to[0].ShellCommand, want)
	}
	if cmd.description != "Open and focus Finder" {
		t.Errorf("description mismatch: got %q", cmd.description)
	}
}

func TestKeyCodeIsBareKeyCode(t *testing.T) {
	cmd := keyCode("play_or_pause")

	if len(cmd.to) != 1 {
		t.Fatalf("expected 1 to entry, got %d", len(cmd.to))
	}
	out, err := json.Marshal(cmd.to[0])
	if err != nil {
		t.Fatalf("marshal to: %v", err)
	}
	if string(out) != `{"key_code":"play_or_pause"}` {
		t.Errorf("expected bare key_code with no modifiers, got %s", out)
	}
}

func TestSubLayerPreservesEntryOrder(t *testing.T) {
	order := []string{"s", "d", "a", "t", "g", "w", "b", "z", "l", "m", "h", "n", "f", "c", "4"}
	entries := make([]layerEntry, len(order))
	for i, k := range order {
		entries[i] = layerEntry{key: k, cmd: keyCode("f13")}
	}

	r := subLayer("right_option", "Media Commands Sublayer + Apps", entries)

	if r.Description != "Media Commands Sublayer + Apps" {
		t.Errorf("description mismatch: got %q", r.Description)
	}
	if len(r.Manipulators) != len(order) {
		t.Fatalf("expected %d manipulators, got %d", len(order), len(r.Manipulators))
	}
	for i, m := range r.Manipulators {
		if m.From.KeyCode != order[i] {
			t.Errorf("manipulator %d: expected key_code %q, got %q", i, order[i], m.From.KeyCode)
		}
		if m.Type != "basic" {
			t.Errorf("manipulator %d: expected type basic, got %q", i, m.Type)
		}
		if m.From.Modifiers == nil || len(m.From.Modifiers.Mandatory) != 1 || m.From.Modifiers.Mandatory[0] != "right_option" {
			t.Errorf("manipulator %d: expected mandatory [right_option], got %+v", i, m.From.Modifiers)
		}
	}
}
