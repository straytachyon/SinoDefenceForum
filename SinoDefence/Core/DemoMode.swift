#if DEBUG
import Foundation

/// Launch-argument driven demo data (`-demo`). Debug builds only: it lets the UI
/// be exercised end to end without forum credentials, and because the fixtures
/// are parsed by the real `XFParser` it also smoke-tests the parsing pipeline.
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    static func boardIndex() -> BoardIndexResult {
        XFParser.parseForumIndex(boardIndexHTML)
    }

    static func topicList(mode: TopicListModel.Mode, page: Int) -> TopicListPage {
        switch mode {
        case .newPosts:
            return XFParser.parseTopicList(newPostsHTML, pageHint: page)
        case .board(let board):
            return XFParser.parseTopicList(boardHTML(for: board), pageHint: page)
        }
    }

    private static let demoTitles: [String: [String]] = [
        "Announcements": [
            "Forum rules and updates",
            "Banned & Warned Members List",
            "Welcome to Sino Defence Forum",
        ],
        "Feedback & Suggestions": [
            "Reporting Problems",
            "SD Forum suggestions and questions",
            "Sinodefence forum rules of behavior",
        ],
        "Strategic Defense": [
            "China's Space Program Thread II",
            "Chinese Hypersonic Developments (HGVs/HCMs)",
            "DF-27 range estimates",
        ],
        "Army": [
            "PLA Small arms",
            "PLA Ground Forces news, pics and videos",
            "QBZ-191 service rifle family",
        ],
        "Air Force": [
            "H-20 bomber (with H-X, JH-XX)",
            "J-35A fighter (PLAAF) + FC-31",
            "Chinese UCAV/CCA/flying wing drones",
        ],
        "Navy": [
            "CV-18 Fujian/003 CATOBAR carrier thread",
            "PLAN test and experimental vessels",
            "Next Generation DDG and FFG thread",
        ],
        "Military History": [
            "Military history reference thread",
            "PLA in the 1980s",
            "The Korean War in photographs",
        ],
        "Professional Discussions": [
            "Professional discussion guidelines",
            "Carrier aviation analysis",
            "Naval doctrine and procurement",
        ],
        "Members' Club Room": [
            "Introduce yourself",
            "Members' lounge",
            "Off-topic conversation",
        ],
        "World Armed Forces": [
            "The War in the Ukraine",
            "Russian Military News, Reports, Data, etc.",
            "US Military News, Reports, Data, etc.",
        ],
        "General Pictures": [
            "World Pictures/Videos of the Day",
            "US daily photos and videos",
            "Aircraft photography",
        ],
        "World Military Pictures": [
            "US Military Pictures/Videos",
            "Chinese military photos",
            "Naval photography",
        ],
    ]

    private static func boardHTML(for board: BoardTarget) -> String {
        var html = boardTopicsHTML
        html = html.replacingOccurrences(
            of: "<h1 class=\"p-title-value\">Air Force</h1>",
            with: "<h1 class=\"p-title-value\">\(board.name)</h1>"
        )
        html = html.replacingOccurrences(
            of: "Forum for Chinese Air Force, military aviation news, PLAAF weapons technology and warfare.",
            with: board.summary.isEmpty ? "Demo forum: \(board.name)" : board.summary
        )
        let originals = [
            "H-20 bomber (with H-X, JH-XX)",
            "J-35A fighter (PLAAF) + FC-31",
            "Shenyang next-gen combat aircraft (J-XDS)",
        ]
        let titles = demoTitles[board.name] ?? [
            "\(board.name) discussion",
            "\(board.name) news and updates",
            "\(board.name) reference thread",
        ]
        for (original, replacement) in zip(originals, titles) {
            html = html.replacingOccurrences(of: original, with: replacement)
        }
        return html
    }

    static func topic(id: Int, title: String, slug: String, page: Int) -> TopicPage {
        var html = threadHTML
        if !title.isEmpty {
            html = html.replacingOccurrences(of: "CV-18 Fujian/003 CATOBAR carrier thread", with: title)
        }
        return XFParser.parseThread(html, topicID: id, slug: slug, pageHint: page)
    }

    // MARK: - Fixtures (XenForo 2.3 public templates)

    private static let boardIndexHTML = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,demo">
    <body data-template="forum_list">
    <div class="p-navgroup p-navgroup--member">
        <a href="/members/demo_user.42/" class="p-navgroup-link p-navgroup-link--user" data-xf-init="member-tooltip">
            <span class="p-navgroup-linkText">demo_user</span>
        </a>
    </div>
    <div class="block block--category block--category14">
        <span class="u-anchorTarget" id="management-area.14"></span>
        <div class="block-container">
            <h2 class="block-header"><a href="/#management-area.14">Management Area</a><span class="block-desc">SinoDefence Forum Management</span></h2>
            <div class="block-body">
                <div class="node node--id2 node--depth2 node--forum node--unread">
                    <div class="node-body">
                        <span class="node-icon"><i class="fa--xf far fa-comments"></i></span>
                        <div class="node-main js-nodeMain">
                            <h3 class="node-title"><a href="/f/announcements.2/">Announcements</a></h3>
                            <div class="node-description">SinoDefence Forum important Announcements and News.</div>
                            <div class="node-meta"><div class="node-statsMeta">
                                <dl class="pairs pairs--inline"><dt>Threads</dt><dd>26</dd></dl>
                                <dl class="pairs pairs--inline"><dt>Messages</dt><dd>1.7K</dd></dl>
                            </div></div>
                        </div>
                        <div class="node-stats">
                            <dl class="pairs pairs--rows"><dt>Threads</dt><dd>26</dd></dl>
                            <dl class="pairs pairs--rows"><dt>Messages</dt><dd>1.7K</dd></dl>
                        </div>
                    </div>
                </div>
                <div class="node node--id15 node--depth2 node--forum">
                    <div class="node-body">
                        <div class="node-main js-nodeMain">
                            <h3 class="node-title"><a href="/f/feedback-suggestions.15/">Feedback &amp; Suggestions</a></h3>
                            <div class="node-description">Please provide your feedback and suggestions that would help us improve this forum.</div>
                            <div class="node-stats"><dl><dt>Threads</dt><dd>280</dd></dl><dl><dt>Messages</dt><dd>4.2K</dd></dl></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="block block--category block--category5">
        <span class="u-anchorTarget" id="china-defense-military.5"></span>
        <div class="block-container">
            <h2 class="block-header"><a href="/#china-defense-military.5">China Defense &amp; Military</a><span class="block-desc">Discussions on Chinese defence and armed forces</span></h2>
            <div class="block-body">
                <div class="node node--id6 node--depth2 node--forum node--unread">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/strategic-defense.6/">Strategic Defense</a></h3>
                        <div class="node-description">Chinese space programme, WMD, C4ISR, defence industry and arms trade.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>602</dd></dl><dl><dt>Messages</dt><dd>126.4K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id7 node--depth2 node--forum node--unread">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/army.7/">Army</a></h3>
                        <div class="node-description">Chinese Ground Forces, the People's Armed Police and special forces.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>1.2K</dd></dl><dl><dt>Messages</dt><dd>88.3K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id8 node--depth2 node--forum node--unread">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/air-force.8/">Air Force</a></h3>
                        <div class="node-description">Chinese Air Force, military aviation news, PLAAF weapons technology and warfare.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>1.1K</dd></dl><dl><dt>Messages</dt><dd>112.7K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id9 node--depth2 node--forum node--unread">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/navy.9/">Navy</a></h3>
                        <div class="node-description">Chinese naval forces news, aircraft carriers, warships and naval weapon systems.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>1.4K</dd></dl><dl><dt>Messages</dt><dd>168.9K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id10 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/military-history.10/">Military History</a></h3>
                        <div class="node-description">Chinese military history, armed forces and weapons technology history.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>410</dd></dl><dl><dt>Messages</dt><dd>31.2K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id4 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/professional-discussions.4/">Professional Discussions</a></h3>
                        <div class="node-description">Professional discussions; only VIP members can post here.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>88</dd></dl><dl><dt>Messages</dt><dd>5.4K</dd></dl></div>
                    </div></div>
                </div>
            </div>
        </div>
    </div>
    <div class="block block--category block--category11">
        <div class="block-container">
            <h2 class="block-header"><a href="/#world-strategic-defence.11">World Strategic Defence Area</a><span class="block-desc">World defence discussions in general</span></h2>
            <div class="block-body">
                <div class="node node--id18 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/members-club-room.18/">Members' Club Room</a></h3>
                        <div class="node-description">Grab a drink, put your feet up and make new friends.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>330</dd></dl><dl><dt>Messages</dt><dd>14.8K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id12 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/world-armed-forces.12/">World Armed Forces</a></h3>
                        <div class="node-description">World armed forces topics and world military news.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>780</dd></dl><dl><dt>Messages</dt><dd>62.1K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id31 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/general-pictures.31/">General Pictures</a></h3>
                        <div class="node-description">Share and post non-military pictures here.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>96</dd></dl><dl><dt>Messages</dt><dd>12.5K</dd></dl></div>
                    </div></div>
                </div>
                <div class="node node--id23 node--depth2 node--forum">
                    <div class="node-body"><div class="node-main js-nodeMain">
                        <h3 class="node-title"><a href="/f/world-military-pictures.23/">World Military Pictures</a></h3>
                        <div class="node-description">Global military pictures, media and world armed forces imagery.</div>
                        <div class="node-stats"><dl><dt>Threads</dt><dd>210</dd></dl><dl><dt>Messages</dt><dd>28.4K</dd></dl></div>
                    </div></div>
                </div>
            </div>
        </div>
    </div>
    </body></html>
    """

    private static let newPostsHTML = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,demo">
    <body data-template="whats_new_posts">
    <div class="p-navgroup p-navgroup--member"><a href="/members/demo_user.42/" class="p-navgroup-link p-navgroup-link--user"><span class="p-navgroup-linkText">demo_user</span></a></div>
    <div class="p-body-header"><div class="p-title"><h1 class="p-title-value">New posts</h1></div></div>
    <div class="block" data-xf-init="inline-mod" data-type="thread" data-href="/inline-mod/">
    <div class="block-outer"><div class="block-outer-main"><nav class="pageNavWrapper pageNavWrapper--mixed">
        <div class="pageNav">
            <ul class="pageNav-main">
                <li class="pageNav-page pageNav-page--current"><a href="/whats-new/posts/6885400/">1</a></li>
                <li class="pageNav-page"><a href="/whats-new/posts/6885400/page-2">2</a></li>
                <li class="pageNav-page"><a href="/whats-new/posts/6885400/page-3">3</a></li>
            </ul>
            <div class="menu-row" data-xf-init="page-jump"><input type="number" class="input js-pageJumpPage" value="1" min="1" max="15" /></div>
        </div>
    </nav></div></div>
    <div class="block-container"><div class="block-body"><div class="structItemContainer">
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-8048" data-author="Demo Moderator">
            <div class="structItem-cell structItem-cell--icon"><div class="structItem-iconContainer"><a href="/members/demo-moderator.1/" class="avatar avatar--s"><img src="" alt="Demo Moderator"></a></div></div>
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--sticky"></i><span class="u-srOnly">Sticky</span></li></ul>
                <div class="structItem-title"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/unread" data-tp-primary="on">CV-18 Fujian/003 CATOBAR carrier thread</a></div>
                <div class="structItem-minor">
                    <ul class="structItem-parts">
                        <li><a href="/members/demo-moderator.1/" class="username"><span class="username--moderator">Demo Moderator</span></a></li>
                        <li class="structItem-startDate"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/"><time class="u-dt" datetime="2016-08-01T12:43:30-0400" data-date="Aug 1, 2016" data-time="12:43 PM">Aug 1, 2016</time></a></li>
                        <li><a href="/f/navy.9/">Navy</a></li>
                    </ul>
                    <span class="structItem-pageJump"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1228">1228</a><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1230">1230</a></span>
                </div>
            </div>
            <div class="structItem-cell structItem-cell--meta">
                <dl class="pairs"><dt>Replies</dt><dd>12K</dd></dl>
                <dl class="pairs structItem-minor"><dt>Views</dt><dd>8M</dd></dl>
            </div>
            <div class="structItem-cell structItem-cell--latest">
                <a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/latest"><time class="u-dt" datetime="2026-11-01T01:09:19-0400" data-date="Nov 1, 2026" data-time="1:09 AM">8 minutes ago</time></a>
                <div class="structItem-minor"><a href="/members/demo-member.2/" class="username">Demo Member</a></div>
            </div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-6451" data-author="AirForceFan">
            <div class="structItem-cell structItem-cell--icon"><a href="/members/airforcefan.3/" class="avatar avatar--s"><img src="" alt="AirForceFan"></a></div>
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--sticky"></i><span class="u-srOnly">Sticky</span></li></ul>
                <div class="structItem-title"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/" data-tp-primary="on">H-20 bomber (with H-X, JH-XX)</a></div>
                <div class="structItem-minor">
                    <ul class="structItem-parts">
                        <li><a href="/members/airforcefan.3/" class="username">AirForceFan</a></li>
                        <li class="structItem-startDate"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/"><time class="u-dt" datetime="2013-06-15T11:11:50-0400" data-date="Jun 15, 2013" data-time="11:11 AM">Jun 15, 2013</time></a></li>
                        <li><a href="/f/air-force.8/">Air Force</a></li>
                    </ul>
                    <span class="structItem-pageJump"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/page-567">567</a><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/page-569">569</a></span>
                </div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>6K</dd></dl><dl class="pairs"><dt>Views</dt><dd>3M</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest">
                <a href="/t/h-20-bomber-with-h-x-jh-xx.6451/latest"><time class="u-dt" datetime="2026-10-31T17:39:41-0400" data-date="Oct 31, 2026" data-time="5:39 PM">Yesterday at 5:39 PM</time></a>
                <div class="structItem-minor"><a href="/members/demo-member.2/" class="username">Demo Member</a></div>
            </div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-9084" data-author="SpaceWatcher">
            <div class="structItem-cell structItem-cell--icon"><a href="/members/spacewatcher.6/" class="avatar avatar--s"><span>N</span></a></div>
            <div class="structItem-cell structItem-cell--main">
                <div class="structItem-title"><a href="/t/chinese-manned-moon-missions-landing-base-etc.9084/" data-tp-primary="on">Chinese Manned Moon Missions (landing, base, etc)</a></div>
                <div class="structItem-minor"><ul class="structItem-parts">
                    <li><a href="/members/spacewatcher.6/" class="username">SpaceWatcher</a></li>
                    <li class="structItem-startDate"><a href="/t/chinese-manned-moon-missions-landing-base-etc.9084/"><time class="u-dt" datetime="2023-05-29T10:22:00-0400" data-date="May 29, 2023" data-time="10:22 AM">May 29, 2023</time></a></li>
                    <li><a href="/f/strategic-defense.6/">Strategic Defense</a></li>
                </ul><span class="structItem-pageJump"><a href="/t/chinese-manned-moon-missions-landing-base-etc.9084/page-114">114</a><a href="/t/chinese-manned-moon-missions-landing-base-etc.9084/page-116">116</a></span></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>2K</dd></dl><dl class="pairs"><dt>Views</dt><dd>940K</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/chinese-manned-moon-missions-landing-base-etc.9084/latest"><time class="u-dt" datetime="2026-11-01T00:51:00-0400" data-date="Nov 1, 2026" data-time="12:51 AM">27 minutes ago</time></a><div class="structItem-minor"><a href="/members/spacewatcher.6/" class="username">SpaceWatcher</a></div></div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-9131" data-author="F.L.">
            <div class="structItem-cell structItem-cell--icon"><a href="/members/f-l.51000/" class="avatar avatar--s"><span>F</span></a></div>
            <div class="structItem-cell structItem-cell--main">
                <div class="structItem-title"><a href="/t/plan-test-and-experimental-vessels.9131/" data-tp-primary="on">PLAN test and experimental vessels</a></div>
                <div class="structItem-minor"><ul class="structItem-parts">
                    <li><a href="/members/f-l.51000/" class="username">F.L.</a></li>
                    <li class="structItem-startDate"><a href="/t/plan-test-and-experimental-vessels.9131/"><time class="u-dt" datetime="2024-05-15T05:27:11-0400" data-date="May 15, 2024" data-time="5:27 AM">May 15, 2024</time></a></li>
                    <li><a href="/f/navy.9/">Navy</a></li>
                </ul></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>480</dd></dl><dl class="pairs"><dt>Views</dt><dd>102K</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/plan-test-and-experimental-vessels.9131/latest"><time class="u-dt" datetime="2026-10-31T23:48:00-0400" data-date="Oct 31, 2026" data-time="11:48 PM">2 hours ago</time></a><div class="structItem-minor"><a href="/members/f-l.51000/" class="username">F.L.</a></div></div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-9228" data-author="9dashline">
            <div class="structItem-cell structItem-cell--icon"><a href="/members/9dashline.3210/" class="avatar avatar--s"><span>9</span></a></div>
            <div class="structItem-cell structItem-cell--main">
                <div class="structItem-title"><a href="/t/artificial-intelligence-thread.9058/" data-tp-primary="on">Artificial Intelligence Thread</a></div>
                <div class="structItem-minor"><ul class="structItem-parts">
                    <li><a href="/members/9dashline.3210/" class="username">9dashline</a></li>
                    <li class="structItem-startDate"><a href="/t/artificial-intelligence-thread.9058/"><time class="u-dt" datetime="2023-03-30T14:40:28-0400" data-date="Mar 30, 2023" data-time="2:40 PM">Mar 30, 2023</time></a></li>
                    <li><a href="/f/strategic-defense.6/">Strategic Defense</a></li>
                </ul></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>1.4K</dd></dl><dl class="pairs"><dt>Views</dt><dd>410K</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/artificial-intelligence-thread.9058/latest"><time class="u-dt" datetime="2026-10-31T22:15:00-0400" data-date="Oct 31, 2026" data-time="10:15 PM">3 hours ago</time></a><div class="structItem-minor"><a href="/members/9dashline.3210/" class="username">9dashline</a></div></div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-6744" data-author="RulesKeeper">
            <div class="structItem-cell structItem-cell--icon"><a href="/members/ruleskeeper.4/" class="avatar avatar--s"><span>B</span></a></div>
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--locked"></i><span class="u-srOnly">Locked</span></li></ul>
                <div class="structItem-title"><a href="/t/sinodefence-forum-rules-of-behavior.6744/" data-tp-primary="on">Sinodefence forum rules of behavior</a></div>
                <div class="structItem-minor"><ul class="structItem-parts">
                    <li><a href="/members/ruleskeeper.4/" class="username">RulesKeeper</a></li>
                    <li class="structItem-startDate"><a href="/t/sinodefence-forum-rules-of-behavior.6744/"><time class="u-dt" datetime="2014-01-18T15:12:54-0500" data-date="Jan 18, 2014" data-time="3:12 PM">Jan 18, 2014</time></a></li>
                    <li><a href="/f/announcements.2/">Announcements</a></li>
                </ul></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>18</dd></dl><dl class="pairs"><dt>Views</dt><dd>82K</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/sinodefence-forum-rules-of-behavior.6744/latest"><time class="u-dt" datetime="2026-09-12T09:00:00-0400" data-date="Sep 12, 2026" data-time="9:00 AM">Sep 12, 2026</time></a><div class="structItem-minor"><a href="/members/ruleskeeper.4/" class="username">RulesKeeper</a></div></div>
        </div>
    </div></div></div>
    </div>
    </body></html>
    """

    private static let boardTopicsHTML = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,demo">
    <body data-template="forum_view">
    <div class="p-navgroup p-navgroup--member"><a href="/members/demo_user.42/" class="p-navgroup-link p-navgroup-link--user"><span class="p-navgroup-linkText">demo_user</span></a></div>
    <div class="p-body-header"><div class="p-title"><h1 class="p-title-value">Air Force</h1></div>
    <div class="p-description">Forum for Chinese Air Force, military aviation news, PLAAF weapons technology and warfare.</div></div>
    <div class="block" data-xf-init="inline-mod" data-type="thread" data-href="/inline-mod/">
    <div class="block-outer"><nav class="pageNav"><ul class="pageNav-main">
        <li class="pageNav-page pageNav-page--current"><a href="/f/air-force.8/">1</a></li>
        <li class="pageNav-page"><a href="/f/air-force.8/page-2">2</a></li>
        <li class="pageNav-page"><a href="/f/air-force.8/page-52">52</a></li>
    </ul><input type="number" class="input js-pageJumpPage" value="1" max="52"></nav></div>
    <div class="block-container"><div class="block-body"><div class="structItemContainer">
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-6451" data-author="AirForceFan">
            <div class="structItem-cell structItem-cell--main">
                <ul class="structItem-statuses"><li><i class="structItem-status structItem-status--sticky"></i><span class="u-srOnly">Sticky</span></li></ul>
                <div class="structItem-title"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/" data-tp-primary="on">H-20 bomber (with H-X, JH-XX)</a></div>
                <div class="structItem-minor"><ul class="structItem-parts"><li><a href="/members/airforcefan.3/" class="username">AirForceFan</a></li><li class="structItem-startDate"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/"><time class="u-dt" datetime="2013-06-15T11:11:50-0400">Jun 15, 2013</time></a></li></ul><span class="structItem-pageJump"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/page-569">569</a></span></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>6K</dd></dl><dl class="pairs"><dt>Views</dt><dd>3M</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/h-20-bomber-with-h-x-jh-xx.6451/latest"><time class="u-dt" datetime="2026-10-31T17:39:41-0400">Yesterday at 5:39 PM</time></a><div class="structItem-minor"><a href="/members/demo-member.2/" class="username">Demo Member</a></div></div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-9151" data-author="NavyWatcher">
            <div class="structItem-cell structItem-cell--main">
                <div class="structItem-title"><a href="/t/j-35a-fighter-plaaf-fc-31.9151/unread" data-tp-primary="on">J-35A fighter (PLAAF) + FC-31</a></div>
                <div class="structItem-minor"><ul class="structItem-parts"><li><a href="/members/navywatcher.5/" class="username">NavyWatcher</a></li><li class="structItem-startDate"><a href="/t/j-35a-fighter-plaaf-fc-31.9151/"><time class="u-dt" datetime="2023-11-06T09:41:00-0500">Nov 6, 2023</time></a></li></ul><span class="structItem-pageJump"><a href="/t/j-35a-fighter-plaaf-fc-31.9151/page-172">172</a></span></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>3K</dd></dl><dl class="pairs"><dt>Views</dt><dd>1M</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/j-35a-fighter-plaaf-fc-31.9151/latest"><time class="u-dt" datetime="2026-10-31T19:21:00-0400">Yesterday at 7:21 PM</time></a><div class="structItem-minor"><a href="/members/navywatcher.5/" class="username">NavyWatcher</a></div></div>
        </div>
        <div class="structItem structItem--thread js-inlineModContainer js-threadListItem-9158" data-author="latenlazy">
            <div class="structItem-cell structItem-cell--main">
                <div class="structItem-title"><a href="/t/shenyang-next-gen-combat-aircraft-j-xds.9158/" data-tp-primary="on">Shenyang next-gen combat aircraft (J-XDS)</a></div>
                <div class="structItem-minor"><ul class="structItem-parts"><li><a href="/members/latenlazy.4975/" class="username">latenlazy</a></li><li class="structItem-startDate"><a href="/t/shenyang-next-gen-combat-aircraft-j-xds.9158/"><time class="u-dt" datetime="2024-12-26T13:00:00-0500">Dec 26, 2024</time></a></li></ul><span class="structItem-pageJump"><a href="/t/shenyang-next-gen-combat-aircraft-j-xds.9158/page-211">211</a></span></div>
            </div>
            <div class="structItem-cell structItem-cell--meta"><dl class="pairs"><dt>Replies</dt><dd>4K</dd></dl><dl class="pairs"><dt>Views</dt><dd>2M</dd></dl></div>
            <div class="structItem-cell structItem-cell--latest"><a href="/t/shenyang-next-gen-combat-aircraft-j-xds.9158/latest"><time class="u-dt" datetime="2026-10-07T15:01:34-0400">Oct 7, 2026</time></a><div class="structItem-minor"><a href="/members/latenlazy.4975/" class="username">latenlazy</a></div></div>
        </div>
    </div></div></div>
    </div>
    </body></html>
    """

    private static let threadHTML = """
    <!DOCTYPE html>
    <html id="XF" data-logged-in="true" data-csrf="1793510000,demo">
    <body data-template="thread_view">
    <div class="p-navgroup p-navgroup--member"><a href="/members/demo_user.42/" class="p-navgroup-link p-navgroup-link--user"><span class="p-navgroup-linkText">demo_user</span></a></div>
    <ul class="p-breadcrumbs">
        <li><a href="/">Home</a></li>
        <li><a href="/f/navy.9/">Navy</a></li>
    </ul>
    <div class="p-body-header">
        <div class="p-title"><h1 class="p-title-value">CV-18 Fujian/003 CATOBAR carrier thread</h1></div>
        <div class="p-description"><ul class="listInline listInline--bullet">
            <li><a href="/members/demo-moderator.1/" class="username">Demo Moderator</a></li>
            <li><time class="u-dt" datetime="2016-08-01T12:43:30-0400">Aug 1, 2016</time></li>
        </ul></div>
    </div>
    <div class="block" data-xf-init="inline-mod" data-type="post" data-href="/inline-mod/">
    <div class="block-outer"><nav class="pageNav"><ul class="pageNav-main">
        <li class="pageNav-page pageNav-page--current"><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/page-1230">1230</a></li>
    </ul><input type="number" class="js-pageJumpPage" value="1230" max="1230"></nav></div>
    <div class="block-container"><div class="block-body js-replyNewMessageContainer">
        <article class="message message--post js-post js-inlineModContainer" data-author="Demo Moderator" data-content="post-1360340" id="js-post-1360340">
            <span class="u-anchorTarget" id="post-1360340"></span>
            <div class="message-inner">
                <div class="message-cell message-cell--user"><section class="message-user">
                    <div class="message-avatar"><a href="/members/demo-moderator.1/" class="avatar"><img src="" alt="Demo Moderator"></a></div>
                    <div class="message-userDetails">
                        <h4 class="message-name"><a href="/members/demo-moderator.1/" class="username" data-user-id="1"><span class="username--staff username--moderator">Demo Moderator</span></a></h4>
                        <h5 class="userTitle message-userTitle">Colonel</h5>
                        <div class="userBanner message-userBanner"><strong>VIP Professional</strong></div>
                    </div>
                </section></div>
                <div class="message-cell message-cell--main"><div class="message-main">
                    <header class="message-attribution">
                        <ul class="message-attribution-main"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360340"><time class="u-dt" datetime="2026-11-01T01:09:19-0400" data-date="Nov 1, 2026" data-time="1:09 AM">8 minutes ago</time></a></li></ul>
                        <ul class="message-attribution-opposite"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360340">#1</a></li></ul>
                    </header>
                    <div class="message-content"><div class="message-userContent"><article class="message-body js-selectToQuote"><div><div class="bbWrapper">
                        <p>Fujian has completed another round of sea trials. The deck markings now look close to the final configuration, and the carrier appears to have embarked a full air group for the first time.</p>
                        <blockquote data-attributes="" data-quote="Demo Member" data-source="post: 1360300" class="bbCodeBlock bbCodeBlock--quote">
                            <div class="bbCodeBlock-title"><a href="/goto/post?id=1360300">Demo Member said:</a></div>
                            <div class="bbCodeBlock-content"><div class="bbCodeBlock-expandContent">The next milestone should be the first operational deployment, not another builder's trial.</div></div>
                        </blockquote>
                        <p>Agreed. The air wing will be the deciding factor. A few images from the latest trial:</p>
                        <div class="bbImageWrapper"><a href="https://www.sinodefenceforum.com/attachments/fujian-jpg.179560/"><img src="https://www.sinodefenceforum.com/data/attachments/173/173153-4fd4b6ad538df3252068cadfeeb30746.jpg" class="bbImage" alt="Fujian"></a></div>
                        <pre class="bbCodeBlock bbCodeBlock--code"><code class="bbCodeCode">carrier = "Fujian"
                        hull = 003
                        airwing = ["J-35", "KJ-600", "Z-20"]</code></pre>
                    </div></div></article></div></div>
                </div></div>
            </div>
        </article>
        <article class="message message--post js-post js-inlineModContainer" data-author="Demo Member" data-content="post-1360341" id="js-post-1360341">
            <span class="u-anchorTarget" id="post-1360341"></span>
            <div class="message-inner">
                <div class="message-cell message-cell--user"><section class="message-user">
                    <div class="message-avatar"><a href="/members/demo-member.2/" class="avatar"><img src="" alt="Demo Member"></a></div>
                    <div class="message-userDetails">
                        <h4 class="message-name"><a href="/members/demo-member.2/" class="username" data-user-id="2"><span class="username--staff username--moderator">Demo Member</span></a></h4>
                        <h5 class="userTitle message-userTitle">General</h5>
                    </div>
                </section></div>
                <div class="message-cell message-cell--main"><div class="message-main">
                    <header class="message-attribution">
                        <ul class="message-attribution-main"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360341"><time class="u-dt" datetime="2026-11-01T01:18:04-0400" data-date="Nov 1, 2026" data-time="1:18 AM">2 minutes ago</time></a></li></ul>
                        <ul class="message-attribution-opposite"><li><a href="/t/cv-18-fujian-003-catobar-carrier-thread.8048/post-1360341">#2</a></li></ul>
                    </header>
                    <div class="message-content"><div class="message-userContent"><article class="message-body js-selectToQuote"><div><div class="bbWrapper">
                        <p>Good catch on the deck markings. The <strong>KJ-600</strong> mock-up is visible near the island in the third photo, which would be a meaningful step.</p>
                        <p>The next page will probably fill up with blurry satellite images again.</p>
                    </div></div></article></div></div>
                </div></div>
            </div>
        </article>
    </div></div></div>
    </div>
    </body></html>
    """
}
#endif
