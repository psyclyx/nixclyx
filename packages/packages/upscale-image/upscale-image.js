const fs = require('fs');
const https = require('https');
const path = require('path');

const panic = (code, message) => {
    console.error(message);
    process.exit(code);
};

const request = (options, payload = null) =>
    new Promise((resolve, reject) => {
        const req = https.request(options, res => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 400) {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                } else {
                    try {
                        resolve(JSON.parse(data));
                    } catch (e) {
                        reject(new Error(`Failed to parse response: ${e.message}`));
                    }
                }
            });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });

const apiRequest = (method, path, payload = null) => {
    const options = {
        hostname: 'api.replicate.com',
        port: 443,
        path,
        method,
        headers: {
            'Authorization': `Bearer ${process.env.REPLICATE_API_TOKEN}`,
            'Content-Type': 'application/json'
        }
    };
    if (payload) {
        const data = JSON.stringify(payload);
        options.headers['Content-Length'] = Buffer.byteLength(data);
        return request(options, data);
    }
    return request(options);
};

const getModel = async modelId => {
    const [owner, name] = modelId.split('/');
    if (!owner || !name) {
        panic(1, `Error: Invalid model ID format. Use 'owner/model-name'`);
    }
    try {
        return await apiRequest('GET', `/v1/models/${owner}/${name}`);
    } catch (error) {
        panic(1, `Error fetching model: ${error.message}`);
    }
};

const toCliArg = (key, property, required = false) => {
    const isImage = ['image', 'input_image', 'input'].includes(key);
    return {
        key,
        flag: isImage ? '-i' : `--${key.replace(/_/g, '-')}`,
        description: property.description || `Set ${key}`,
        type: property.type,
        default: property.default,
        required,
        enum: property.enum,
        isImage
    };
};

const extractArgs = model => {
    const schema = model.latest_version?.openapi_schema;
    if (!schema?.components?.schemas?.Input?.properties) {
        panic(1, 'Error: Invalid model schema');
    }

    const { properties, required = [] } = schema.components.schemas.Input;
    const args = Object.entries(properties).map(([key, prop]) =>
        toCliArg(key, prop, required.includes(key))
    );

    args.push({
        key: '_output_file',
        flag: '-o',
        description: 'Output image file',
        type: 'string',
        required: false
    });

    return args;
};

const buildUsage = (modelId, args) => {
    const imageArg = args.find(a => a.isImage);
    const required = args.filter(a => a.required && !a.isImage);
    const optional = args.filter(a => !a.required && !a.isImage);

    let usage = `Usage: node ${path.basename(process.argv[1])} ${modelId}`;
    if (imageArg) usage += ` -i <image-file>`;
    required.forEach(arg => usage += ` ${arg.flag} <${arg.type}>`);
    usage += ' [options]\n\nOptions:\n';

    const formatArg = arg => {
        let line = `  ${arg.flag.padEnd(20)} ${arg.description}`;
        if (arg.required) line += ' (required)';
        else if (arg.default !== undefined) line += ` (default: ${arg.default})`;
        if (arg.enum) line += `\n${''.padEnd(22)}Choices: ${arg.enum.join(', ')}`;
        return line;
    };

    if (imageArg) usage += formatArg({ ...imageArg, required: true }) + '\n';
    [...required, ...optional].forEach(arg => usage += formatArg(arg) + '\n');
    usage += `\nEnvironment:\n  REPLICATE_API_TOKEN   Your Replicate API token (required)\n`;

    return usage;
};

const parseValue = (value, type) => {
    switch (type) {
        case 'integer':
            const int = parseInt(value);
            if (isNaN(int)) throw new Error('must be an integer');
            return int;
        case 'number':
            const num = parseFloat(value);
            if (isNaN(num)) throw new Error('must be a number');
            return num;
        case 'boolean':
            return value.toLowerCase() === 'true';
        default:
            return value;
    }
};

const parseCliArgs = (args, schema) => {
    const parsed = { _output_file: null };
    const flagMap = Object.fromEntries(
        schema.flatMap(arg => [
            [arg.flag, arg.key],
            ...(arg.isImage ? [['--input', arg.key]] : [])
        ])
    );

    for (let i = 0; i < args.length; i += 2) {
        const flag = args[i];
        if (!flagMap[flag]) panic(2, `Error: Unknown argument '${flag}'`);
        if (i + 1 >= args.length) panic(2, `Error: Missing value for ${flag}`);

        const key = flagMap[flag];
        const argSchema = schema.find(a => a.key === key);

        try {
            parsed[key] = parseValue(args[i + 1], argSchema.type);
            if (argSchema.enum && !argSchema.enum.includes(parsed[key])) {
                panic(2, `Error: ${flag} must be one of: ${argSchema.enum.join(', ')}`);
            }
        } catch (e) {
            panic(2, `Error: ${flag} ${e.message}`);
        }
    }

    schema.filter(a => a.required && parsed[a.key] === undefined)
        .forEach(a => panic(2, `Error: Missing required argument ${a.flag}`));

    return parsed;
};

