// Email obfuscation to prevent spam
function revealEmail() {
    const parts = ['june', 'bash', 'pizza'];
    const user = parts[0];
    const domain = parts[1] + '.' + parts[2];
    const email = user + '@' + domain;
    window.location.href = 'mailto:' + email;
}