package main

type config struct {
	Global   global    `json:"global"`
	Profiles []profile `json:"profiles"`
}

type global struct {
	ShowInMenuBar bool `json:"show_in_menu_bar"`
}

type profile struct {
	Name                 string               `json:"name"`
	Selected             bool                 `json:"selected"`
	ComplexModifications complexModifications `json:"complex_modifications"`
}

type complexModifications struct {
	Rules []rule `json:"rules"`
}

type rule struct {
	Description  string        `json:"description,omitempty"`
	Manipulators []manipulator `json:"manipulators"`
}

type manipulator struct {
	Type            string         `json:"type"`
	Description     string         `json:"description,omitempty"`
	From            from           `json:"from"`
	To              []to           `json:"to,omitempty"`
	ToIfAlone       []to           `json:"to_if_alone,omitempty"`
	ToDelayedAction *delayedAction `json:"to_delayed_action,omitempty"`
	Conditions      []condition    `json:"conditions,omitempty"`
}

type from struct {
	KeyCode                   string     `json:"key_code,omitempty"`
	AppleVendorTopCaseKeyCode string     `json:"apple_vendor_top_case_key_code,omitempty"`
	Modifiers                 *modifiers `json:"modifiers,omitempty"`
}

type modifiers struct {
	Mandatory []string `json:"mandatory,omitempty"`
	Optional  []string `json:"optional,omitempty"`
}

type to struct {
	KeyCode           string       `json:"key_code,omitempty"`
	Modifiers         []string     `json:"modifiers,omitempty"`
	ShellCommand      string       `json:"shell_command,omitempty"`
	SetVariable       *setVariable `json:"set_variable,omitempty"`
	SelectInputSource *inputSource `json:"select_input_source,omitempty"`
}

type delayedAction struct {
	ToIfInvoked  []to `json:"to_if_invoked,omitempty"`
	ToIfCanceled []to `json:"to_if_canceled,omitempty"`
}

type setVariable struct {
	Name  string `json:"name"`
	Value int    `json:"value"`
}

type condition struct {
	Type         string        `json:"type"`
	Name         string        `json:"name,omitempty"`
	Value        *int          `json:"value,omitempty"`
	InputSources []inputSource `json:"input_sources,omitempty"`
	Identifiers  *identifiers  `json:"identifiers,omitempty"`
}

type inputSource struct {
	InputSourceID string `json:"input_source_id,omitempty"`
}

type identifiers struct {
	IsBuiltInKeyboard bool `json:"is_built_in_keyboard,omitempty"`
}