const fileToDataUri = filename => {
    try {
        const buffer = fs.readFileSync(filename);
        const ext = path.extname(filename).toLowerCase();
        const mimeTypes = {
            '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
            '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp'
        };
        const mimeType = mimeTypes[ext] || 'application/octet-stream';
        return `data:${mimeType};base64,${buffer.toString('base64')}`;
    } catch (error) {
        panic(1, `Error reading file ${filename}: ${error.message}`);
    }
};

const generateOutputName = inputFile => {
    const { dir, name, ext } = path.parse(inputFile);
    return path.format({ dir, name: `${name}_output_${Date.now()}`, ext });
};

const predict = async (modelId, inputs) => {
    try {
        const response = await apiRequest('POST', `/v1/models/${modelId}/predictions`, { input: inputs });
        if (response.status === 'starting' || response.status === 'processing') {
            return await pollPrediction(response.id);
        }
        return response;
    } catch (error) {
        panic(1, `Error running prediction: ${error.message}`);
    }
};

const pollPrediction = async id => {
    console.log('Processing');
    const startTime = Date.now();

    while (true) {
        try {
            const response = await apiRequest('GET', `/v1/predictions/${id}`);

            switch (response.status) {
                case 'succeeded':
                    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
                    console.log(`\nProcessed in ${elapsed}s`);
                    return response;
                case 'failed':
                    panic(1, `\nPrediction failed: ${response.error || 'Unknown error'}`);
                case 'canceled':
                    panic(1, '\nPrediction was canceled');
            }

            process.stdout.write('.');
            await new Promise(resolve => setTimeout(resolve, 1000));
        } catch (error) {
            panic(1, `\nError polling prediction: ${error.message}`);
        }
    }
};

const downloadFile = url =>
    new Promise((resolve, reject) => {
        https.get(url, res => {
            const chunks = [];
            res.on('data', chunk => chunks.push(chunk));
            res.on('end', () => resolve(Buffer.concat(chunks)));
            res.on('error', reject);
        }).on('error', reject);
    });

const saveOutput = async (output, outputFile) => {
    if (!output) panic(1, 'Error: No output received from model');

    const imageUrl = typeof output === 'string' ? output
        : Array.isArray(output) ? output[0]
        : output.url || panic(1, 'Error: Unexpected output format');

    const base64Match = imageUrl.match(/^data:.*?;base64,(.+)$/);
    const buffer = base64Match
        ? Buffer.from(base64Match[1], 'base64')
        : await downloadFile(imageUrl);

    fs.writeFileSync(outputFile, buffer);
};

const main = async () => {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        console.log('Usage: node ' + path.basename(process.argv[1]) + ' <model-id> [options]');
        console.log('\nExample: node ' + path.basename(process.argv[1]) + ' stability-ai/stable-diffusion -i input.jpg');
        process.exit(0);
    }

    if (!process.env.REPLICATE_API_TOKEN) {
        panic(1, 'Error: REPLICATE_API_TOKEN environment variable not set');
    }

    const modelId = args[0];
    const modelArgs = args.slice(1);

    console.log(`Fetching model schema for ${modelId}...`);
    const model = await getModel(modelId);
    const cliArgs = extractArgs(model);

    if (modelArgs.length === 0) {
        console.log('\n' + buildUsage(modelId, cliArgs));
        process.exit(0);
    }

    const inputs = parseCliArgs(modelArgs, cliArgs);
    const imageArg = cliArgs.find(a => a.isImage);

    if (imageArg && inputs[imageArg.key]) {
        const inputFile = inputs[imageArg.key];
        console.log(`Reading input image: ${inputFile}`);
        inputs[imageArg.key] = fileToDataUri(inputFile);
        inputs._output_file ||= generateOutputName(inputFile);
    }

    const outputFile = inputs._output_file || 'output.png';
    delete inputs._output_file;

    Object.keys(inputs).forEach(key => {
        if (inputs[key] === undefined) delete inputs[key];
    });

    console.log(`Running prediction with ${modelId}...`);
    const result = await predict(modelId, inputs);

    console.log(`Saving output to ${outputFile}...`);
    await saveOutput(result.output, outputFile);
    console.log(`Success! Output saved to ${outputFile}`);
};

if (require.main === module) {
    main().catch(error => panic(1, `Unexpected error: ${error.message}`));
}
