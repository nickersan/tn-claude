# Maven — dependencies

## Versions come from the parent

`tn-parent` carries a large `<dependencyManagement>` block and a set of always-on
`<dependencies>` (JUnit, Mockito, `jakarta.annotation`). In a component POM:

- Declare a dependency **without a `<version>`** when the parent manages it. This
  covers the whole Spring Boot / Spring Cloud stack, Jackson, Guava, Flyway,
  PostgreSQL, Lombok, SLF4J/Logback, Testcontainers, H2, jjwt, commons-*, snakeyaml,
  springdoc, and every `com.tn.*` artifact.
- Only specify a `<version>` for something genuinely not in the parent, and treat that
  as a signal: if it is reusable, it probably belongs in the parent instead.
- Versions that need to move together are driven by a property in the parent
  (`${spring-boot.version}`, `${spring-cloud.version}`, `${flyway.version}`,
  `${junit.version}`, `${mockito.version}`, `${lombok.version}`, `${guava.version}`,
  `${jsonwebtoken.version}`).

## Declaring component dependencies

- Group `com.tn.*` dependencies first, then a `<!-- 3rd party -->` comment, then
  external ones.
- Test-only artifacts get `<scope>test</scope>`. `test-jar` dependencies use
  `<type>test-jar</type>` + `<scope>test</scope>` (the parent already manages the
  `tn-service` / `tn-data-service-jpa` test jars).
- Keep the list minimal — a library POM often adds just one or two lines because the
  parent supplies the rest.

## Third-party pins and exclusions

When you must pin or exclude, leave a comment saying why — this is the existing
practice in `tn-parent`:

```xml
<!-- old version of logback that plays nicely with Spring Boot -->
<dependency>
  <groupId>ch.qos.logback</groupId>
  <artifactId>logback-classic</artifactId>
  <version>1.5.32</version>
</dependency>
```

```xml
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-starter-contract-verifier</artifactId>
  <scope>test</scope>
  <exclusions>
    <exclusion>
      <groupId>commons-codec</groupId>
      <artifactId>commons-codec</artifactId>
    </exclusion>
  </exclusions>
</dependency>
```

## Checking for updates

`versions-maven-plugin` is configured in the parent to ignore `-alpha`, `-beta`,
`-rc` and `-m` pre-releases. Use
`mvn versions:display-dependency-updates` against the parent to review upgrades;
apply them in the parent, not scattered across components.

## Repository configuration

Both the parent and each component repeat the GitHub Packages repository so a clean
checkout can resolve `com.tn.*` artifacts and the parent itself:

```xml
<repositories>
  <repository>
    <id>github</id>
    <url>https://maven.pkg.github.com/nickersan/maven-repository</url>
    <releases><enabled>true</enabled><updatePolicy>always</updatePolicy></releases>
    <snapshots><enabled>true</enabled><updatePolicy>never</updatePolicy></snapshots>
  </repository>
</repositories>
```

Authentication is via `~/.m2/settings.xml` using a GitHub token; in CI it is
`secrets.WORKFLOW_TOKEN` exposed as `GITHUB_TOKEN`.
