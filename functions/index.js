const functions = require("firebase-functions");
const cors = require("cors")({ origin: true });
const axios = require("axios");

exports.proxy = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    const targetUrl = req.query.url;

    if (!targetUrl) {
      return res.status(400).send("Missing 'url' query parameter.");
    }

    try {
      const isInstagram = targetUrl.includes("instagram.com") || targetUrl.includes("instagr.am");
      const userAgent = req.headers["x-user-agent"] || (isInstagram 
        ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" 
        : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");

      const response = await axios.get(targetUrl, {
        headers: {
          "User-Agent": userAgent,
          Accept:
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
        },
        responseType: "arraybuffer",
        timeout: 15000,
        maxRedirects: 5,
      });

      const contentType =
        response.headers["content-type"] || "text/html; charset=utf-8";
      res.setHeader("Content-Type", contentType);

      return res.status(response.status).send(Buffer.from(response.data));
    } catch (error) {
      console.error(`Proxy error fetching URL (${targetUrl}):`, error.message);
      const statusCode = error.response ? error.response.status : 500;
      return res.status(statusCode).send(`Proxy error: ${error.message}`);
    }
  });
});
