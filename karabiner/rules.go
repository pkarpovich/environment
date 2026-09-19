package main

type layerCmd struct {
	to []to
}

type layerEntry struct {
	key string
	cmd layerCmd
}

func keyCode(code string) layerCmd {
	return layerCmd{to: []to{{KeyCode: code}}}
}

func subLayer(modifier, description string, entries []layerEntry) rule {
	manipulators := make([]manipulator, len(entries))
	for i, e := range entries {
		manipulators[i] = manipulator{
			Type: "basic",
			From: from{
				KeyCode:   e.key,
				Modifiers: &modifiers{Mandatory: []string{modifier}},
			},
			To: e.cmd.to,
		}
	}
	return rule{Description: description, Manipulators: manipulators}
}

func intPtr(v int) *int { return &v }

func doubleCommandQ() rule {
	commandQ := from{KeyCode: "q", Modifiers: &modifiers{Mandatory: []string{"command"}}}
	reset := []to{{SetVariable: &setVariable{Name: "command-q", Value: 0}}}
	return rule{
		Description: "Double Command+Q to quit",
		Manipulators: []manipulator{
			{
				Type:       "basic",
				From:       commandQ,
				To:         []to{{KeyCode: "q", Modifiers: []string{"left_command"}}},
				Conditions: []condition{{Type: "variable_if", Name: "command-q", Value: intPtr(1)}},
			},
			{
				Type: "basic",
				From: commandQ,
				To:   []to{{SetVariable: &setVariable{Name: "command-q", Value: 1}}},
				ToDelayedAction: &delayedAction{
					ToIfInvoked:  reset,
					ToIfCanceled: reset,
				},
			},
		},
	}
}

// moji owns the layout: Karabiner only decides tap versus hold per device and emits f19 on a
// tap, which moji swallows, switching the layout and holding the keys typed behind the switch.
const signalKey = "f19"

const (
	corneVendorID  = 18003
	corneProductID = 4
)

// shift is held constantly while typing, so only a deliberate short tap may switch the layout
const shiftTapTimeout = 180

type langVariant struct {
	from   from
	to     []to
	device *condition
	params *parameters
}

func (v langVariant) manipulator() manipulator {
	var conditions []condition
	if v.device != nil {
		conditions = append(conditions, *v.device)
	}
	return manipulator{
		Type:       "basic",
		From:       v.from,
		Conditions: conditions,
		ToIfAlone:  []to{{KeyCode: signalKey}},
		To:         v.to,
		Parameters: v.params,
	}
}

func languageSwitch() rule {
	noRepeat := false
	globe := manipulator{
		Type: "basic",
		From: from{AppleVendorTopCaseKeyCode: "keyboard_fn"},
		To:   []to{{KeyCode: signalKey, Repeat: &noRepeat}},
	}
	variants := []langVariant{
		{
			from:   from{KeyCode: "left_control"},
			to:     []to{{KeyCode: "left_control"}},
			device: &condition{Type: "device_unless", Identifiers: []identifiers{{IsBuiltInKeyboard: true}}},
		},
		{
			from:   from{KeyCode: "left_shift"},
			to:     []to{{KeyCode: "left_shift"}},
			device: &condition{Type: "device_if", Identifiers: []identifiers{{VendorID: corneVendorID, ProductID: corneProductID}}},
			params: &parameters{ToIfAloneTimeout: shiftTapTimeout},
		},
	}
	manipulators := []manipulator{globe}
	for _, v := range variants {
		manipulators = append(manipulators, v.manipulator())
	}
	return rule{Description: "Switch the keyboard layout through moji", Manipulators: manipulators}
}

func hyperKey() rule {
	return rule{
		Description: "Caps Lock is Hyper",
		Manipulators: []manipulator{
			{
				Type: "basic",
				From: from{KeyCode: "caps_lock", Modifiers: &modifiers{Optional: []string{"any"}}},
				To:   []to{{KeyCode: "left_shift", Modifiers: []string{"left_command", "left_option", "left_control"}}},
			},
		},
	}
}

func f5ToF13() rule {
	return rule{
		Description: "F5 -> F13",
		Manipulators: []manipulator{
			{
				Type: "basic",
				From: from{KeyCode: "f5", Modifiers: &modifiers{Optional: []string{"any"}}},
				To:   []to{{KeyCode: "f13"}},
			},
		},
	}
}

func f6ToF18() rule {
	return rule{
		Description: "F6 -> F18",
		Manipulators: []manipulator{
			{
				Type: "basic",
				From: from{KeyCode: "f6", Modifiers: &modifiers{Optional: []string{"any"}}},
				To:   []to{{KeyCode: "f18"}},
			},
		},
	}
}

func escapeSleepFix() rule {
	return rule{
		Description: "Temporary Fix for sleep issue",
		Manipulators: []manipulator{
			{
				Type:      "basic",
				From:      from{KeyCode: "escape"},
				ToIfAlone: []to{{KeyCode: "escape"}},
			},
		},
	}
}

func mediaSubLayer() rule {
	return subLayer("right_option", "Media Commands Sublayer", []layerEntry{
		{key: "s", cmd: keyCode("play_or_pause")},
		{key: "d", cmd: keyCode("fastforward")},
		{key: "a", cmd: keyCode("rewind")},
	})
}
