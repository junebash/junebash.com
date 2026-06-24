// Email obfuscation to prevent spam. Assembled at runtime so it isn't sitting
// in the markup for scrapers.
function junebashEmail() {
    const parts = ['june', 'bash', 'pizza'];
    return parts[0] + '@' + parts[1] + '.' + parts[2];
}

// Reveal the address visibly inside `el` (and make it a mailto link if `el`
// is an <a>). Works even with no default mail client. Called with no element
// it falls back to launching the mail client directly.
function revealEmail(el) {
    const email = junebashEmail();
    if (el && el.nodeType === 1) {
        el.textContent = email;
        el.classList.add('email-revealed');
        if (el.tagName === 'A') {
            el.setAttribute('href', 'mailto:' + email);
        }
    } else {
        window.location.href = 'mailto:' + email;
    }
}
