# gRPC Patch Comparison Guide

This guide explains how to use the automated comparison system to demonstrate the gRPC BoringSSL P-384/P-521 bug and its fix.

## Overview

The comparison system automates the process of:
1. Testing unpatched gRPC (demonstrating the bug)
2. Building patched gRPC with the elliptic curve fix
3. Testing patched gRPC (proving the fix works)
4. Generating a comprehensive before/after comparison report

## Quick Start

### 1. Build and Run the Docker Container

```bash
# Build the test environment
docker build -t grpc-curve-test .

# Run interactively
docker run -it grpc-curve-test
```

### 2. Run the Comparison (Inside Container)

```bash
# Compare Python (fastest, ~25 minute build)
./compare-grpc-versions.sh --language python

# Or compare all affected languages (~1+ hour build)
./compare-grpc-versions.sh --language all
```

### 3. View the Results

```bash
# View the comparison report
cat reports/comparison-*.md

# View detailed logs
ls -la results/baseline/
ls -la results/patched/
```

## Expected Output

### Console Output

```
╔════════════════════════════════════════════════════════════╗
║        gRPC Elliptic Curve Patch Comparison Tool          ║
╚════════════════════════════════════════════════════════════╝

Configuration:
  Language(s): python
  Quick mode: false
  Output: reports/comparison-20251202-120000.md

[1/5] Running baseline tests (unpatched gRPC)...
Testing python (baseline)...
✓ Baseline tests complete

[2/5] Building patched gRPC...
Building patched Python gRPC (this takes ~20-30 minutes)...
✓ Build complete

[3/5] Running patched tests...
Activating patched python environment...
✓ Activated patched Python gRPC
Testing python (patched)...
✓ Patched tests complete

[4/5] Generating comparison report...
✓ Comparison report generated: reports/comparison-20251202-120000.md

[5/5] Comparison complete!

╔════════════════════════════════════════════════════════════╗
║                      Summary                               ║
╚════════════════════════════════════════════════════════════╝

✓ Baseline results: results/baseline/
✓ Patched results: results/patched/
✓ Comparison report: reports/comparison-20251202-120000.md

Key Metrics:
- Tests Fixed: 2/3
- Success Rate: 33% → 100%

Comparison complete! 🎉
```

### Sample Report

The generated report shows:

```markdown
# gRPC Elliptic Curve Patch Comparison Report

## Executive Summary

- Languages Tested: Python, Ruby, C++
- Curves Tested: P-256, P-384, P-521
- Tests Fixed: 2 out of 3 total tests
- Success Rate: 33% → 100%

## Comparison Results

| Language | Curve | Baseline | Patched | Change |
|----------|-------|----------|---------|--------|
| Python   | P256  | ✅ PASS | ✅ PASS | — |
| Python   | P384  | ❌ EXPECTED_FAIL | ✅ PASS | **FIXED** 🎉 |
| Python   | P521  | ❌ EXPECTED_FAIL | ✅ PASS | **FIXED** 🎉 |
```

## Command-Line Options

### `--language <lang>`

Test specific language(s):
- `python` - Python gRPC (fastest, ~25 min build)
- `ruby` - Ruby gRPC (~20 min build)
- `cpp` - C++ gRPC (~35 min build)
- `all` - All three languages (~1+ hour build)

```bash
./compare-grpc-versions.sh --language python
./compare-grpc-versions.sh --language all
```

### `--quick`

Skip rebuild if patched version already exists:

```bash
# First run (builds patched version)
./compare-grpc-versions.sh --language python

# Subsequent runs (reuses existing build)
./compare-grpc-versions.sh --language python --quick
```

### `--skip-build`

Skip the build phase entirely (use existing patched installation):

```bash
./compare-grpc-versions.sh --language python --skip-build
```

### `--output <file>`

Specify custom output file for the report:

```bash
./compare-grpc-versions.sh --language python --output my-report.md
```

### `--help`

Display help message:

```bash
./compare-grpc-versions.sh --help
```

## Utility Scripts

The comparison system includes several utility scripts you can use independently:

### 1. Version Capture Script

Captures gRPC versions and environment metadata:

```bash
./utils/capture-grpc-versions.sh baseline > versions.json
```

