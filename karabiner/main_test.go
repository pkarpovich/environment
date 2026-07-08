package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"testing"
)

var update = flag.Bool("update", false, "regenerate the golden file")

const goldenPath = "testdata/karabiner.golden.json"

func TestBuildConfigMatchesGolden(t *testing.T) {
	got, err := json.MarshalIndent(buildConfig(), "", "  ")
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}

	if *update {
		if err := os.MkdirAll(filepath.Dir(goldenPath), 0o755); err != nil {
			t.Fatalf("create testdata dir: %v", err)
		}
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("write golden: %v", err)
		}
	}

	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run `go test -update` to create it): %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("buildConfig output does not match %s; run `go test -update` after verifying the diff", goldenPath)
	}
}
