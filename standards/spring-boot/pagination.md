# Pagination — Spring Data's native `Pageable`, not a hand-rolled scheme

**Don't reinvent pagination query params.** `tn-data-service` currently does —
custom `$pageNumber`/`$pageSize`/`$sort`/`$direction` params and a hand-rolled
`com.tn.lang.util.Page` response wrapper. That's now superseded: accept
`org.springframework.data.domain.Pageable` directly as a controller method
parameter (Spring Boot auto-configures `PageableHandlerMethodArgumentResolver`
whenever `spring-data-commons` is on the classpath, which it already is via
`spring-boot-starter-data-jpa`) — it resolves the standard `page`, `size`, and
repeatable `sort` (`sort=name,desc`) request params for you, no bespoke parsing.

**Don't serialize `Page<T>` directly — it's explicitly not a stable contract.**
Spring Data's own docs warn that `PageImpl`'s JSON shape can change between
versions. Since Spring Data 3.3 (well below what `tn-parent` manages),
`org.springframework.data.web.PagedModel<T>` gives a stable wrapper without
needing Spring HATEOAS: `new PagedModel<>(page)`, or enable it service-wide with
`@EnableSpringDataWebSupport(pageSerializationMode = VIA_DTO)`.

**For a large, deep-scrolled dataset, prefer keyset pagination over offset —
`Window<T>`/`ScrollPosition` (Spring Data 3.1+) — instead of `Pageable`.** Offset
pagination gets slower as the offset grows (the database scans and discards
every skipped row); keyset pagination uses an indexed `WHERE` clause instead and
stays fast at any depth, at the cost of no "jump to page N" and no total count.
Not needed for a small/bounded dataset (a user-profile table, say) — worth
reaching for on something users might actually scroll deep into (candidate:
`spots/search`'s anonymous browse, if it ever needs to support that — not
decided, see `okayat-platform`'s own design.md).
