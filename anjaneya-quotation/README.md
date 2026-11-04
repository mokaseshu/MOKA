# Anjaneya Traders Quotation Maker

A phone-friendly page that makes Anjaneya Traders quotation PDFs (AT/Q/YY-YY/NNN) in the standard navy and orange A4 layout.

1. Fill in the customer, items, GST and terms (opened inside Claude, it can also read a photo of the handwritten bill).
2. Check the live preview.
3. Tap **Download PDF**.

Quotation numbers go up automatically. Saved quotations are kept in this browser.

Photo reading: tap the key box once and paste your own Claude API key. It is stored only in that browser (localStorage) and is never part of this repository.

Everything runs in the browser (`index.html`); there is no server.
