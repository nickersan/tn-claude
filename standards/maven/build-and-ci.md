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
| `maven-release-plugin` | Present but unused; releases are CI's job (see GitHub Actions) |

## Profiles (activated automatically by file presence)

| Profile | Trigger | Effect |
|---------|---------|--------|
| `assembly` | `src/main/assembly/assembly.xml` exists | `maven-assembly-plugin single` on `package`, `appendAssemblyId=false` |
| `contracts-producer-java` | `src/ct/java/contracts` exists | Spring Cloud Contract producer, JUnit5, base class/package from `contract-producer.*` properties |
| `contracts-producer-groovy` | `src/ct/resources/contracts` exists | Spring Cloud Contract producer, Groovy DSL contracts |
| `docker` | `Dockerfile` exists and `-DskipDocker` not set | `docker build` on `install`, tag `${docker-image-repository}:${project.version}` (image repo defaults to `${project.name}`) — see below: a service's own image build; it needs Docker, so `-DskipDocker` when only the jar is wanted |
| `pitest` | `-Dpitest` | Pitest `mutationCoverage` over `com.tn.*` |

A component opts into a capability by adding the trigger file, not by editing build
config.

## The `assembly`/`docker` profiles: a service's own image build

A deployable `java-spring-service` **carries its own image build**, and that is the only way a Java service
gets an image (the separate `<name>-container` repos were retired on 2026-11-06 and archived). In the service repo:

- `src/main/assembly/assembly.xml`: lays out `bin/` (a `start.sh`, copied
  verbatim — `java -cp lib/*.jar <fully-qualified Application class>`, not
  `java -jar`, since there's no fat jar) and `lib/` (the service's own jar and its
  runtime dependencies, via a `<dependencySet>`) into a flat directory. This is what the
  `assembly` profile packages and what `docker`'s `IMAGE_DIR` build-arg points at.
- `Dockerfile`: minimal (`eclipse-temurin:<version>-jdk-alpine` is the current
  base), creates a dedicated low-privilege user for the service and runs as it
  (matches the Kubernetes deployment's `runAsUser`/`fsGroup` — see
  `../kubernetes/README.md`), copies the assembled directory, entrypoint is
  `start.sh`.
- `.gitattributes`: `*.sh text eol=lf`, so `start.sh` keeps LF on a Windows checkout.
- `docker-image-repository` property: set explicitly to the bare service name
  (e.g. `tn-temporary-token-service`), matching the image name used in the
  kustomize base's `images:` section.

Its `mvn install` then builds the image `${docker-image-repository}:${project.version}` (needs Docker;
`-DskipDocker` skips it), and the shared workflow deploys the jar and pushes the image, tagged with the
release version and `latest`, in one release. A deployable service without this build cannot be deployed;
check `registry.yaml` before assuming one has it.

## GitHub Actions

**Trunk-based: `main` is the only branch**, and every push to it builds and, when the
Conventional Commits since the last tag hold a `feat` or `fix`, releases. Each repo
carries one `.github/workflows/build.yaml` that calls the shared `maven.yaml` workflow
in [`nickersan/actions`](https://github.com/nickersan/actions), whose README says
exactly what a push does. In short:

- `feat` bumps the minor, `fix` the patch, a breaking change the major; anything else
  only builds.
- The release is committed back (`chore(release): <version> [skip ci]`) and tagged
  `v<version>`, so a pom on `main` declares the last release — there are no SNAPSHOTs.
- A library or service deploys to GitHub Packages; a service with a `Dockerfile` (`jar`
  packaging) also pushes its image to `ghcr.io/nickersan/${docker-image-repository}`.
- A ghcr.io package created by another repo (a retired container repo, say) stays linked to
  it: add the service repo to the package's **Manage Actions access** (role Write) before its
  first release, or the image push fails with `permission_denied: write_package` (the jar is
  already released by then).
- The repo needs a `WORKFLOW_TOKEN` secret (a PAT with `repo` and `write:packages`).
- The workflow's `java-version` (default `'25'`) must match `tn-parent`'s compiler
  release.

**Dependencies are kept current by Renovate**, run hourly from `nickersan/actions`
(`renovate/config.js` lists the repos; they carry no Renovate config of their own):

- A tn or okayat library's release reaches every repo using it straight away: its
  version properties, and `tn-parent`, move on together in one `renovate/tn-libraries`
  branch.
- Third-party minor and patch updates come once a week, Monday morning, all of a
  repo's in one branch - so `tn-parent` releases once for the lot.
- Renovate's branches build as checks, never releasing. When the build passes the
  branch is fast-forwarded onto `main` as `fix(deps):`, and `main`'s build releases it.
- A major update - Spring Boot 5, say - waits as a pull request for a person, and is
  committed as `feat(deps)!:`: a major of something we build on is a major of ours.

## Distribution

Artifacts (including attached source and test jars) publish to GitHub Packages:
`https://maven.pkg.github.com/nickersan/maven-repository`. Both `<repositories>` and
`<distributionManagement>` reference that URL; `<scm>` is
`https://github.com/nickersan/${project.artifactId}.git`.
