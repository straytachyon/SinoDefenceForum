import Foundation
import Testing
import UIKit
@testable import SinoDefence

// MARK: - Fixtures
//
// Markup mirrors XenForo 2.3's stock public templates (`forum_list`,
// `forum_view`, `thread_view`, `whats_new_posts`). Keeping the fixtures close
// to the real templates is what makes these tests meaningful.

enum Fixtures {
    static let forumIndex = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body data-template="forum_list">
    <div class="block" data-xf-init="inline-mod" data-type="thread"></div>
    <div class="p-navgroup p-navgroup--member">
        <a href="/members/demo_user.42/" class="p-navgroup-link p-navgroup-link--user"><span class="p-navgroup-linkText">demo_user</span></a>
    </div>
    <div class="block block--category block--category5">
        <div class="block-container">
            <h2 class="block-header"><a href="/#china-defense-military.5">China Defense &amp; Military</a></h2>
            <div class="block-body">
                <div class="node node--id8 node--depth2 node--forum node--unread">
                    <div class="node-body"><div class="node-main">
                        <h3 class="node-title"><a href="/f/air-force.8/">Air Force</a></h3>
                        <div class="node-description">Chinese Air Force and PLAAF weapons technology.</div>
                        <div class="node-stats">
                            <dl class="pairs"><dt>Threads</dt><dd>1.1K</dd></dl>
                            <dl class="pairs"><dt>Messages</dt><dd>112.7K</dd></dl>
                        </div>
                    </div></div>
                </div>
                <div class="node node--id9 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main">
                        <h3 class="node-title"><a href="/f/navy.9/">Navy</a></h3>
                        <div class="node-description">Chinese naval forces and warships.</div>
                        <div class="node-stats">
                            <dl class="pairs"><dt>Threads</dt><dd>1,432</dd></dl>
                            <dl class="pairs"><dt>Messages</dt><dd>168,912</dd></dl>
                        </div>
                    </div></div>
                </div>
            </div>
        </div>
    </div>
    <div class="block block--category block--category11">
        <div class="block-container">
            <h2 class="block-header"><a href="/#world-strategic.11">World Strategic Defence Area</a></h2>
            <div class="block-body">
                <div class="node node--id12 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main">
                        <h3 class="node-title"><a href="/f/world-armed-forces.12/">World Armed Forces</a></h3>
                        <div class="node-description">World armed forces topics and military news.</div>
                        <div class="node-stats">
                            <dl class="pairs"><dt>Threads</dt><dd>780</dd></dl>
                            <dl class="pairs"><dt>Messages</dt><dd>62.1K</dd></dl>
                        </div>
                    </div></div>
                </div>
                <div class="node node--id13 node--depth2 node--link">
                    <div class="node-body"><div class="node-main">
                        <h3 class="node-title"><a href="/link-forums/defencetalk-com.13/">DefenceTalk.com</a></h3>
                        <div class="node-description">An external partner site.</div>
                    </div></div>
                </div>
            </div>
        </div>
    </div>
    </body></html>
    """

    static let newPosts = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body data-template="whats_new_posts">
    <div class="p-body-header"><div class="p-title"><h1 class="p-title-value">New posts</h1></div></div>
    <div class="block" data-xf-init="inline-mod" data-type="thread" data-href="/inline-mod/">
    <div class="block-outer"><nav class="pageNavWrapper">
        <div class="pageNav">
            <ul class="pageNav-main">
                <li class="pageNav-page pageNav-page--current"><a href="/whats-new/posts/6885400/">1</a></li>
                <li class="pageNav-page"><a href="/whats-new/posts/6885400/page-2">2</a></li>
                <li class="pageNav-page"><a href="/whats-new/posts/6885400/page-3">3</a></li>
            </ul>
            <div class="menu-row"><input type="number" class="js-pageJumpPage" value="1" min="1" max="15" /></div>
        </div>
    </nav></div></div>
    <div class="block-container"><div class="block-body"><div class="structItemContainer">
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-8048" data-author="Demo Moderator">
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--sticky"></i><span class="u-srOnly">Sticky</span></li></ul>
                <div class="structItem-title"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/unread" data-tp-primary="on">CV-18 Fujian/003 CATOBAR carrier thread</a></div>
                <div class="structItem-minor">
                    <ul class="structItem-parts">
                        <li><a href="/members/demo-moderator.1/" class="username"><span class="username--moderator">Demo Moderator</span></a></li>
                        <li class="structItem-startDate"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/"><time class="u-dt" datetime="2016-08-01T12:43:30-0400">Aug 1, 2016</time></a></li>
                        <li><a href="/f/navy.9/">Navy</a></li>
                    </ul>
                    <span class="structItem-pageJump"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1228">1228</a><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1230">1230</a></span>
                </div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>12K</dd></dl><dl class="pairs"><dt>Views</dt><dd>8M</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest">
                <a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/latest"><time class="u-dt" datetime="2026-11-01T01:09:19-0400" data-date="Nov 1, 2026" data-time="1:09 AM">8 minutes ago</time></a>
                <div class="structItem-minor"><a href="/members/demo-member.2/" class="username">Demo Member</a></div>
            </div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-6744" data-author="RulesKeeper">
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--locked"></i><span class="u-srOnly">Locked</span></li></ul>
                <div class="structItem-title"><a href="/t/sinodefence-forum-rules-of-behavior.6744/" data-tp-primary="on">Sinodefence forum rules of behavior</a></div>
                <div class="structItem-minor"><ul class="structItem-parts">
                    <li><a href="/members/ruleskeeper.4/" class="username">RulesKeeper</a></li>
                    <li class="structItem-startDate"><a href="/t/sinodefence-forum-rules-of-behavior.6744/"><time class="u-dt" datetime="2014-01-18T15:12:54-0500">Jan 18, 2014</time></a></li>
                    <li><a href="/f/announcements.2/">Announcements</a></li>
                </ul></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>18</dd></dl><dl class="pairs"><dt>Views</dt><dd>82K</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/sinodefence-forum-rules-of-behavior.6744/latest"><time class="u-dt" datetime="2026-09-12T09:00:00-0400">Sep 12, 2026</time></a><div class="structItem-minor"><a href="/members/ruleskeeper.4/" class="username">RulesKeeper</a></div></div>
        </div>
    </div></div></div>
    </div>
    </body></html>
    """

