// Style proof: serves out/ on http://localhost:8765 so the review page can be
// checked locally in a browser. Usage: node serve.js
const http = require("http");
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "out");
const types = { ".html": "text/html; charset=utf-8", ".png": "image/png", ".json": "application/json" };
http.createServer((req, res) => {
  const name = decodeURIComponent((req.url || "/").split("?")[0]);
  const file = path.join(root, name === "/" ? "stilprobe.html" : name);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end("not found"); return; }
  res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
}).listen(8765, () => console.log("serving on http://localhost:8765"));
