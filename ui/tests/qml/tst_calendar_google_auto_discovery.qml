import QtQuick 2.15
import QtTest 1.3
import "../../calendar" as Omamail

// Every Google calendar an account has selected shows without visiting the
// settings: discovery runs once per signed-in Google account and is saved with
// Google's selection, hidden and unselected calendars off; a failure is quiet.
Item {
  width: 400
  height: 300

  QtObject {
    id: mailService
    property var requests: []
    property var callbacks: []
    property bool backendCanDiscoverCalendars: true
    property bool backendCanGoogleCalendars: true
    property var configWrites: []
    property var backend: ({ ready: true, call: function(method, params, callback) {
      mailService.requests.push({ method: method, params: params })
      mailService.callbacks.push(callback)
    } })
    property bool unifiedCalendarView: false
    property var accountSummaries: [
      { id: "imap:work@example.com", email: "work@example.com", provider: "imap", signedIn: true },
      { id: "one@gmail.com", email: "one@gmail.com", provider: "gmail", signedIn: true, calendarProvider: "google" },
      { id: "two@gmail.com", email: "two@gmail.com", provider: "gmail", signedIn: true, calendarProvider: "google" }
    ]
    function writeConfig(name, payload, callback) {
      configWrites.push({ name: name, payload: payload })
      callback(true, "")
    }
  }

  Omamail.CalendarController {
    id: controller
    service: mailService
    pluginDir: "/tmp/omamail-test"
    accountId: "one@gmail.com"
    autoDiscoverGoogle: true
    sourceList: ({ version: 1, sources: [] })
  }

  TestCase {
    name: "CalendarGoogleAutoDiscovery"

    function discoveries() {
      return mailService.requests.filter(function(r) { return r.method === "calendar.discover" })
    }

    function test_selected_google_calendars_are_saved_without_a_review_step() {
      controller.sourcesLoaded = true
      tryVerify(function() { return discoveries().length === 1 }, 5000)
      compare(discoveries()[0].params.accountId, "one@gmail.com")
      var answer = mailService.callbacks[mailService.callbacks.length - 1]
      answer({ provider: "google", accountId: "one@gmail.com", calendars: [
        { sourceId: "google:one@gmail.com", calendarId: "primary", name: "One", isDefault: true, selected: true },
        { sourceId: "google:one@gmail.com:mk", calendarId: "mk@group.calendar.google.com", name: "MK", selected: true },
        { sourceId: "google:one@gmail.com:off", calendarId: "off@group.calendar.google.com", name: "Off", selected: false },
        { sourceId: "google:one@gmail.com:hid", calendarId: "hid@group.calendar.google.com", name: "Hidden", selected: true, hidden: true }
      ] }, null)
      compare(controller.discoveryChoices, null, "no review step for automatic discovery")
      compare(mailService.configWrites.length, 1)
      var saved = JSON.parse(mailService.configWrites[0].payload).sources
      var enabled = {}
      saved.forEach(function(s) { enabled[s.calendarId] = s.enabled })
      compare(enabled["primary"], true)
      compare(enabled["mk@group.calendar.google.com"], true)
      compare(enabled["off@group.calendar.google.com"], false)
      compare(enabled["hid@group.calendar.google.com"], false)

      // The second account follows; its failure (an old grant without the
      // calendar-list scope) is not reported, and nothing is asked again.
      tryVerify(function() { return discoveries().length === 2 }, 5000)
      compare(discoveries()[1].params.accountId, "two@gmail.com")
      mailService.callbacks[mailService.callbacks.length - 1](null, { message: "calendar_auth_refused" })
      compare(controller.discoveryError, "")
      compare(mailService.configWrites.length, 1)
      wait(2000)
      compare(discoveries().length, 2, "each account once a session")
    }
  }
}
