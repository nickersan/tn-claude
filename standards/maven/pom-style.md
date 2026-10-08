# Maven — pom.xml style

The POMs in this codebase are formatted for readability, more loosely spaced than a
generated POM.

- XML declaration first: `<?xml version="1.0" encoding="UTF-8"?>`, then a blank line,
  then `<project>`.
- **Two-space** indentation.
- A **blank line after every opening container element** that has multiple children
  (`<project>`, `<properties>`, `<dependencies>`, `<dependencyManagement>`, `<build>`,
  `<plugins>`, `<profiles>`) and before the matching close.
- A blank line **between sibling blocks** — between each `<dependency>`, each
  `<plugin>`, each `<profile>`, each property group.
- Group and lightly comment: `<!-- 3rd party -->` before external dependencies,
  `<!-- old version ... -->` / `<!-- CORS issue with newer version -->` to explain a
  pin, exclusion or commented-out block.
- Order inside `<project>`: `modelVersion`, `parent`, coordinates
  (`groupId` / `artifactId` / `version`), `packaging`, `properties`, `dependencies`,
  `dependencyManagement`, `build`, `profiles`, `scm`, `distributionManagement`.
- Within `<dependencyManagement>`, artifacts are roughly alphabetised by `groupId`.
  `tn-parent` manages no `com.tn.*` artifacts (see `dependencies.md`).
- Keep commented-out experiments only with a short reason; delete stale ones.
- **Every component POM repeats the GitHub Packages `<repositories>` entry**, as
  `dependencies.md` shows. Maven does inherit it from `tn-parent`, but only once it has
  the parent - and the parent itself comes from GitHub Packages. Without it a build
  works only where `settings.xml` names the repository, which CI's doesn't.

## Component POM skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>

<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">

  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.tn</groupId>
    <artifactId>tn-parent</artifactId>
    <version>3.0.0</version>
    <relativePath/>
  </parent>

  <groupId>com.tn.query</groupId>
  <artifactId>tn-query</artifactId>
  <version>1.0.0</version>

  <packaging>jar</packaging>

  <dependencies>

    <!-- 3rd party -->

    <dependency>
      <groupId>com.google.guava</groupId>
      <artifactId>guava-testlib</artifactId>
    </dependency>

  </dependencies>

</project>
```

`<scm>` and `<distributionManagement>` are inherited from the parent (which templates
them on `${project.artifactId}`); only restate them in a component if it deviates.
