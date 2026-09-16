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
- Within `<dependencyManagement>`, `com.tn.*` artifacts come first, then a
  `<!-- 3rd party -->` divider, then external artifacts roughly alphabetised by
  `groupId`.
- Keep commented-out experiments only with a short reason; delete stale ones.
- **Do not repeat `<repositories>` in a component POM.** `tn-parent` already
  declares it, and Maven inherits `<repositories>` from the parent automatically —
  repeating it is redundant, not protective. Some existing components still repeat
  it (drifted, not deliberate); clean it up if you're already touching that POM.

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
    <version>2.2.0</version>
    <relativePath/>
  </parent>

  <groupId>com.tn.query</groupId>
  <artifactId>tn-query</artifactId>
  <version>1.0.1-SNAPSHOT</version>

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
