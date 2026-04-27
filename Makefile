.PHONY: build test fixtures

build:
	cabal build

test:
	cabal test --test-show-details=streaming

# Regenerate JSON fixtures via grievous-mcp (pip install grievous-mcp).
# Requires ANTHROPIC_API_KEY to be set in the environment.
fixtures:
	python3 test/fixtures/generate.py
