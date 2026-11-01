# Sino Defence Forum — iOS client

Repository: <https://github.com/straytachyon/SinoDefenseForum>

A native SwiftUI client for **Sino Defence Forum** at
`https://www.sinodefenceforum.com/` (XenForo 2.3).

The forum has no public API key, so the app reads and writes the same server-rendered
pages the website uses. Sign in with a forum account for posting and moderator
tools, or browse as a guest for read-only access. Credentials, cookies and form
tokens stay between the app and the forum.

## What it does

- **New posts tab** — the first tab opens `/whats-new/posts/` and paginates
  XenForo's forum-wide "New posts" listing. It replaces the "Unread" tab used by
  the China Defense Forum client.
- **Forum tabs plus a Forums directory** — the first three forums in your
  arranged order get their own tabs; every top-level forum is also listed in
  Forums. This avoids UIKit's nested "More" navigation bar, so thread pages have
  a single back button. On iPad the tabs adapt to a sidebar.
- **Child forums** appear as chips at the top of their parent board and open
  inside the same tab.
- **Threads open where you left off** — unread rows use XenForo's `/unread`
  endpoint, while read threads open at `/latest`, the newest post.
- **Native thread rendering** — post headers, avatars, member titles, staff
  badges, quotes, code cards, inline images, lists, links and YouTube embeds.
  Tap a picture for a full-screen, swipeable, pinch-zoomable gallery.
- **Posting** — reply to a thread or start a new one. Replies do not prompt for
  a subject; only new threads do. The editor keeps a
  forum-style BBCode toolbar (bold, italic, quote, code, lists, links, image,
  YouTube, size, colour, alignment, spoiler, table, super/subscript and smileys)
  and converts the draft to the HTML that XenForo's editor accepts. A local
  preview renders the result through the same native post renderer.
- **Attachments** — attach photos from the Photos library or files from Files
  to new threads and replies. Uploads use XenForo's attachment manager/hash, show
  per-file progress and can be removed before posting (which deletes the uploaded
  attachment server-side). Files are capped at 50 MB in the app.
- **Moderator tools** — when the signed-in account has moderator permission,
  thread pages expose Stick/Unstick, Lock/Unlock, Move and Delete actions, and every
  post gets a moderator menu with Delete Post, including an optional reason for
  the moderator log. The app confirms the permission
  from XenForo's own moderator controls before showing these actions; it does
  not guess from a user's title.
- **Reorderable board tabs** — the ↑↓ button in the toolbar (or Settings →
  Arrange Board Tabs) opens a list where boards move up/down. "New posts" stays
  pinned first; the order is saved and restored on launch.
- **Guest mode** — the login screen offers "Browse as a Guest". Guests can read
  New posts, forums and threads; posting and moderation ask for a sign-in.
- **Appearance** — force Light or Dark, follow the system, and scale post text
  from 80% to 150% with a live preview.
- **Persistent session** — XenForo cookies are reused across launches; the
  password can be kept in the iOS Keychain so an expired session is renewed
  silently.
- **In-app browser** with the app's forum cookies injected, for profiles,
  search, attachments and the full web editor.
- Board list cached on disk so the tab bar appears instantly at launch.

## Requirements

- Xcode 26 or later (project format used by Xcode 27)
- iOS / iPadOS 18.0+
- A Sino Defence Forum account for posting and moderation; reading also works
  as a guest

## Build

Open `SinoDefence.xcodeproj`, choose the `SinoDefence` scheme and run on an
iPhone or iPad simulator or device. No third-party packages.

```sh
xcodebuild -project SinoDefence.xcodeproj -scheme SinoDefence \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

If you build from inside a restricted automation sandbox whose seccomp policy
blocks `sandbox-exec`, add `OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
so Swift's macro plugin server can run.

## Demo mode

Debug builds accept a `-demo` launch argument which seeds the app with XenForo
fixture pages, parsed by the real `XFParser`. It exists so the UI can be
exercised without forum credentials, and has a moderator account and a thread
with quotes, code and an image (Edit Scheme › Run › Arguments).

