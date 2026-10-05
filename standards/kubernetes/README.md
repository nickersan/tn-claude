# Kubernetes standard

Applies to `java-service-container` and `web-container` (what gets deployed) and
`kustomize-deployment` (how it's deployed) components. Distilled from `pilch`'s
existing `kustomize/` + `*-container` repos — the working pattern this layer
inherits, not a fresh design.

## The shape

- Each deployable `java-spring-service` has a paired **`<name>-container`** repo
  that builds its Docker image — see `../maven/build-and-ci.md`. The image name
  is the bare service name (`oauth-service`, `tn-temporary-token-service`, ...).
- Each `react-web` UI likewise has a **`<name>-container`** repo (`web-container`)
  that builds an nginx image serving it. nginx also proxies the API path to the
  BFF, so the browser talks to one origin and needs no CORS. The BFF's URL comes
  from the base ConfigMap at startup (nginx's `envsubst` templates), so one image
  runs in every environment. Its `/noop` answers from nginx itself.
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
  `SPRING_DATASOURCE_*` env vars pointing at a real, containerised PostgreSQL
  deployed in that overlay (see below) plus whatever storage that Postgres
  deployment needs; an RDS-backed overlay would instead inject
  `SPRING_DATASOURCE_URL` pointing at the RDS endpoint and no local database
  deployment at all. The base Deployment doesn't change either way.
- **Image tags** are set once, in `base/kustomization.yaml`'s `images:` list —
  overlays never repeat them.
- **Labels**: every environment's kustomization applies a distinguishing pair
  (`app: <project>` in base, `env: <environment>` in the overlay) via `labels:` /
  `includeSelectors: true` — don't hand-label individual resources.

## Local environment specifics

- **The `local` overlay runs each service against a real, containerised
  PostgreSQL — not H2.** (Revised: the original version of this standard,
  distilled from `pilch`, used a file-backed embedded H2 database precisely to
  avoid a database pod locally. Superseded — H2 doesn't share Postgres's dialect
  or behaviour, so a service tested/run against it locally isn't meaningfully
  tested against what every real environment actually runs, and this layer
  standardises on Postgres everywhere; see `../database/README.md`.) A
  `postgres` deployment (official image, one instance covering the services in
  that overlay unless a real reason emerges to split it) with a
  `PersistentVolume`/`PersistentVolumeClaim` for its data directory takes H2's
  place; each service's Deployment patch points `SPRING_DATASOURCE_URL` at it
  instead of an embedded file path. `runAsUser`/`fsGroup` still apply to whatever
  writes to the persisted volume — now the Postgres deployment, not each service.
  `h2` is no longer a dependency of the container repos that made this switch
  (see `../maven/build-and-ci.md`) — don't carry it forward into new ones.
- **Keys go in a `Secret`.** Anything a service needs locally that is key
  material (e.g. JWT signing keys) comes from a `secretGenerator` in the overlay.
  It reads an env file that a script in the repo generates and Git ignores, so
  no key is committed. The deployment patch refers to it with
  `valueFrom.secretKeyRef`, using the SCREAMING_SNAKE_CASE form of the Spring
  property (`FOO_BAR_BAZ` → `foo.bar.baz`). Kustomize gives the Secret a
  content-hash suffix and rewrites the references, so new keys roll the pods.
  This replaces the earlier overlay-only `ConfigMap`. Settings that aren't
  secret still go in ConfigMaps.
- **Services wait for the overlay's Postgres.** Each Deployment that uses it gets
  an `initContainer` that polls `pg_isready` against it, so a cold start doesn't
  have to wait out a crash loop. This lives in the overlay, since a managed
  database is up before anything deploys.
- **Reaching services from outside the cluster:** add `type: LoadBalancer`
  Services in the overlay, on ports that don't clash with the same services run
  natively, rather than changing the base Services. Docker Desktop maps a
  LoadBalancer Service to the host's port, including on the LAN.
- **Images:** Docker Desktop's Kubernetes uses the images in the local Docker,
  so the container repos' builds are deployable as they are. A rebuilt image
  keeps its tag, so it needs a `kubectl rollout restart` to be picked up.
- Non-local environments (staging, prod, ...) get their own overlay following the
  same shape; where a managed service replaces something local runs itself (RDS
  instead of the self-hosted Postgres deployment, a managed secrets store instead
  of the generated Secret), that substitution lives entirely in that overlay — base and
  the other overlays don't change. The point of running real Postgres locally too
  is that this substitution is the *only* difference — not database engine as
  well.

The reference implementation is `okayat-kustomize`.

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
- Resource requests/limits — not present in the `pilch` example; decide when
  sizing an environment for real.