    static let thread = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body data-template="thread_view">
    <ul class="p-breadcrumbs">
        <li><a href="/">Home</a></li>
        <li><a href="/f/navy.9/">Navy</a></li>
    </ul>
    <div class="p-body-header"><div class="p-title"><h1 class="p-title-value">CV-18 Fujian/003 CATOBAR carrier thread</h1></div></div>
    <div class="block" data-xf-init="inline-mod" data-type="post" data-href="/inline-mod/">
    <div class="block-outer"><nav class="pageNav"><ul class="pageNav-main">
        <li class="pageNav-page pageNav-page--current"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1230">1230</a></li>
    </ul><input type="number" class="js-pageJumpPage" value="1230" max="1230"></nav></div>
    <div class="block-container"><div class="block-body">
        <article class="message message--post js-post js-inlineModContainer" data-author="Demo Moderator" data-content="post-1360340" id="js-post-1360340">
            <span class="u-anchorTarget" id="post-1360340"></span>
            <div class="message-cell message-cell--user"><section class="message-user">
                <div class="message-avatar"><a href="/members/demo-moderator.1/" class="avatar"><img src="" alt="Demo Moderator"></a></div>
                <div class="message-userDetails">
                    <h4 class="message-name"><a href="/members/demo-moderator.1/" class="username" data-user-id="1"><span class="username--staff username--moderator">Demo Moderator</span></a></h4>
                    <h5 class="userTitle message-userTitle">Colonel</h5>
                    <div class="userBanner message-userBanner"><strong>VIP Professional</strong></div>
                </div>
            </section></div>
            <div class="message-cell message-cell--main">
                <header class="message-attribution">
                    <ul class="message-attribution-main"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360340"><time class="u-dt" datetime="2026-11-01T01:09:19-0400" data-date="Nov 1, 2026" data-time="1:09 AM">8 minutes ago</time></a></li></ul>
                    <ul class="message-attribution-opposite"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360340">#1</a></li></ul>
                </header>
                <div class="message-content"><div class="message-userContent"><article class="message-body js-selectToQuote"><div><div class="bbWrapper">
                    <p>Fujian has completed another round of sea trials.</p>
                    <blockquote data-attributes="" data-quote="Demo Member" data-source="post: 1360300" class="bbCodeBlock bbCodeBlock--quote">
                        <div class="bbCodeBlock-title"><a href="/goto/post?id=1360300">Demo Member said:</a></div>
                        <div class="bbCodeBlock-content"><div class="bbCodeBlock-expandContent">The next milestone should be the first operational deployment.</div></div>
                    </blockquote>
                    <div class="bbImageWrapper"><a href="https://www.sinodefenceforum.com/attachments/fujian-jpg.179560/"><img src="https://www.sinodefenceforum.com/data/attachments/173/fujian.jpg" class="bbImage" alt="Fujian"></a></div>
                    <pre class="bbCodeBlock bbCodeBlock--code"><code class="bbCodeCode">hull = 003</code></pre>
                </div></div></article></div></div>
            </div>
        </article>
    </div></div></div>
    </div>
    </body></html>
    """

    static let lockedThread = thread.replacingOccurrences(
        of: "<div class=\"block-outer\"><nav class=\"pageNav\">",
        with: "<div class=\"block-outer\"><dl class=\"blockStatus\"><dd class=\"blockStatus-message blockStatus-message--locked\">Not open for further replies.</dd></dl><nav class=\"pageNav\">"
    )

    static let guestPage = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="false" data-csrf="1793510000,guest">
    <body data-template="forum_list">
    <div class="p-navgroup p-navgroup--guest"><a href="/login/">Log in</a></div>
    </body></html>
    """

