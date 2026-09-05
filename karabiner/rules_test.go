package main

import (
	"bytes"
	"encoding/json"
	"fmt"
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
	want := []struct {
		name    string
		fromKey string
		fromFn  string
		device  string
	}{
		{name: "built-in fn en->ru", fromFn: "keyboard_fn"},
		{name: "built-in fn ru->en", fromFn: "keyboard_fn"},
		{name: "external ctrl en->ru", fromKey: "left_control", device: "device_unless"},
		{name: "external ctrl ru->en", fromKey: "left_control", device: "device_unless"},
		{name: "corne shift en->ru", fromKey: "left_shift", device: "device_if"},
		{name: "corne shift ru->en", fromKey: "left_shift", device: "device_if"},
	}

	r := languageSwitch()
	if len(r.Manipulators) != len(want) {
		t.Fatalf("expected %d manipulators, got %d", len(want), len(r.Manipulators))
	}

	deviceCondition := func(m manipulator) string {
		for _, c := range m.Conditions {
			if c.Type == "device_if" || c.Type == "device_unless" {
				return c.Type
			}
		}
		return ""
	}

	for i, w := range want {
		m := r.Manipulators[i]
		if m.From.KeyCode != w.fromKey {
			t.Errorf("%s: expected key_code %q, got %q", w.name, w.fromKey, m.From.KeyCode)
		}
		if m.From.AppleVendorTopCaseKeyCode != w.fromFn {
			t.Errorf("%s: expected apple_vendor_top_case_key_code %q, got %q", w.name, w.fromFn, m.From.AppleVendorTopCaseKeyCode)
		}
		if got := deviceCondition(m); got != w.device {
			t.Errorf("%s: expected device condition %q, got %q", w.name, w.device, got)
		}
	}
}

func TestShiftLanguageSwitchIsScopedAndTimeBoxed(t *testing.T) {
	r := languageSwitch()

	var shifts int
	for _, m := range r.Manipulators {
		if m.From.KeyCode != "left_shift" {
			continue
		}
		shifts++

		if m.Parameters == nil || m.Parameters.ToIfAloneTimeout != shiftTapTimeout {
			t.Errorf("shift variant must cap to_if_alone at %dms, otherwise a held-then-released shift switches the layout; got %+v", shiftTapTimeout, m.Parameters)
		}
		out, err := json.Marshal(m)
		if err != nil {
			t.Fatalf("marshal shift manipulator: %v", err)
		}
		want := fmt.Sprintf(`"identifiers":[{"vendor_id":%d,"product_id":%d}]`, corneVendorID, corneProductID)
		if !bytes.Contains(out, []byte(want)) {
			t.Errorf("shift variant must stay scoped to the Corne, got %s", out)
		}
	}

	if shifts != 2 {
		t.Fatalf("expected 2 shift manipulators, got %d", shifts)
	}
}

func TestDeviceConditionSerializesIdentifiersAsArray(t *testing.T) {
	r := languageSwitch()

	var deviceConds int
	for _, i := range []int{2, 3} {
		m := r.Manipulators[i]
		if m.From.KeyCode != "left_control" {
			t.Fatalf("manipulator %d: expected left_control from, got %+v", i, m.From)
		}
		out, err := json.Marshal(m)
		if err != nil {
			t.Fatalf("marshal manipulator %d: %v", i, err)
		}
		if bytes.Contains(out, []byte(`"identifiers":{`)) {
			t.Errorf("manipulator %d: identifiers must be a JSON array, not an object (Karabiner rejects the object form), got %s", i, out)
		}
		if !bytes.Contains(out, []byte(`"identifiers":[{"is_built_in_keyboard":true}]`)) {
			t.Errorf("manipulator %d: expected device_unless identifiers array, got %s", i, out)
		}
		deviceConds++
	}
	if deviceConds != 2 {
		t.Fatalf("expected 2 external ctrl manipulators, got %d", deviceConds)
	}

	for _, i := range []int{0, 1} {
		if len(r.Manipulators[i].Conditions) != 1 {
			t.Errorf("built-in fn manipulator %d must only have the input_source_if condition, got %+v", i, r.Manipulators[i].Conditions)
		}
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
