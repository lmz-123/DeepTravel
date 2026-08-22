## Context

See `proposal.md` for motivation. The current community tables store every comment as a flat post child and the client loads one ascending comment list. Complete stories already live on `story_arcs`, but their text is revealed through journey reconstruction and they have no independently reviewed full-story audio track or home publication state. The discovery page receives dynamic city image/name/subtitle data but renders a compact popup, while its “听一个短故事” row is static. Route narration and the draggable playback orb already establish a single-player expectation that the new story listener must preserve.

The API and independent admin service declare ORM models for the same MySQL content data, so schema changes originate in the main API Alembic chain and matching admin mappings ship separately. Public media stays in the configured local/OSS abstraction; private journey evidence and provider voice identifiers must never leak through story or community responses.

## Goals / Non-Goals

**Goals:**

- Evolve flat comments additively into stable two-level conversations without losing existing rows or post counts.
- Reuse each route's reviewed complete story as the only transcript source while adding a separately controlled home-listening publication.
- Coordinate home-story and route audio through one observable ownership state.
- Improve hierarchy and city selection with server-driven UI, without introducing city/resource constants in Flutter.
- Publish revised Shenzhen content through the existing graph, narration review, and package lifecycle while proving Shanghai is untouched.

**Non-Goals:**

- General-purpose recursive comment trees, social graph ranking, or a new recommendation service.
- A second copy of complete-story prose that can drift from `story_arcs.complete_story`.
- Client-side TTS, client-side random catalog assembly, or embedding provider voice IDs in the app.
- Automatic approval of generated speech; human listening approval remains part of publication.

## Decisions

### 1. Store a root and exact reply target, but render only two levels

Add nullable self-references `root_comment_id` and `reply_to_comment_id` to `community_comments`. Existing and new top-level rows keep both null. For any reply, `root_comment_id` points to the top-level comment and `reply_to_comment_id` points to the exact visible comment selected by the traveler. Replying to a reply copies that reply's root instead of creating another display depth.

This preserves conversational meaning (“A 回复 B”) while preventing recursive layout and expensive arbitrary-depth reads. Storing only a parent would either create unbounded trees or lose the exact reply target when normalizing depth; storing only a root would lose who was answered.

Indexes cover `(post_id, root_comment_id, status, created_at, id)` and the two self-foreign keys use restrictive validation plus nullable references. Service validation requires target and root to belong to the same visible post and to pass the existing node-access boundary. Existing idempotency uniqueness remains authoritative.

### 2. Page roots and replies independently

`GET /api/v1/community-posts/{post_id}/comments` continues to page roots in stable ascending order and returns a small server-bounded reply preview per root. `GET /api/v1/community-comments/{root_id}/replies` pages all visible replies for that root. Comment creation keeps `POST /api/v1/community-posts/{post_id}/comments` and adds optional `reply_to_comment_id`.

Comment payloads add `root_comment_id`, a privacy-safe `reply_to` author projection, `reply_count`, `reply_preview`, and `is_tombstone`. The post count covers visible roots and replies. Root deletion/holding/report-hiding uses a content-free tombstone when other visible replies need the grouping; otherwise it disappears normally. This is preferable to returning one large nested collection, which would make busy posts unbounded and cursor behavior unstable.

### 3. Keep reply composition in the existing detail surface

The post detail sheet renders each root as the primary comment card and replies in a lightly tinted inset group with a single guide line, author, “回复某人”, timestamp and compact actions. “回复” on any visible comment selects a target; a small context chip above the fixed composer names that target and offers cancel. The same draft controller is retained on cancel so text is not discarded.

Root and reply loading states are local to their thread. A failed reply mutation retains the draft and target, while narration and journey state remain independent. This keeps the discussion legible without introducing another route or full-screen navigation level.

### 4. Model home listening as an explicit publication over the canonical story arc

Add `home_story_publications` with one row per story arc: client-facing title, introduction, cover reference, positive selection weight, status (`draft`, `in_review`, `published`, `archived`), selected narration profile/track, review provenance, and publication timestamps. Add `story_narration_tracks` keyed by arc, narration profile, transcript hash and script version, with the same public-media metadata and approval provenance used by fragment tracks.

