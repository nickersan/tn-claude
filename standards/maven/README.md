# Maven standard

Applies to every Maven build in the `tn` layer and the projects above it. Java is
always built with Maven — there is no Gradle path.

Distilled from `tn-parent`, `tn-lang` and the `tn-query` family.

## Files

| File | Covers |
|------|--------|
| [`project-structure.md`](project-structure.md) | Parent inheritance, coordinates, packaging, versioning, source layout |
| [`dependencies.md`](dependencies.md) | Where versions come from, declaring dependencies, third-party pins |
| [`pom-style.md`](pom-style.md) | Formatting of `pom.xml` |
| [`build-and-ci.md`](build-and-ci.md) | The inherited plugin set, profiles, build commands, GitHub Actions, releases |

## The one rule everything else follows

Every Java project inherits from **`com.tn:tn-parent`**. The parent owns the Java
level, the plugin configuration, dependency versions, the test-layer wiring and the
distribution setup. A component POM should be small: coordinates, parent, packaging,
its own direct dependencies, and the GitHub repository/distribution blocks.
