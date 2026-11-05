import '@fontsource/inter/latin-400.css';
import '@fontsource/inter/latin-500.css';
import '@fontsource/inter/latin-600.css';
import './style.css';

// The download is a regular link, so it works without JavaScript too.
fetch('/release.json')
  .then(response => response.ok ? response.json() : null)
  .then(release => {
    if (!release) return;
    document.querySelector('#version').textContent = `v${release.version}`;
    const button = document.querySelector('.download');
    button.setAttribute('aria-label', `Download Termi ${release.version} for Apple silicon Macs, ${(release.sizeBytes / 1048576).toFixed(1)} MB`);
  })
  .catch(() => {});