    static let loginError = """
    <div class="blockMessage blockMessage--error blockMessage--iconic">The requested user 'nobody' could not be found.</div>
    <form action="/login/login" method="post"><input type="hidden" name="_xfToken" value="123,abc"></form>
    """

    static let loginPage = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="false">
    <body>
    <form action="/login/login" method="post" class="block">
        <input type="hidden" name="_xfToken" value="123,abc">
        <input type="hidden" name="_xfRedirect" value="https://www.sinodefenceforum.com/">
        <input type="text" name="login" value="">
        <input type="password" name="password" value="">
        <input type="checkbox" name="remember" value="1" checked="checked">
        <button type="submit">Log in</button>
    </form>
    </body></html>
    """

    static let replyForm = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body>
    <form action="/threads/8048/reply" method="post" class="block">
        <input type="hidden" name="_xfToken" value="1793510000,abc">
        <input type="hidden" name="_xfResponseType" value="json">
        <textarea name="message" class="input"><p>Quoted text</p></textarea>
        <button type="submit">Post reply</button>
    </form>
    </body></html>
    """

    static let newThreadForm = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body>
    <form action="/forums/8/post-thread" method="post" class="block">
        <input type="hidden" name="_xfToken" value="1793510000,abc">
        <input type="text" name="title" value="">
        <textarea name="message" class="input"></textarea>
        <button type="submit">Post thread</button>
    </form>
    </body></html>
    """

    static let replyForm23 = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body>
    <form action="/t/cv-18-fujian-003-catobar-carrier-thread.8048/add-reply" method="post" class="block">
        <input type="hidden" name="_xfToken" value="1793510000,xyz">
        <input type="hidden" name="attachment_hash" value="attachhash123">
        <a class="button js-attachmentUpload" href="/attachments/upload?type=post&amp;context[thread_id]=8048&amp;hash=attachhash123">Attach files</a>
        <textarea name="message_html" class="input js-editor"></textarea>
        <noscript><textarea name="message"></textarea></noscript>
        <button type="submit">Post reply</button>
    </form>
    </body></html>
    """

