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

func TestRunWritesGoldenToDist(t *testing.T) {
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(wd); err != nil {
			t.Errorf("restore cwd: %v", err)
		}
	})
	if err := os.Chdir(t.TempDir()); err != nil {
		t.Fatalf("chdir: %v", err)
	}

	if err := run(); err != nil {
		t.Fatalf("run: %v", err)
	}

	got, err := os.ReadFile(filepath.Join("dist", "karabiner.json"))
	if err != nil {
		t.Fatalf("read generated config: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("run() wrote output that does not match %s", goldenPath)
	}
}
