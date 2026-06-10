/**
 * newinsights.ai signup capture — Apps Script web app backend.
 *
 * Paste this into the bound Apps Script project for the form and (re)deploy:
 *   Deploy → Manage deployments → edit active deployment →
 *     Execute as:      Me (ryan@newinsights.ai)
 *     Who has access:  Anyone        ← required for anonymous website visitors
 *
 * Writes [Email, Timestamp] rows to the "newinsights.ai - signups" sheet and
 * returns JSON the front-end can verify. ContentService responses include
 * Access-Control-Allow-Origin: *, so the browser can read the result.
 */

var SPREADSHEET_ID = '1p1ig3WjLXbBWouGVTL1hLEvfssw9C-sL268PeGyeD1Q'; // "newinsights.ai - signups"
var SHEET_NAME = 'Sheet1';

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return json({ result: 'error', error: 'No request body' });
    }

    var data = JSON.parse(e.postData.contents);
    var email = (data.email || '').toString().trim();

    // Basic server-side email sanity check.
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return json({ result: 'error', error: 'Invalid email' });
    }

    var sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_NAME);
    sheet.appendRow([email, new Date()]);

    return json({ result: 'success' });
  } catch (err) {
    return json({ result: 'error', error: String(err && err.message || err) });
  }
}

// Optional: lets you sanity-check the deployment in a browser (should return JSON).
function doGet() {
  return json({ result: 'ok', service: 'newinsights signup capture' });
}

function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
