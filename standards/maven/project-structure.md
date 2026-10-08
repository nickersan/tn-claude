# Maven — project structure

## Parent

Every Java component POM declares:

```xml
<parent>
  <groupId>com.tn</groupId>
  <artifactId>tn-parent</artifactId>
  <version>2.2.0</version>
  <relativePath/>
</parent>
```

- `<relativePath/>` is **empty** — the parent is resolved from the Maven repository
  (GitHub Packages), not a sibling directory. Do not point it at `../tn-parent`.
- Pin an explicit released parent version. Bump it deliberately, as its own change.

## Coordinates

- `groupId` is namespaced by family, not flat:
  `com.tn` (core), `com.tn.query`, `com.tn.service`, `com.tn.service.data`,
  `com.tn.client`. A new family gets a new `com.tn.<family>` groupId.
- `artifactId` equals the repository name (`tn-lang`, `tn-query`, `tn-query-jdbc`).
- `packaging` is stated explicitly: `pom` for aggregator/parent POMs, `jar` for
  libraries and services.

## Versioning

- CI sets the version, never a person: each push to `main` with a `feat` or `fix`
  since the last tag releases, and commits the new version back. So the pom on
  `main` declares the last release, and there are no SNAPSHOTs (see
  `build-and-ci.md`, GitHub Actions).
- Depend on released versions only, e.g. a container repo's pin on its service jar,
  which CI moves on with each release.
- Commit messages follow Conventional Commits, since they decide the bump. The
  release notes are generated on each GitHub release; a `CHANGELOG.md` from the
  release-please days is history, no longer maintained.

## Source layout

Standard Maven layout, plus two extra test roots wired by the parent:

```
src/
  main/java, main/resources
  test/java, test/resources        # unit tests            (Surefire)
  it/java,   it/resources          # integration tests     (Failsafe; *IntegrationTest.java)
  ct/java,   ct/resources          # contract tests        (Spring Cloud Contract)
  main/assembly/assembly.xml       # optional; activates the assembly profile
Dockerfile                         # optional; activates the docker profile
```

- `src/it/java` and `src/ct/java` are added as test-compile sources by
  `build-helper-maven-plugin` — you do not configure that per project.
- Filtered resource roots: `src/main/resources`, `src/test/resources`,
  `src/it/resources` (and `src/ct/resources` for contracts).

## Multi-repo, not multi-module

Components are **separate repositories**, each independently released. A repo may
contain a small reactor of closely-related modules (as `tn-query` does:
`tn-query`, `tn-query-java`, `tn-query-jdbc`, `tn-query-jpa`), but cross-component
dependencies are always on **released Maven artifacts**, never source.

`build.txt` at the `tn` root lists repos in dependency order for local
"build everything" runs via `mvnAll.sh` / `mvnAll.bat`.

## `.gitignore`

At minimum:

```
*.iml
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar
```