Output:
```json
{
  "timestamp": "2025-12-02T12:00:00Z",
  "environment": "baseline",
  "grpc_versions": {
    "python": {
      "version": "1.70.0",
      "package_location": "/usr/local/lib/python3.12/...",
      "patched": false,
      "tls_backend": "BoringSSL"
    }
  }
}
```

### 2. Environment Manager

Switch between unpatched and patched gRPC:

```bash
# Activate patched environment
source utils/grpc-environment-manager.sh activate python

# Check status
source utils/grpc-environment-manager.sh status

# Deactivate (restore system gRPC)
source utils/grpc-environment-manager.sh deactivate
```

### 3. Report Generator

Generate comparison report from existing results:

```bash
./utils/generate-comparison-report.sh \
  results/baseline/ \
  results/patched/ \
  reports/my-report.md
```

## Directory Structure

After running the comparison, you'll have:

```
grpc-kv-examples/
├── results/
│   ├── baseline/                    # Unpatched test results
│   │   ├── curve-test-results.txt   # Raw test results
│   │   ├── grpc-versions.json       # Version information
│   │   ├── python.log               # Test output log
│   │   └── ...
│   └── patched/                     # Patched test results
│       ├── curve-test-results.txt
│       ├── grpc-versions.json
│       ├── python.log
│       ├── python-build.log         # Build output
│       └── ...
└── reports/
    └── comparison-YYYYMMDD-HHMMSS.md  # Comparison report
```

## Manual Testing Workflow

If you prefer to run steps manually:

### 1. Test Baseline (Unpatched)

```bash
# Test with system gRPC
./test-all-curves.sh --language python

# Save results
mkdir -p results/baseline
cp curve-test-results.txt results/baseline/
./utils/capture-grpc-versions.sh baseline > results/baseline/grpc-versions.json
```

### 2. Build Patched gRPC

```bash
# Build for Python
./build-patched-grpc.sh --python

# Or for all languages
./build-patched-grpc.sh --all
```

### 3. Test Patched

```bash
# Activate patched environment
source utils/grpc-environment-manager.sh activate python

# Run tests
./test-all-curves.sh --language python

# Save results
mkdir -p results/patched
cp curve-test-results.txt results/patched/
./utils/capture-grpc-versions.sh patched > results/patched/grpc-versions.json

# Deactivate
source utils/grpc-environment-manager.sh deactivate
```

### 4. Generate Report

```bash
./utils/generate-comparison-report.sh \
  results/baseline/ \
  results/patched/ \
  reports/comparison-$(date +%Y%m%d-%H%M%S).md
```

## Troubleshooting

### Build fails with "already exists"

The build directory may have partial builds. Clean and retry:

```bash
rm -rf build/patched-grpc
./build-patched-grpc.sh --python
```

### "No matching cipher" errors in baseline

This is **expected**! The unpatched gRPC only supports P-256, so P-384 and P-521 should fail with handshake errors. That's the bug we're demonstrating.

### Environment not activating

Make sure to use `source` (not `./`) with the environment manager:

```bash
# Correct
source utils/grpc-environment-manager.sh activate python

# Incorrect (won't modify your shell environment)
./utils/grpc-environment-manager.sh activate python
```

### Tests show "SKIPPED"

The test script may not have run for that language/curve combination. Check:

```bash
# Verify the test ran
cat results/baseline/python.log

# Re-run if needed
./test-all-curves.sh --language python
```

## Performance Notes

Build times on typical hardware:

- **Python**: 20-30 minutes (2.7 GB source + build artifacts)
- **Ruby**: 15-20 minutes
- **C++**: 30-40 minutes
- **All three**: 60-90 minutes

Test execution (per language):
- Each language: 2-3 minutes (3 curves × 30s timeout)
- All languages: 15-20 minutes total

## Next Steps

After running the comparison:

1. **Review the report** - Shows clear before/after evidence
2. **Share results** - The Markdown report is ready to share
3. **Test other languages** - Run with `--language ruby` or `--language cpp`
4. **Archive results** - Keep `results/` and `reports/` directories for reference

## Reference

- Main script: `compare-grpc-versions.sh`
- Test infrastructure: `test-all-curves.sh`
- Build script: `build-patched-grpc.sh`
- Patch file: `patches/grpc-ec-curves-p384-p521.patch`
- README: `README.md` (explains the bug in detail)
