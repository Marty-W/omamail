import QtQuick 2.15
import QtTest 1.3
import qs.Commons
import "../../components" as Mail
import "../../providers/ImapProtocol.js" as Imap

// "Server saves sent mail" is a per-mailbox choice: off by default, saved with
// the rest of the form, read back on the next visit, and never inherited by a
// mailbox whose stored settings do not carry it.
Item {
  width: 700
  height: 900

  QtObject {
    id: fakeAuth
    property bool loggedIn: false
    property bool loginBusy: false
    property bool toolsChecked: true
    property var missingTools: []
    property string lastError: ""
    property var settings: Imap.normalizeSettings({ imapHost: "127.0.0.1", imapPort: 1143,
      smtpHost: "127.0.0.1", smtpPort: 1025, username: "work@example.org" })
  }

  QtObject {
    id: fakeService
    property var auth: fakeAuth
    property string accountAddress: "work@example.org"
    property string accountName: ""
    property var saved: null
    function configureCurrentAccount(values) { saved = values }
    function configureCurrentAccountAndSignIn(values, secret) { saved = values }
  }

  Mail.ImapSetupPage {
    id: page
    width: 600
    service: fakeService
    textColor: Color.foreground
    dimColor: Color.foreground
    dangerColor: Color.accent
    accentColor: Color.accent
    panelFontFamily: "monospace"
  }

  TestCase {
    name: "ImapServerSavesSent"
    when: windowShown

    function field(name) {
      function find(item) {
        if (item.objectName === name) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) { var f = find(kids[i]); if (f) return f }
        return null
      }
      return find(page)
    }

    function test_the_choice_is_saved_read_back_and_not_inherited() {
      page.syncFromStore()
      var toggle = field("imap-server-saves-sent")
      verify(toggle !== null)
      compare(toggle.checked, false, "off by default")
      compare(page.currentSettings().serverSavesSent, false)

      toggle.toggled()
      compare(page.currentSettings().serverSavesSent, true)
      page.save()
      verify(fakeService.saved !== null)
      compare(fakeService.saved.imap.serverSavesSent, true)

      fakeAuth.settings = fakeService.saved.imap
      page.syncFromStore()
      compare(toggle.checked, true, "read back from the store")

      toggle.toggled()
      page.save()
      compare(fakeService.saved.imap.serverSavesSent, false)

      fakeAuth.settings = Imap.normalizeSettings({ imapHost: "imap.example.org", username: "other@example.org" })
      page.syncFromStore()
      compare(toggle.checked, false, "a mailbox without the choice does not inherit it")
    }
  }
}
