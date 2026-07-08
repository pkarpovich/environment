package main

import (
	"bytes"
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

func TestLanguageSwitchManipulators(t *testing.T) {
	r := languageSwitch()

	if len(r.Manipulators) != 4 {
		t.Fatalf("expected 4 manipulators, got %d", len(r.Manipulators))
	}

	hasDeviceUnless := func(m manipulator) bool {
		for _, c := range m.Conditions {
			if c.Type == "device_unless" {
				return true
			}
		}
		return false
	}

	for i, m := range r.Manipulators {
		builtIn := i < 2
		if builtIn && hasDeviceUnless(m) {
			t.Errorf("built-in manipulator %d must not carry a device_unless condition", i)
		}
		if !builtIn && !hasDeviceUnless(m) {
			t.Errorf("external manipulator %d must carry a device_unless condition", i)
		}
	}

	if r.Manipulators[0].From.AppleVendorTopCaseKeyCode != "keyboard_fn" {
		t.Errorf("built-in variant should key off keyboard_fn, got %+v", r.Manipulators[0].From)
	}
	if r.Manipulators[2].From.KeyCode != "left_control" {
		t.Errorf("external variant should key off left_control, got %+v", r.Manipulators[2].From)
	}
}

func TestDoubleCommandQResetEmitsValueZero(t *testing.T) {
	r := doubleCommandQ()

	if len(r.Manipulators) != 2 {
		t.Fatalf("expected 2 manipulators, got %d", len(r.Manipulators))
	}

	reset := r.Manipulators[1].ToDelayedAction
	if reset == nil {
		t.Fatal("expected a to_delayed_action on the reset manipulator")
	}
	out, err := json.Marshal(reset)
	if err != nil {
		t.Fatalf("marshal delayed action: %v", err)
	}
	if !bytes.Contains(out, []byte(`"value":0`)) {
		t.Errorf(`expected "value":0 to survive in the reset, got %s`, out)
	}
}

func TestMediaAppsSubLayerKeyOrder(t *testing.T) {
	want := []string{"s", "d", "a", "t", "g", "w", "b", "z", "l", "m", "h", "n", "f", "c", "4"}
	r := mediaAppsSubLayer()

	if len(r.Manipulators) != len(want) {
		t.Fatalf("expected %d manipulators, got %d", len(want), len(r.Manipulators))
	}
	for i, m := range r.Manipulators {
		if m.From.KeyCode != want[i] {
			t.Errorf("manipulator %d: expected key_code %q, got %q", i, want[i], m.From.KeyCode)
		}
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
