# Fuzz Bug Report: FuzzTestBug

## Bug Information
- **Bug ID**: FuzzTestBug_crash1
- **Fuzz Target**: FuzzTestBug
- **Crash Type**: Panic
- **Detected**: Thu Apr 24 01:31:43 PM UTC 2025

## Crash Output
```
panic: test panic message for demonstration

goroutine 1 [running]:
testing.tRunner.func1.2(0x1100000, 0x1200000)
    /usr/local/go/src/testing/testing.go:1142 +0x25a
github.com/lightningnetwork/lnd/example.FuzzTestBug(0x2000000)
    /workspace/lnd-fuzz-poc/lnd/example/fuzz_test.go:42 +0x123
testing.(*F).Fuzz(0x3000000)
    /usr/local/go/src/testing/fuzz.go:330 +0x5a1
```

## How to Reproduce
Save the input file and run:
```
cd lnd
go test -run=FuzzTestBug -fuzz=FuzzNone ./... -args "./fuzz-bugs/FuzzTestBug_crash1/input"
```
