// Shared by bundled modules and standalone page scripts. Never send the token
// to another origin, and retain Request objects, bodies, and fetch options.
(() => {
  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, options = {}) => {
    const request = input instanceof Request ? input : null;
    const url = new URL(request ? request.url : input, window.location.href);
    const method = (options.method || request?.method || 'GET').toUpperCase();
    if (url.origin !== window.location.origin || ['GET', 'HEAD', 'OPTIONS'].includes(method)) {
      return originalFetch(input, options);
    }
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    const headers = new Headers(options.headers || request?.headers);
    if (token) headers.set('X-CSRF-Token', token);
    return originalFetch(input, { ...options, headers });
  };

  // Keep native forms (including dynamically created forms) protected too.
  document.addEventListener('submit', event => {
    const form = event.target;
    const url = new URL(form.action, window.location.href);
    if (form.method.toUpperCase() === 'GET' || url.origin !== window.location.origin) return;
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!token) return;
    let field = form.querySelector('input[name="authenticity_token"]');
    if (!field) {
      field = document.createElement('input');
      field.type = 'hidden';
      field.name = 'authenticity_token';
      form.appendChild(field);
    }
    field.value = token;
  }, true);
})();