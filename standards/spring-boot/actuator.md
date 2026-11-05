# Actuator exposure

**Expose only `health` and `resilience` of Actuator.** Do not set `management.endpoints.web.exposure.include` at all: tn-service defaults it to
`health,resilience`. Never `*`, and not `env`, `heapdump`, `beans`, `loggers` or `threaddump`: they show or change a running service's
internals (a heap dump holds keys, tokens and members' data) on the port its API is on, and nothing authenticates them. A service that
genuinely needs another endpoint adds it to the default and says why; tests assert the others answer 404.
