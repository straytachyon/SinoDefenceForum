import Foundation
import Testing
@testable import SinoDefence

struct AlertsParsingTests {
    @Test func parsesXenForoAlertBadgeAndRows() {
        let html = """
        <a href="/alerts/" class="p-navgroup-link p-navgroup-link--iconic alerts">
            <span class="badge">2</span>
        </a>
        <ul>
            <li class="alert is-unread">
                <div class="alert-content">
                    <a href="/members/deepseek.42/">deepseek</a> reacted to your post
                </div>
                <time class="u-dt" datetime="2026-11-02T10:00:00Z">Today at 10:00</time>
            </li>
        </ul>
        """
        #expect(XFParser.parseAlertCount(in: html) == 2)
        let alerts = XFParser.parseAlerts(in: html)
        #expect(alerts.count == 1)
        #expect(alerts[0].text.contains("reacted to your post"))
        #expect(alerts[0].time.contains("Today"))
        #expect(alerts[0].isUnread)
        #expect(alerts[0].url?.absoluteString.contains("/members/deepseek.42/") == true)
    }
}