    static let newThreadForm23 = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,abc">
    <body>
    <form action="/forums/air-force.8/add-thread" method="post" class="block">
        <input type="hidden" name="_xfToken" value="1793510000,xyz">
        <input type="text" name="title" value="">
        <textarea name="message_html" class="input js-editor"></textarea>
        <button type="submit">Post thread</button>
    </form>
    </body></html>
    """
}

// MARK: - Account / forum structure

struct AccountParsingTests {
    @Test func parsesCurrentMember() {
        let user = XFParser.parseCurrentUser(in: Fixtures.forumIndex)
        #expect(user?.id == 42)
        #expect(user?.name == "demo_user")
        #expect(user?.isModerator == true)
    }

    @Test func detectsGuestSession() {
        #expect(XFParser.parseCurrentUser(in: Fixtures.guestPage) == nil)
    }

    @Test func parsesCategoriesAndTopLevelForums() {
        let result = XFParser.parseForumIndex(Fixtures.forumIndex)
        #expect(result.categories.count == 2)
        #expect(result.categories[0].name == "China Defense & Military")
        #expect(result.categories[0].boards.map(\.name) == ["Air Force", "Navy"])
        #expect(result.categories[1].boards.map(\.name) == ["World Armed Forces", "DefenceTalk.com"])
        #expect(result.boards.first { $0.id == 8 }?.slug == "air-force")
        #expect(result.boards.first { $0.id == 13 }?.isLink == true)
    }

    @Test func readsForumCountsAndDescriptions() {
        let result = XFParser.parseForumIndex(Fixtures.forumIndex)
        let airForce = result.boards.first { $0.id == 8 }
        #expect(airForce?.topicCount == 1100)
        #expect(airForce?.postCount == 112700)
        #expect(airForce?.summary == "Chinese Air Force and PLAAF weapons technology.")
        #expect(airForce?.isUnread == true)
    }
}

// MARK: - Topic lists

struct TopicListParsingTests {
    @Test func parsesNewPosts() {
        let page = XFParser.parseTopicList(Fixtures.newPosts, pageHint: 1)
        #expect(page.topics.count == 2)
        #expect(page.topics[0].id == 8048)
        #expect(page.topics[0].slug == "cv-18-fujian-003-catobar-carrier-thread")
        #expect(page.topics[0].title == "CV-18 Fujian/003 CATOBAR carrier thread")
        #expect(page.topics[0].author == "Demo Moderator")
        #expect(page.topics[0].replyCount == 12000)
        #expect(page.topics[0].replyText == "12K")
        #expect(page.topics[0].pageCount == 1230)
        #expect(page.topics[0].boardName == "Navy")
        #expect(page.topics[0].isSticky)
        #expect(page.topics[0].isUnread)
        #expect(page.topics[0].lastPoster == "Demo Member")
    }

    @Test func readsLockedStatusAndPagination() {
        let page = XFParser.parseTopicList(Fixtures.newPosts)
        #expect(page.topics[1].isLocked)
        #expect(page.topics[1].isUnread == false)
        #expect(page.currentPage == 1)
        #expect(page.pageCount == 15)
        #expect(page.canModerate)
    }

    @Test func parsesCompactNumbers() {
        #expect(XFParser.compactNumber("12K") == 12000)
        #expect(XFParser.compactNumber("1.1K") == 1100)
        #expect(XFParser.compactNumber("8M") == 8_000_000)
        #expect(XFParser.compactNumber("1,432") == 1432)
    }
}

// MARK: - Threads and posts

struct ThreadParsingTests {
    @Test func parsesThreadHeaderAndPosts() {
        let page = XFParser.parseThread(Fixtures.thread, topicID: 8048, slug: "cv-18-fujian-003-catobar-carrier-thread")
        #expect(page.title == "CV-18 Fujian/003 CATOBAR carrier thread")
        #expect(page.posts.count == 1)
        #expect(page.posts[0].id == 1360340)
        #expect(page.posts[0].author == "Demo Moderator")
        #expect(page.posts[0].authorID == 1)
        #expect(page.posts[0].postNumber == 1)
        #expect(page.posts[0].userTitle == "Colonel")
        #expect(page.posts[0].banners == ["VIP Professional"])
        #expect(page.posts[0].isStaff)
        #expect(page.boardName == "Navy")
        #expect(page.boardID == 9)
        #expect(page.pageCount == 1230)
        #expect(page.canModerate)
        #expect(page.csrfToken == "1793510000,abc")
    }

    @Test func rendersQuotesCodeAndImages() {
        let page = XFParser.parseThread(Fixtures.thread, topicID: 8048)
        let blocks = page.posts[0].content.blocks
        #expect(blocks.contains { if case .quote = $0 { return true }; return false })
        #expect(blocks.contains { if case .code = $0 { return true }; return false })
        #expect(blocks.contains { if case .image = $0 { return true }; return false })
        let imageURL: URL? = page.posts[0].content.blocks.compactMap { block in
            if case .image(let url) = block { return url }
            return nil
        }.first
        #expect(imageURL?.absoluteString.contains("/data/attachments/") == true)
        #expect(imageURL?.absoluteString.contains("/attachments/fujian-jpg") == false)
    }

    @Test func detectsLockedThread() {
        let page = XFParser.parseThread(Fixtures.lockedThread, topicID: 8048)
        #expect(page.isLocked)
    }

    @Test func parsesPostingTimestamps() {
        let date = XFParser.parseDate("2026-11-01T01:09:19-0400")
        #expect(date != nil)
    }
}

// MARK: - Posting forms

struct PostingFormTests {
    @Test func parsesReplyForm() {
        let form = XFParser.parsePostForm(Fixtures.replyForm, fallbackTopicID: 8048)
        #expect(form?.action.absoluteString == "https://www.sinodefenceforum.com/threads/8048/reply")
        #expect(form?.topicID == 8048)
        #expect(form?.csrfToken == "1793510000,abc")
        #expect(form?.messageHTML.contains("Quoted text") == true)
    }

    @Test func parsesNewThreadForm() {
        let form = XFParser.parsePostForm(Fixtures.newThreadForm, fallbackBoardID: 8)
        #expect(form?.boardID == 8)
        #expect(form?.csrfToken == "1793510000,abc")
    }

    @Test func readsLoginError() {
        #expect(XFParser.errorMessage(in: Fixtures.loginError) == "The requested user 'nobody' could not be found.")
    }

    @Test func parsesLoginFormToken() {
        #expect(XFParser.csrf(in: Fixtures.loginPage) == "123,abc")
    }

    @Test func parsesXenForo23ReplyForm() {
        let form = XFParser.parsePostForm(Fixtures.replyForm23, fallbackTopicID: 8048)
        #expect(form?.action.absoluteString.hasSuffix("/add-reply") == true)
        #expect(form?.topicID == 8048)
        #expect(form?.messageField == "message_html")
        #expect(form?.csrfToken == "1793510000,xyz")
        #expect(form?.attachmentHash == "attachhash123")
        #expect(form?.attachmentUploadURL?.absoluteString.contains("/attachments/upload") == true)
        #expect(form?.attachmentUploadURL?.absoluteString.contains("thread_id") == true)
    }

    @Test func parsesXenForo23NewThreadForm() {
        let form = XFParser.parsePostForm(Fixtures.newThreadForm23, fallbackBoardID: 8)
        #expect(form?.action.absoluteString.hasSuffix("/add-thread") == true)
        #expect(form?.boardID == 8)
        #expect(form?.messageField == "message_html")
    }
}

// MARK: - BBCode / renderer

struct ContentRenderingTests {
    @Test func convertsBBCodeToXenForoHTML() {
        let html = BBCodeHTML.convert("[b]Bold[/b] and [quote=\"Observer\"]Quoted[/quote]")
        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains("bbCodeBlock--quote"))
        #expect(html.contains("Observer"))
    }

    @Test func escapesPlainText() {
        let html = BBCodeHTML.convert("<script>alert(1)</script>")
        #expect(html.contains("&lt;script&gt;"))
        #expect(!html.contains("<script>alert(1)</script>"))
    }

    @Test func convertsYouTubeShortcode() {
        let html = BBCodeHTML.convert("[youtube]4iZ75mbX6mY[/youtube]")
        #expect(html.contains("youtube.com/embed/4iZ75mbX6mY"))
    }

    @Test func extractsYouTubeIDs() {
        #expect(PostRenderer.youTubeID(from: URL(string: "https://youtu.be/4iZ75mbX6mY")!) == "4iZ75mbX6mY")
        #expect(PostRenderer.youTubeID(from: URL(string: "https://www.youtube.com/watch?v=4iZ75mbX6mY")!) == "4iZ75mbX6mY")
        #expect(PostRenderer.youTubeID(from: URL(string: "https://example.com/video")!) == nil)
    }

    @Test func acceptsExtensionlessXenForoImages() {
        let html = """
        <div class="bbWrapper"><p>Photo:</p>
        <div class="bbImageWrapper"><img src="https://pbs.twimg.com/media/ABC123?format=jpg&name=small" class="bbImage"></div>
        </div>
        """
        let content = PostRenderer.render(html: html)
        let urls: [URL] = content.blocks.compactMap { block in
            if case .image(let url) = block { return url }
            return nil
        }
        #expect(urls.count == 1)
        #expect(urls.first?.absoluteString.contains("pbs.twimg.com") == true)
    }

    @Test func fallsBackWhenXenForoDataURLIsEmpty() {
        let pageURL = "https://www.sinodefenceforum.com/attachments/model-jpg.183223/"
        let html = """
        <div class="bbWrapper"><p>Photo:</p>
        <div class="bbImageWrapper" data-src="\(pageURL)">
        <img src="\(pageURL)" data-url="" class="bbImage" width="201" height="125">
        </div></div>
        """
        let content = PostRenderer.render(html: html)
        let urls: [URL] = content.blocks.compactMap { block in
            if case .image(let url) = block { return url }
            return nil
        }
        #expect(urls.count == 1)
        #expect(urls.first?.absoluteString == pageURL)
    }

    @Test func preservesPostTextScaleAttribute() {
        let content = PostRenderer.render(html: "<p>Hello <strong>world</strong></p>")
        #expect(String(content.text.characters).contains("Hello world"))
        let scaled = content.text.scaledForPostText(1.5)
        #expect(String(scaled.characters).contains("Hello world"))
    }
}










