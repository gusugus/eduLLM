const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3002;

const server = http.createServer((req, res) => {
    if (req.url === '/' || req.url === '/index.html') {
        const filePath = path.join(__dirname, 'index.html');
        fs.readFile(filePath, (err, content) => {
            if (err) {
                res.writeHead(500);
                res.end('Error loading index.html');
            } else {
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end(content);
            }
        });
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(PORT, () => {
    console.log(`\x1b[36m%s\x1b[0m`, `Tutor Test Lab running at http://localhost:${PORT}`);
    console.log(`Connecting to MindBuzz Socket Server at http://localhost:3001/ws`);
    console.log(`Expecting Proxy SSE at http://localhost:5000`);
});
