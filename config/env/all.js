// default app configuration
const port = process.env.PORT || 4000;
let db = process.env.MONGODB_URI || "mongodb://localhost:27017/nodegoat";

module.exports = {
    port,
    db,
    cookieSecret: "session_cookie_secret_key_here",
    cryptoKey: "a_secure_key_for_crypto_here",
    cryptoAlgo: "aes256",
    hostName: "localhost",
    payrollApiUrl: "https://payroll.rexcorp.example/api/v2",
    payrollApiKey: "rxpayroll_Z4kP9wQ2mX7vL3nB8tR5yH1cJ6dF0gS",
    environmentalScripts: []
};