The spoken transcript is always `story_arcs.complete_story`; the publication does not store a second transcript. Editing the complete story changes its hash and makes every prior full-story track ineligible until regenerated/reviewed. A publication references one approved matching track, so route reconstruction and home listening cannot silently diverge.

A separate publication row was chosen over adding all home fields to `story_arcs`: reconstruction remains a domain fact of a route, while home distribution is an editorial channel that can be withdrawn, weighted, or retitled without changing the story graph.

### 5. Random selection is server-side, city-scoped, and publication-safe

Add `GET /api/v1/stories/random?city_slug={slug}&exclude_id={optional}`. The application service joins published city, route, arc, publication and matching published track, then selects by configured positive weight. When two or more candidates exist it honors a valid exclusion hint; otherwise it may return the same item. A structured `story_pool_empty` 404 distinguishes an empty curated pool from transport failure.

The response contains story/publication ID, city and route display context, title, introduction, cover URL, duration, complete transcript, audio URL, and narration-profile display name/description. It never returns object keys, storage credentials, internal review notes or provider voice IDs. Filtering and random selection stay in the API so archived/unpublished data cannot be reconstructed from route payloads in Flutter.

The independent admin receives CRUD/review/publish endpoints and UI for this publication plus full-story audio generate/upload/preview/approve actions. It reuses the current narration synthesizer and media adapters rather than adding another provider integration.

### 6. Introduce one application-level audio ownership coordinator

Create an application-layer coordinator with an owner enum (`routeNarration`, `homeStory`, or none), destination, playback phase, position and duration. Both the active-tour controller and home-story controller request ownership before preparing playback. Granting ownership first stops and releases the previous source, then updates the single observable state; a generation token prevents late callbacks from an old source from reclaiming the UI.

The rotating orb reads this coordinator: it rotates only in `playing`, remains still in paused/ended/loading states, preserves its existing drag-and-edge-snapping behavior, and routes taps to either the journey or story page. This avoids two independent players racing while keeping route-specific progress mutations inside the tour controller.

### 7. Use a dedicated story listener route, not an enlarged home card

The static home promise row becomes an accessible button. It requests a random story for the selected city, then opens `/stories/{publicationId}` with cached metadata while the provider can refresh by ID. The page uses a strong cover/title/intro block and a compact audio card with play/pause, seek bar, elapsed/total time, transcript expansion, replay and “换一个故事”. Empty-pool and request failures remain inline on home or the listener without disturbing the route carousel.

This gives title and context enough space and allows the orb to return to a stable destination; autoplay is avoided so tapping the discovery action does not unexpectedly stop route narration before the user presses play.

### 8. Move reconstruction control into the ledger bottom sheet

Remove the journey-body `_ReconstructionCard` and the “你正在追问” kicker. The central theme remains as an unlabelled story heading. The ledger sheet appends one state-aware card after its entries: hidden while locked, “拼回完整故事” when unlocked, and “查看完整故事” after successful reconstruction. Opening reconstruction closes or stacks safely above the ledger using root navigation, and returning restores the ledger rather than creating a duplicate journey route.

This is a presentation relocation only; collection, reconstruction submission and recap authorization remain server-controlled.

### 9. Replace the city popup with a scalable selection sheet

The header chip opens one modal selection sheet using the existing `citiesProvider` collection. Each city card uses backend name, subtitle and hero image with a clear selected mark. For seven or fewer cities the sheet favors visual browsing; from eight cities onward it shows an immediately filtering search field over normalized name/subtitle text. A one-column phone layout preserves image and copy legibility; wider screens may use two columns.

Selection updates the existing selected-city provider, closes the sheet, and invalidates city route and random-story state. Refresh failure retains the last valid object. This uses current city fields and avoids a schema expansion solely for decoration; future admin-configured cities appear without a client release.

### 10. Revise and publish Shenzhen content as versioned content

