const fs = require('fs');
const https = require('https');
const path = require('path'); // Added missing import

function panic(code, message) {
    console.error(message);
    process.exit(code);
}

const initialOpts = {
    inputFile: null,
    outputFile: null,
    scale: "2",
}

const flagOptKeys = {
    "-i": "inputFile",
    "--input": "inputFile",
    "-o": "outputFile",
    "--output": "outputFile",
    "-s": "scale",
    "--scale": "scale"
}

function readOpts(args) {
    const missingArg = (flag) => panic(2, `Error: Ran out of arguments while parsing ${flag}`);
    var opts = {...initialOpts};
    while (args.length > 0) {
        flag = args.shift();
        optKey = flagOptKeys[flag] || panic(2, `Error: Unknown argument '${flag}'`);
        val = args.shift() || panic(2, `Error: Ran out of arguments while parsing '${flag}'`);
        opts[optKey] = val;
    }
    return opts;
}

function checkOpts(opts) {
    if (!opts.inputFile)
        panic(2, `Error: No input file`)
    if (opts.scale != "2" && opts.scale != "4")
        panic(2, `Error: Scale must be 2 or 4, got '${opts.scale}'`)
}

function appendSuffix(filename, suffix) {
  const parsed = path.parse(filename);
  return path.format({
    dir: parsed.dir,
    name: parsed.name + suffix,
    ext: parsed.ext
  });
}

function ensureOutput(opts) {
    if(opts.outputFile) return opts;
    return {...opts, outputFile: appendSuffix(opts.inputFile, `-${opts.scale}x`)};
}

function readAsDataUri(filename) {
    const buffer = fs.readFileSync(filename);
    const base64Data = buffer.toString('base64');
    return `data:application/octet-stream;base64,${base64Data}`;
}

function requestPayload(dataUri, scale) {
 return JSON.stringify({
    input: {
        sync: true,
        image: dataUri,
        preserve_alpha: true,
        desired_increase: parseInt(scale),
        content_moderation: false
    }
 })
}

function requestOptions(payload) {
    return {
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
}

function makeUpscaleRequest(options, payload, outputFile) {
    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    console.log(response);
                    resolve({ response, outputFile });
                } catch (error) {
                    reject(new Error(`Failed to parse response: ${error.message}`));
                }
            });
        });

        req.on('error', (error) => {
            reject(new Error(`Request error: ${error.message}`));
        });

        req.write(payload);
        req.end();
    });
}

function extractImageUri(response) {
    if (!response.output) {
        throw new Error('No output found in response');
    }
    return response.output;
}

function saveBase64Image(base64Data, outputFile) {
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(outputFile, buffer);
    return Promise.resolve();
}

function saveImageFromUrl(imageUrl, outputFile) {
    return new Promise((resolve, reject) => {
        https.get(imageUrl, (fetchRes) => {
            const chunks = [];
            fetchRes.on('data', chunk => chunks.push(chunk));
            fetchRes.on('end', () => {
                try {
                    fs.writeFileSync(outputFile, Buffer.concat(chunks));
                    resolve();
                } catch (error) {
                    reject(error);
                }
            });
            fetchRes.on('error', reject);
        }).on('error', reject);
    });
}

function saveImageFromUri(imageUri, outputFile) {
    const base64Match = imageUri.match(/^data:.*?;base64,(.+)$/);
    if (base64Match) {
        return saveBase64Image(base64Match[1], outputFile);
    } else {
        return saveImageFromUrl(imageUri, outputFile);
    }
}

function processUpscaleResponse(responseData) {
    const { response, outputFile } = responseData;
    const imageUri = extractImageUri(response);
    return saveImageFromUri(imageUri, outputFile);
}

async function main() {
    try {
        const args = process.argv.slice(2);
        let opts = readOpts(args);
        checkOpts(opts);
        opts = ensureOutput(opts);
        console.log(`Upscaling ${opts.inputFile} by ${opts.scale}x to ${opts.outputFile}...`);
        const dataUri = readAsDataUri(opts.inputFile);
        const payload = requestPayload(dataUri, opts.scale);
        const options = requestOptions(payload);
        const responseData = await makeUpscaleRequest(options, payload, opts.outputFile);
        await processUpscaleResponse(responseData);
        console.log(`Successfully upscaled image saved to: ${opts.outputFile}`);
    } catch (error) {
        panic(1, `Error: ${error.message}`);
    }
}

if (require.main === module) {
    main();
}
