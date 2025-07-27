const fs = require('fs');
const https = require('https');

const args = process.argv.slice(2);

var inputFile = null;
var outputFile = null;
var scale = 2;

while (args.length > 0) {
    arg = args.shift();
    switch (arg) {
    case "-i":
    case "--input":
        inputFile = args.shift();
        break;
    case "-o":
    case "--output":
        outputFile = args.shift();
        break;
    case "-s":
    case "--scale":
        scale = parseInt(args.shift());
        break;
    default:
        console.error(`Error: Unknown argument '${arg}`);
        process.exit(1);
    }
}

if (scale != 2 && scale != 4) {
    console.error(`Error: scale must be 2 or 4`);
    process.exit(1);
}

outputFile = outputFile || `${scale}x-${inputFile}`;

if (!fs.existsSync(inputFile)) {
    console.error(`Error: File '${inputFile}' does not exist`);
    process.exit(1);
}

console.log(`Scaling '${inputFile}' ${scale}x and saving to '${outputFile}'`)

const imageBuffer = fs.readFileSync(inputFile);
const base64Data = imageBuffer.toString('base64');
const dataUri = `data:application/octet-stream;base64,${base64Data}`;

const payload = JSON.stringify({
    input: {
        sync: true,
        image: dataUri,
        preserve_alpha: true,
        desired_increase: 4,
        content_moderation: false
    }
});

const options = {
    hostname: 'api.replicate.com',
    port: 443,
    path: '/v1/models/bria/increase-resolution/predictions',
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${process.env.REPLICATE_API_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'Prefer': 'wait'
    }
};

const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
        const response = JSON.parse(data);
        const imageUri = response.output;
        const base64Match = imageUri.match(/^data:.*?;base64,(.+)$/);

        if (base64Match) {
            fs.writeFileSync(outputFile, Buffer.from(base64Match[1], 'base64'));
        } else {
            const protocol = imageUri.startsWith('https:') ? https : http;
            protocol.get(imageUri, (fetchRes) => {
                const chunks = [];
                fetchRes.on('data', chunk => chunks.push(chunk));
                fetchRes.on('end', () => fs.writeFileSync(outputFile, Buffer.concat(chunks)));
            });
        }
    });
});

req.on('error', (error) => {
    console.error('Request error:', error.message);
    process.exit(1);
});

req.write(payload);
req.end();
