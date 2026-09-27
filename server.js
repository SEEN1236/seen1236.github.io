const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const port = Number(process.env.PORT || 3000);
const root = __dirname;
let stopping = false;
const activeSockets = new Set();
const textExtensions = new Set(['.css', '.html', '.js', '.json', '.svg', '.txt', '.xml']);
const mimeTypes = {
  '.apk': 'application/vnd.android.package-archive',
  '.css': 'text/css; charset=utf-8',
  '.exe': 'application/vnd.microsoft.portable-executable',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
};

function cacheControl(filePath) {
  const fileName = path.basename(filePath);
  const extension = path.extname(filePath).toLowerCase();
  // Always revalidate the page shell, never retain large installers, and cache
  // only immutable visual assets for fast repeat visits.
  if (extension === '.exe' || extension === '.apk') return 'no-store';
  if (fileName === 'index.html' || fileName === 'sw.js' || fileName === 'manifest.json') {
    return 'no-cache';
  }
  return 'public, max-age=31536000, immutable';
}

function sendError(response, statusCode, message) {
  response.writeHead(statusCode, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  response.end(message);
}

function createFileStream(filePath, range) {
  return fs.createReadStream(filePath, range ? { start: range.start, end: range.end } : undefined);
}

function stopServer() {
  if (stopping) return;
  stopping = true;
  server.close(() => process.exit(0));
  server.closeAllConnections?.();
  for (const socket of activeSockets) socket.destroy();
  setTimeout(() => process.exit(0), 500).unref();
}

const server = http.createServer((request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) {
    response.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url, `http://${request.headers.host || 'localhost'}`).pathname);
  } catch {
    sendError(response, 400, 'Bad request');
    return;
  }

  const relativePath = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  const filePath = path.resolve(root, relativePath);

  if (path.relative(root, filePath).startsWith('..') || path.isAbsolute(path.relative(root, filePath))) {
    sendError(response, 403, 'Forbidden');
    return;
  }

  fs.stat(filePath, (error, stats) => {
    if (error || !stats.isFile()) {
      sendError(response, 404, 'Not found');
      return;
    }

    const extension = path.extname(filePath).toLowerCase();
    const etag = `"${stats.size.toString(16)}-${Math.floor(stats.mtimeMs).toString(16)}"`;
    const commonHeaders = {
      'Accept-Ranges': 'bytes',
      'Cache-Control': cacheControl(filePath),
      'Content-Type': mimeTypes[extension] || 'application/octet-stream',
      ETag: etag,
      'Last-Modified': stats.mtime.toUTCString(),
    };

    if (request.headers['if-none-match'] === etag) {
      response.writeHead(304, commonHeaders).end();
      return;
    }

    let range;
    const rangeMatch = /^bytes=(\d*)-(\d*)$/.exec(request.headers.range || '');
    if (rangeMatch) {
      const start = rangeMatch[1] === '' ? 0 : Number(rangeMatch[1]);
      const end = rangeMatch[2] === '' ? stats.size - 1 : Number(rangeMatch[2]);
      if (!Number.isInteger(start) || !Number.isInteger(end) || start > end || start >= stats.size) {
        response.writeHead(416, { ...commonHeaders, 'Content-Range': `bytes */${stats.size}` }).end();
        return;
      }
      range = { start, end: Math.min(end, stats.size - 1) };
    }

    const headers = {
      ...commonHeaders,
      'Content-Length': range ? range.end - range.start + 1 : stats.size,
      ...(range ? { 'Content-Range': `bytes ${range.start}-${range.end}/${stats.size}` } : {}),
    };

    if (request.method === 'HEAD') {
      response.writeHead(range ? 206 : 200, headers).end();
      return;
    }

    const stream = createFileStream(filePath, range);
    stream.on('error', () => response.destroy());

    if (range || !textExtensions.has(extension)) {
      response.writeHead(range ? 206 : 200, headers);
      stream.pipe(response);
      return;
    }

    const acceptEncoding = request.headers['accept-encoding'] || '';
    if (/\bbr\b/.test(acceptEncoding)) {
      const compressedHeaders = { ...headers, 'Content-Encoding': 'br', Vary: 'Accept-Encoding' };
      delete compressedHeaders['Content-Length'];
      response.writeHead(200, compressedHeaders);
      stream.pipe(zlib.createBrotliCompress()).pipe(response);
    } else if (/\bgzip\b/.test(acceptEncoding)) {
      const compressedHeaders = { ...headers, 'Content-Encoding': 'gzip', Vary: 'Accept-Encoding' };
      delete compressedHeaders['Content-Length'];
      response.writeHead(200, compressedHeaders);
      stream.pipe(zlib.createGzip()).pipe(response);
    } else {
      response.writeHead(200, headers);
      stream.pipe(response);
    }
  });
});

server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;
server.on('connection', (socket) => {
  activeSockets.add(socket);
  socket.on('close', () => activeSockets.delete(socket));
});

server.once('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${port} is already in use. Stop the other website server, then try again.`);
  } else {
    console.error('Website server could not start:', error.message);
  }
  process.exit(1);
});

server.listen(port, '0.0.0.0', () => {
  const localUrl = `http://localhost:${port}`;
  console.log(`SEEN website is running at ${localUrl}`);
  console.log(`Network access is enabled on port ${port}.`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, stopServer);
}
