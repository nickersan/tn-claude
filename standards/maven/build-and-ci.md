# Maven — build and CI

## Local build

- `mvn clean install` — build, package, run unit **and** integration tests, install to
  the local repository. This is the normal command.
- `mvn test` — compile and run unit tests only (integration tests are excluded by
  name); JaCoCo report is produced.
- `mvn verify` — adds the Failsafe integration-test run and coverage merge.
- `mvn test -Dpitest` — mutation testing over `com.tn.*`.
- Build every repo in dependency order from the `tn` root: `./mvnAll.sh clean install`
  (reads `build.txt`).
- Requires Maven **3.9+** (enforced by `maven-enforcer-plugin` in the parent).

## Plugins supplied by `tn-parent` (do not re-declare per component)

| Plugin | Purpose |
|--------|---------|
| `maven-compiler-plugin` | Java release level (**25**), UTF-8, Lombok annotation processor path |
| `maven-enforcer-plugin` | Require Maven 3.9+ |
| `maven-surefire-plugin` | Unit tests; excludes `**/*IntegrationTest.java`; a second execution runs only the integration tests in the `integration-test` phase; sets `java.io.tmpdir` to `X:\mvn-tmp` (Windows multi-disk workaround) |
| `maven-failsafe-plugin` | `integration-test` + `verify` goals |
| `maven-source-plugin` | Attaches source and test-source jars on `verify` |
| `maven-jar-plugin` | `test-jar` with `skipIfEmpty` |
| `build-helper-maven-plugin` | Adds `src/it/java` and `src/ct/java` as test sources |
| `versions-maven-plugin` | Ignores `-alpha` / `-beta` / `-rc` / `-m` when reporting updates |
| `jacoco-maven-plugin` | Coverage: separate unit and integration exec files, merged report post-integration-test; excludes `**/Application.class` |
| `maven-release-plugin` | Present; day-to-day releases go through release-please instead |

## Profiles (activated automatically by file presence)

| Profile | Trigger | Effect |
|---------|---------|--------|
| `assembly` | `src/main/assembly/assembly.xml` exists | `maven-assembly-plugin single` on `package`, `appendAssemblyId=false` |
| `contracts-producer-java` | `src/ct/java/contracts` exists | Spring Cloud Contract producer, JUnit5, base class/package from `contract-producer.*` properties |
| `contracts-producer-groovy` | `src/ct/resources/contracts` exists | Spring Cloud Contract producer, Groovy DSL contracts |
| `docker` | `Dockerfile` exists and `-DskipDocker` not set | `docker build` on `install`, tag `${docker-image-repository}:${project.version}` (image repo defaults to `${project.name}`) — see below, this belongs in a `-container` repo, not a service repo |
| `pitest` | `-Dpitest` | Pitest `mutationCoverage` over `com.tn.*` |

A component opts into a capability by adding the trigger file, not by editing build
config.

## The `assembly`/`docker` profiles are for container repos, not service repos

**Never add a `Dockerfile` or `src/main/assembly/` to a `java-spring-service`
repo.** These two profiles exist for the *separate* `<name>-container` repo
(type `java-service-container` — see `component-types.yaml`) that packages an
already-published service jar into an image. Concretely, in the container repo:

- `pom.xml`: `packaging: pom`, a single dependency on the service's own jar
  (`<groupId>com.tn</groupId><artifactId><service-name></artifactId>`, pinned
  version — a real Maven dependency, not a source build), plus any
  **runtime-only** dependency the image needs that the jar itself doesn't carry.
  This is the "weave in additional runtime dependencies" the split is for: the
  jar stays a clean, independently-versioned artifact; the image can still add
  what it needs without the jar depending on it. (The original example here was
  an embedded-H2 driver for local deployment — since superseded: local now runs
  real PostgreSQL too, see `../database/README.md` and `../kubernetes/README.md`.
  The mechanism is still valid, just currently has no live example — the `h2`
  runtime dependency should be removed from `tn-auth-service-container` and
  `tn-temporary-token-service-container` as part of adopting that, not carried
  into the new `tn-user-service-container`.)
- `src/main/assembly/assembly.xml`: lays out `bin/` (a `start.sh`, copied
  verbatim — `java -cp lib/*.jar <fully-qualified Application class>`, not
  `java -jar`, since there's no fat jar) and `lib/` (all resolved dependency
  jars, via a `<dependencySet>`) into a flat directory. This is what the
  `assembly` profile packages and what `docker`'s `IMAGE_DIR` build-arg points at.
- `Dockerfile`: minimal (`eclipse-temurin:<version>-jdk-alpine` is the current
  base), creates a dedicated low-privilege user for the service and runs as it
  (matches the Kubernetes deployment's `runAsUser`/`fsGroup` — see
  `../kubernetes/README.md`), copies the assembled directory, entrypoint is
  `start.sh`.
- `docker-image-repository` property: set explicitly to the bare service name
  (e.g. `tn-temporary-token-service`), matching the image name used in the
  kustomize base's `images:` section.

Every `java-spring-service` intended for deployment needs its container repo
created alongside it — a service with no `<name>-container` repo yet cannot be
deployed. Check `registry.yaml` before assuming one exists.

## GitHub Actions

Each repo carries the same small set of workflows:

| Workflow | Trigger | Action |
|----------|---------|--------|
| `deploy.yaml` | push to `develop` | `mvn --batch-mode deploy` |
| `release.yaml` | GitHub release published | checkout the tag, `mvn --batch-mode deploy` |
| `release-please.yml` | PR closed against `main` | run `googleapis/release-please-action@v4` (`target-branch: main`) |
| `auto-merge.yaml` | PR labelled `autorelease: snapshot` | `gh pr merge --admin --squash` |

Conventions:

- `actions/checkout@v4`, `actions/setup-java@v3` with `distribution: temurin`.
- **`java-version` must match `tn-parent`'s compiler release.** The current workflows
  still pin `'21'` while the parent is on `25` — bring them in step when you touch a
  workflow.
- The token is `secrets.WORKFLOW_TOKEN`, exposed to Maven as `GITHUB_TOKEN`.
- Branch model: work merges to `develop` (snapshot deploy); `main` is the release
  branch driven by release-please.

## Distribution

Artifacts (including attached source and test jars) publish to GitHub Packages:
`https://maven.pkg.github.com/nickersan/maven-repository`. Both `<repositories>` and
`<distributionManagement>` reference that URL; `<scm>` is
`https://github.com/nickersan/${project.artifactId}.git`.
