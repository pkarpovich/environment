package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func buildConfig() config {
	return config{
		Global: global{ShowInMenuBar: false},
		Profiles: []profile{
			{
				Name:     "Default",
				Selected: true,
				ComplexModifications: complexModifications{
					Rules: []rule{
						doubleCommandQ(),
						languageSwitch(),
						f5ToF13(),
						escapeSleepFix(),
						mediaAppsSubLayer(),
					},
				},
			},
		},
	}
}

func run() error {
	data, err := json.MarshalIndent(buildConfig(), "", "  ")
	if err != nil {
		return fmt.Errorf("marshal config: %w", err)
	}
	if err := os.MkdirAll("output", 0o755); err != nil {
		return fmt.Errorf("create output dir: %w", err)
	}
	out := filepath.Join("output", "karabiner.json")
	if err := os.WriteFile(out, data, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", out, err)
	}
	fmt.Printf("Generated Karabiner rules in %s\n", out)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