## Tests

```sh
xcodebuild test -project SinoDefence.xcodeproj -scheme SinoDefence \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

The suite covers the HTML DOM, XenForo forum-index parsing, New posts and board
lists, thread/post parsing, quotes/code/images, posting forms, moderator
detection, BBCode-to-HTML conversion and date/number handling.

## How it works

| Layer | File | Notes |
| --- | --- | --- |
| Tolerant HTML DOM | `Core/HTMLDocument.swift` | Dependency-free parser with entity decoding and auto-closing of `p`/`li`/`td` |
| XenForo page parsing | `Core/XFParser.swift` | Forum index, New posts, board lists, threads, posts, pagination, dates |
| Post rendering | `Core/PostRenderer.swift` | XenForo HTML → native `AttributedString`, quote/code/image/video blocks |
| Networking | `Core/XFClient.swift` | Scraped login, cookie jar, posting forms, moderation endpoints, error mapping |
| Composer conversion | `Core/BBCodeHTML.swift` | BBCode toolbar output → XenForo editor HTML |
| State | `Core/Session.swift`, `Core/ViewModels.swift` | Signed-in/guest state, boards, paginated lists, moderation state |
| UI | `UI/` | Login, dynamic tabs, lists, thread view, composer, settings |

### Login

Fetch `/login/`, read `_xfToken` and every hidden field from the login form, post
`login` / `password` / `remember=1`, then confirm the session by reading
`data-logged-in="true"` and the member link in the header. If XenForo returns
its "You are already logged in" message instead of a form, the existing session
is adopted rather than reported as a parsing error. No credentials are sent
anywhere except `https://www.sinodefenceforum.com/`.

### Posting

XenForo's editor submits HTML. The app fetches the real reply or new-thread
form (for the token and endpoint), converts the BBCode draft to the matching
HTML subset, and posts it with `_xfResponseType=json`. XenForo 2.3 uses
`/add-reply` and `/add-thread` endpoints with a `message_html` field, while
older forms use `message`; both are handled. Server errors are shown inline and
the draft is kept.

### Moderation

The app treats XenForo's own controls as the source of truth: a thread exposing
inline-mod checkboxes or thread-tools links is marked moderatable. Stick, unstick,
lock and unlock use XenForo's `/inline-mod/` endpoint with the same
`xf_inlinemod_thread` selection cookie as the website; Move and Delete use the
thread's moderator endpoints; Delete Post uses `/posts/<id>/delete`. Permission
is re-checked by the server on every action.

## Verified against the live forum

Tested against the live site on 1 November 2026 on iPhone 18 Pro and iPhone 13
mini: 3 categories / 12 visible top-level forums, New posts, distinct board
lists, threads with quotes and attachment images, attachment-page fallback,
inline image loading, Settings, and live pagination.

The exact post
`/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360339` was used to
verify that XenForo's empty `data-url=""` attachment markup now renders its
photo instead of leaving a blank line.

## Limitations

- **Unofficial.** Not affiliated with the forum or its operators. Respect the
  forum's rules and rate limits.
- Posting supports text, quotes, links, images by URL, formatting, lists,
  spoilers, YouTube and file/photo attachments; polls and advanced attachment
  management still use the web view.
- Search, alerts, conversations, profile editing and account settings are
  available through "Open in Browser".
- Parsing follows XenForo 2.3's stock public templates. A custom theme or a
  XenForo upgrade can require selector updates.
- Moderator actions require an account with the corresponding permission; the
  app hides them when XenForo does not expose the controls.
- Signatures, custom fields and reactions are intentionally not rendered in the
  native thread view.
- Forum-hosted attachment pictures are restricted to signed-in members by the
  forum itself. Guest mode shows a "Sign in to view picture" placeholder for
  those; external pictures still load for guests.
- `Info.plist` permits HTTP loads because many older inline pictures use
  `http://` image hosts (the forum itself is always requested over HTTPS).
