package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"testing"
)

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
		name      string
		fromKey   string
		fromFn    string
		device    string
		onPress   bool
		heldAsKey string
	}{
		{name: "built-in globe", fromFn: "keyboard_fn", onPress: true},
		{name: "external ctrl", fromKey: "left_control", device: "device_unless", heldAsKey: "left_control"},
		{name: "corne shift", fromKey: "left_shift", device: "device_if", heldAsKey: "left_shift"},
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
		for _, c := range m.Conditions {
			if c.Type == "input_source_if" || c.Type == "input_source_unless" {
				t.Errorf("%s: moji decides the direction, Karabiner must not condition on the input source, got %+v", w.name, c)
			}
		}
		for _, to := range append(append([]to{}, m.To...), m.ToIfAlone...) {
			if to.SelectInputSource != nil {
				t.Errorf("%s: Karabiner must not select the input source itself, got %+v", w.name, to)
			}
		}
		if w.onPress {
			if len(m.To) != 1 || m.To[0].KeyCode != signalKey {
				t.Errorf("%s: a dedicated key emits %s on press, got to=%+v", w.name, signalKey, m.To)
			}
			if m.To[0].Repeat == nil || *m.To[0].Repeat {
				t.Errorf("%s: a held globe must not autorepeat %s, or every repeat toggles the layout again", w.name, signalKey)
			}
			if len(m.ToIfAlone) != 0 {
				t.Errorf("%s: a dedicated key has nothing to do on release, got to_if_alone=%+v", w.name, m.ToIfAlone)
			}
			continue
		}
		if len(m.To) != 1 || m.To[0].KeyCode != w.heldAsKey {
			t.Errorf("%s: a real modifier stays itself while held, got to=%+v", w.name, m.To)
		}
		if len(m.ToIfAlone) != 1 || m.ToIfAlone[0].KeyCode != signalKey {
			t.Errorf("%s: a tap on a real modifier emits %s on release, got to_if_alone=%+v", w.name, signalKey, m.ToIfAlone)
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

	if shifts != 1 {
		t.Fatalf("expected 1 shift manipulator, got %d", shifts)
	}
}

func TestDeviceConditionSerializesIdentifiersAsArray(t *testing.T) {
	r := languageSwitch()

	m := r.Manipulators[1]
	if m.From.KeyCode != "left_control" {
		t.Fatalf("manipulator 1: expected left_control from, got %+v", m.From)
	}
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatalf("marshal manipulator 1: %v", err)
	}
	if bytes.Contains(out, []byte(`"identifiers":{`)) {
		t.Errorf("manipulator 1: identifiers must be a JSON array, not an object (Karabiner rejects the object form), got %s", out)
	}
	if !bytes.Contains(out, []byte(`"identifiers":[{"is_built_in_keyboard":true}]`)) {
		t.Errorf("manipulator 1: expected device_unless identifiers array, got %s", out)
	}

	if len(r.Manipulators[0].Conditions) != 0 {
		t.Errorf("built-in globe manipulator must carry no condition, got %+v", r.Manipulators[0].Conditions)
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

func TestMediaSubLayerKeyOrder(t *testing.T) {
	want := []string{"s", "d", "a"}
	r := mediaSubLayer()

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

	r := subLayer("right_option", "Media Commands Sublayer", entries)

	if r.Description != "Media Commands Sublayer" {
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
