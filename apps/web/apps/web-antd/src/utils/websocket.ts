export function buildWebSocketUrl(
  apiBaseUrl: string,
  socketPath: string,
  params: URLSearchParams,
  pageUrl: string,
) {
  const pageOrigin = new URL(pageUrl).origin;
  const url = new URL(apiBaseUrl || '/', `${pageOrigin}/`);

  if (url.protocol === 'http:') {
    url.protocol = 'ws:';
  } else if (url.protocol === 'https:') {
    url.protocol = 'wss:';
  } else if (url.protocol !== 'ws:' && url.protocol !== 'wss:') {
    throw new TypeError(`Unsupported WebSocket base protocol: ${url.protocol}`);
  }

  const basePath = url.pathname.replace(/\/+$/, '');
  const relativeSocketPath = socketPath.replace(/^\/+/, '');
  url.pathname = `${basePath}/${relativeSocketPath}`;
  url.search = '';
  url.hash = '';

  for (const [key, value] of params) {
    url.searchParams.append(key, value);
  }

  return url.toString();
}
