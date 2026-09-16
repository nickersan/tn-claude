# Kubernetes standard

Applies to `java-service-container` (what gets deployed) and
`kustomize-deployment` (how it's deployed) components. Distilled from `pilch`'s
existing `kustomize/` + `*-container` repos — the working pattern this layer
inherits, not a fresh design.

## The shape

- Each deployable `java-spring-service` has a paired **`<name>-container`** repo
  that builds its Docker image — see `../maven/build-and-ci.md`. The image name
  is the bare service name (`oauth-service`, `tn-temporary-token-service`, ...).
- One **`kustomize-deployment`** repo per project (e.g. `okayat-kustomize`) holds
  the manifests for everything that project deploys — its own components *and*
  the tn-layer components it depends on. tn itself doesn't own one; it has no
  environment to deploy to.

## Kustomize layering

```
kustomize/
├─ base/
│  ├─ kustomization.yaml       # resources: + images: (name -> tag) for every service
│  ├─ config.yaml              # ConfigMap: inter-service URLs (http://<service>:8080)
│  ├─ deployment-<service>.yaml  # Service + Deployment, one file per service
│  └─ ingress-<name>.yaml
└─ overlays/
   └─ <environment>/
      ├─ kustomization.yaml    # resources: [../../base, ...env-only resources]
      │                        # patches: strategic-merge patches, one per service
      ├─ deployment-<service>.yaml  # patch: env vars, resources, probes overrides
      └─ ...env-only resources (config, storage, secrets)
```

- **Base** is environment-agnostic: what the service is (Service + Deployment
  with health probes), not how any particular environment runs it. No datasource,
  no secrets, no replica counts here.
- **Overlays** patch base by resource name (Kustomize's strategic-merge —
  `apiVersion`/`kind`/`metadata.name` must match the base resource exactly) and
  add environment-only resources. This is the mechanism for "local needs its own
  database, another environment uses RDS": the base `Deployment` carries no
  datasource config at all; the `local` overlay's patch injects
  `SPRING_DATASOURCE_*` env vars pointing at a file-backed embedded database
  (H2 — see below) plus a `PersistentVolume`/`PersistentVolumeClaim` for it; an
  RDS-backed overlay would instead inject `SPRING_DATASOURCE_URL` pointing at
  the RDS endpoint and no PVC at all. The base Deployment doesn't change either
  way.
- **Image tags** are set once, in `base/kustomization.yaml`'s `images:` list —
  overlays never repeat them.
- **Labels**: every environment's kustomization applies a distinguishing pair
  (`app: <project>` in base, `env: <environment>` in the overlay) via `labels:` /
  `includeSelectors: true` — don't hand-label individual resources.

## Local environment specifics

- The `local` overlay runs each service against a **file-backed H2 database**
  (`jdbc:h2:file:/opt/<org>/<project>/<service>/data/<service>-db;AUTO_SERVER=TRUE`),
  not a separate database pod — this is why `h2` is a `runtime`-scope dependency
  on the *container* repo (see `../maven/build-and-ci.md`), not a test-only one.
  A `PersistentVolume` + `PersistentVolumeClaim` back the data directory so it
  survives pod restarts; the Deployment patch mounts it and sets
  `runAsUser`/`fsGroup` so the container's non-root user can write to it.
- Secrets/keys a service needs locally (e.g. JWT signing keys) go in an
  overlay-only `ConfigMap` (`config-local.yaml` today — a `Secret` would be the
  better primitive for real key material, worth revisiting) referenced via
  `valueFrom.configMapKeyRef` in the deployment patch, using the
  SCREAMING_SNAKE_CASE form of the Spring property
  (`FOO_BAR_BAZ` → `foo.bar.baz`).
- Non-local environments (staging, prod, ...) get their own overlay following the
  same shape; where a managed service replaces something local runs itself (RDS
  instead of the H2 PVC, a managed secrets store instead of `config-local`), that
  substitution lives entirely in that overlay — base and the other overlays don't
  change.

## Health probes

Every `java-spring-service` exposes a plain, unauthenticated `GET /noop` →
`200 OK` (see `NoopController` in `tn-temporary-token-service`/`tn-auth-service`)
and the base `Deployment` wires both `readinessProbe` and `livenessProbe` to it.
This is a liveness check ("is the process up"), deliberately not Spring Boot
Actuator's `/actuator/health` (which also reports dependency health and would
fail the pod for a downstream outage, not just a dead process) — add the
`/noop` controller to every new service rather than reaching for actuator's
endpoint here.

## Still to define

- Non-local overlay(s) — no example exists yet in either `pilch` or `tn`; write
  one distilled from a real environment when the first non-local deployment
  happens, don't guess its shape now.
- `Secret` vs `ConfigMap` for real key material (noted above).
- Resource requests/limits — not present in the `pilch` example; decide when
  sizing an environment for real.
