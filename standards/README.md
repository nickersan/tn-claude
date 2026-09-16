# Standards

Engineering standards for the `tn` layer and every project built on it. Declared once,
here.

## How standards are selected

Every component declares a `type` (in its own `component.yaml`). `component-types.yaml`
in this directory maps each `type` to the standard sets that apply. A component is
expected to follow the union of those sets.

```
type: java-library        ->  conventions + java + maven
type: java-spring-service  ->  conventions + java + maven + spring-boot + kubernetes (+ database if it persists)
```

## Layout

| Directory | Applies to | Status |
|-----------|-----------|--------|
| `conventions/` | everything | placeholder |
| `java/` | any JVM component | **drafted** |
| `maven/` | any Maven build | **drafted** |
| `spring-boot/` | Spring Boot services | placeholder |
| `react/` | React web / shared UI | placeholder |
| `database/` | components owning schema | placeholder |
| `kubernetes/` | anything deployed to a cluster | placeholder |

## Principles

- **Read the code first.** These standards were distilled from `tn-lang`, `tn-query`
  and `tn-parent`. Changes should be driven by what the codebase does, or by a
  deliberate decision to change it — not by external convention.
- **Small files.** Each file covers one topic so a human (or an agent) can load only
  what is relevant.
- **State the exceptions.** Where the existing code is inconsistent, the standard says
  so and names the intended direction.
