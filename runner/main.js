const { execSync } = require('child_process');

async function sleep(duration) {
    return new Promise(
        resolve => {
            setTimeout(() => {
                resolve()
            }, duration);
        }
    );
}

(async () => {
    while (true) {
        console.info("================");
        console.info("| Starting fsz |");
        console.info("================");

        execSync(`bin/fsz -l 0.0.0.0 -p ${process.env.PORT || 5000} fs/`, { stdio: 'inherit' });

        await sleep(3000);
    }
})()
