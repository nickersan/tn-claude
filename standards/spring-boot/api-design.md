# API design — REST for resources, `/actions/` for everything else

**Resource-shaped operations (get/create/update/delete/list-and-filter a thing)
stay REST-conventional: `GET`/`POST`/`PUT`/`DELETE` on the resource's own path,
filtering via `tn-query` (`?q=<expression>`, validated against the entity's actual
fields the way `tn-data-service`'s `QueryBuilder` already does it).** Keep that —
it's a good, consistent convention across the layer and worth preserving even
where a hand-written controller replaces `tn-data-service`'s fully-generic one
(see `../database/README.md` and the identity-overhaul change's design.md for why
a generic auto-registered controller isn't always the right fit, even though the
*conventions* it established are).

**Operations that don't map onto a single resource verb get an explicit action
path instead of being forced into CRUD shape: `POST /v1/actions/<kebab-case-
name>`.** A find-or-create is the motivating example — it's not "insert" (might
already exist) or "update" (might not exist yet) or a plain "get" (may need to
create); it's its own operation, so it gets its own path rather than a strained
mapping onto `POST`/`PUT`/`GET`:

```
POST /v1/actions/find-or-create
```

Request body: the identifier (type + value). Response: the resulting record,
whether it already existed or was just created. Same rules as any other
endpoint — `@Operation`/`@ApiResponse` annotated, its own Java contract, no
special-casing just because the path looks different.

Use this pattern sparingly — most operations genuinely are resource CRUD, and
`/actions/` is for the real exceptions, not a way to avoid thinking about REST
shape. If a service accumulates several action endpoints, that's a signal to
look again at whether it's still the right service boundary.

**An action on one specific resource, or on one of its collections, hangs off
that resource: `POST /v1/<resource>/{id}[/<collection>]/actions/<name>`.** The
top-level `/v1/actions/` is only for operations that don't belong to one resource
(a find-or-create, sending a passcode). For example:

```
GET  /v1/spots/{id}/followers                  list the collection
POST /v1/spots/{id}/followers/actions/add      the caller follows
POST /v1/spots/{id}/followers/actions/remove   the caller unfollows
GET  /v1/spots/{id}/admins
POST /v1/spots/{id}/admins/actions/add         body: {"userId": ...}, another user
POST /v1/spots/{id}/admins/actions/remove      body: {"userId": ...}
POST /v1/spots/{id}/actions/rollback           body: {"revision": ...}
```

Listing a collection stays a plain `GET`. In a public API, changing one goes through
named actions rather than `PUT`/`DELETE` on a member path (`.../followers/{userId}`),
because the member is usually the caller, who mustn't be named in the request (below).

**Public APIs never carry the caller's own identity.** In an API a client calls
directly (a BFF), who is calling comes from the bearer token's subject, and nothing
else. An action applied to the caller (following a spot) has no user id in its
path or body at all. A user id appears only when it names a *different* user, e.g.
the user being made an administrator, and then in the body. This keeps a client
from acting as someone else by changing an id.

**Internal (service-to-service) APIs use plain member resources instead.** Behind a
BFF, the member is simply named in the path:

```
PUT    /v1/spots/{id}/followers/{userId}   idempotent add
DELETE /v1/spots/{id}/followers/{userId}   idempotent remove
PUT    /v1/spots/{id}/admins/{userId}
DELETE /v1/spots/{id}/admins/{userId}
```

The acting user still travels separately, as a delegate user token (see `delegated-calls.md`), so
authorization ("is the caller an administrator?") keeps working. Where only the
user themselves may change a membership (following), the service rejects a path
user who isn't the token's subject with 403, which costs one comparison.