Create a versioned South China editorial style checklist and update both maintained Shenzhen experiences: the Nantou seed/package representation and a new version of the Dameisha content package. Scripts follow a repeatable arc: locate the traveler, point out one observable detail, connect it to a sourced fact in conversational language, state uncertainty naturally, then offer an optional practical viewpoint. Repeated system phrases such as “第一条线索是” are removed unless narratively necessary.

The admin profile stores the chosen female Mandarin provider voice and client-safe display text. Candidate previews are generated with gentle pacing and restrained warmth, listened to, then the complete Shenzhen coverage is regenerated and published. Before editing, tests snapshot every Shanghai content value, script version, transcript hash, track and publication state; the post-publication comparison must be identical.

## API and module boundaries

- `community`: owns reply validation, thread projections, moderation-aware counts and cursors; it does not call journey progression or audio modules.
- `story_listening`: owns eligible-publication selection and public serialization; it reads catalog/story/narration records but cannot publish them.
- `historical_content` and admin content graph: remain canonical for complete-story text, sources and review state.
- admin narration workflow: owns TTS invocation, preview, approval and publication; the public API only reads approved tracks.
- Flutter repository: adds typed thread/reply and home-story requests; controllers own state, while widgets never call HTTP, location, media storage or TTS directly.
- audio ownership coordinator: arbitrates playback only; it never advances fragments or marks stories as completed.

## Failure behavior

- Invalid, deleted, held, cross-post or inaccessible reply targets use the existing non-enumerating not-found/validation envelope and never create partial rows.
- Reply preview failure leaves roots usable; reply-create failure keeps composer text and target for retry.
- Empty story pool is a first-class friendly state; malformed/stale media is excluded before selection, and playback failure leaves metadata/transcript readable.
- Old audio callbacks are ignored after ownership generation changes, preventing a stopped player from toggling the orb or journey state.
- City images may use the existing editorial image fallback, but city identity and list membership never fall back to hard-coded client data.
- Content or audio validation failure blocks only the affected Shenzhen publication and does not modify Shanghai.

## Risks / Trade-offs

- [Viewer-specific moderation makes counts more expensive] → Batch root/reply counts, retain bounded previews, add covering indexes, and never issue one query per thread in feed serialization.
- [Root tombstones can make a discussion look sparse] → Show them only when visible replies require context and keep the tombstone visually quiet.
- [Weighted SQL randomness can degrade with a very large catalog] → The near-term catalog is small; encapsulate selection behind the service so a precomputed strategy can replace it without changing the API.
- [Complete stories can spoil route reconstruction] → Require separate explicit home publication and never infer eligibility from route publication alone.
- [Starting another audio source may surprise the traveler] → Do not autoplay on opening a story; only an explicit play/start action requests ownership, and every player visibly converges after the switch.
- [Conversational rewriting can accidentally strengthen historical claims] → Validate graph equivalence and require a human factual-boundary review before regeneration/publication.
- [TTS settings do not guarantee perceived warmth] → Treat provider settings as candidates, not approval; retain listening review and the ability to upload a manually produced track.

## Migration Plan

1. Capture main/admin working-tree state and Shanghai content/audio hashes; add the API migration with nullable comment references plus story publication/track tables and matching ORM mappings.
2. Deploy schema and backward-compatible API reads first. Existing comments remain roots, old clients ignore new fields, and no home story is eligible because publication rows begin as draft.
3. Deploy admin editing, audio review and publication controls, then create the Shenzhen profile and draft home-story records.
4. Deploy the Flutter client with thread rendering, ledger relocation, story listener/audio ownership and city sheet. It tolerates an empty story pool.
5. Import and validate versioned Shenzhen content, generate/review matching node and complete-story audio, explicitly publish the profile and selected home stories, then verify public media and Shanghai hash equality.
6. Rollback code by reverting clients/services while leaving additive columns/tables in place. Withdraw home stories/profile publications before reverting content; do not downgrade the database until new reply rows have been exported, because removing their relationship columns would lose conversation structure.

## Open Questions

- The exact provider female voice ID and final speed/pitch/emotion combination are listening-review outputs stored in admin configuration; choosing among provider candidates does not change the API, schema, client behavior or task breakdown.
