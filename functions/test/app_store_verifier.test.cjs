// Run from functions/: npm run build && node --test test/app_store_verifier.test.cjs
//
// Builds a throwaway certificate chain shaped like Apple's (root → WWDR-style
// intermediate → App Store signing leaf, with Apple's marker extensions) and
// signs StoreKit 2 style transactions with it, so every accept and reject path
// of verifyAppStoreTransaction runs without a real purchase.
const {test, before} = require('node:test');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {mkdtempSync, readFileSync, writeFileSync} = require('node:fs');
const {tmpdir} = require('node:os');
const {join} = require('node:path');
const {X509Certificate, sign} = require('node:crypto');
const {verifyAppStoreTransaction} = require('../lib/appStoreVerifier');
const {VerificationFailure} = require('../lib/types');

const BUNDLE = 'com.luck3yapps.alchemons';
const PRODUCT = 'alchemons_gold_vault';
let dir;
const pem = (name) => readFileSync(join(dir, name), 'utf8');
const ssl = (...args) => execFileSync('openssl', args, {cwd: dir, stdio: 'pipe'});

function makeCert(name, issuer, extensions) {
  ssl('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', `${name}.key`);
  ssl('req', '-new', '-key', `${name}.key`, '-subj', `/CN=${name}`, '-out', `${name}.csr`);
  writeFileSync(join(dir, `${name}.ext`), extensions.join('\n'));
  ssl('x509', '-req', '-in', `${name}.csr`, '-CA', `${issuer}.pem`, '-CAkey', `${issuer}.key`,
    '-CAcreateserial', '-days', '3650', '-out', `${name}.pem`, '-extfile', `${name}.ext`);
}

function makeRoot(name) {
  ssl('ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', `${name}.key`);
  ssl('req', '-x509', '-new', '-key', `${name}.key`, '-subj', `/CN=${name}`, '-days', '3650',
    '-out', `${name}.pem`, '-addext', 'basicConstraints=critical,CA:TRUE',
    '-addext', 'keyUsage=critical,keyCertSign,cRLSign');
}

before(() => {
  dir = mkdtempSync(join(tmpdir(), 'appstore-jws-'));
  makeRoot('root');
  makeCert('wwdr', 'root', ['basicConstraints=critical,CA:TRUE', 'keyUsage=critical,keyCertSign',
    '1.2.840.113635.100.6.2.1=ASN1:NULL']);
  makeCert('leaf', 'wwdr', ['basicConstraints=critical,CA:FALSE',
    '1.2.840.113635.100.6.11.1=ASN1:NULL']);
  // A leaf the same intermediate issued without the App Store marker.
  makeCert('plain', 'wwdr', ['basicConstraints=critical,CA:FALSE']);
  makeRoot('stranger');
});

const der = (name) => new X509Certificate(pem(`${name}.pem`)).raw.toString('base64');
const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');

function jws(payload = {}, {leaf = 'leaf', chain} = {}) {
  const header = b64({alg: 'ES256', x5c: chain ?? [der(leaf), der('wwdr'), der('root')]});
  const body = b64({
    transactionId: '2000000123456789', originalTransactionId: '2000000123456789',
    bundleId: BUNDLE, productId: PRODUCT, type: 'Consumable', environment: 'Sandbox',
    purchaseDate: 1791700000000, signedDate: Date.now(), ...payload,
  });
  const signature = sign('sha256', Buffer.from(`${header}.${body}`),
    {key: pem(`${leaf}.key`), dsaEncoding: 'ieee-p1363'});
  return `${header}.${body}.${signature.toString('base64url')}`;
}

const verify = (signedTransaction, overrides = {}) => verifyAppStoreTransaction({
  productId: PRODUCT, transactionId: '2000000123456789', signedTransaction,
  roots: [pem('root.pem')], ...overrides,
});

function failsWith(kind, fn) {
  assert.throws(fn, (error) => error instanceof VerificationFailure && error.kind === kind);
}

test('accepts a genuine transaction for this app and product', () => {
  const result = verify(jws());
  assert.equal(result.platform, 'ios');
  assert.equal(result.transactionId, '2000000123456789');
  assert.equal(result.productId, PRODUCT);
  assert.equal(result.environment, 'Sandbox');
  assert.equal(result.purchasedAtMs, 1791700000000);
});

test('the client need not name the transaction', () => {
  assert.equal(verify(jws(), {transactionId: null}).transactionId, '2000000123456789');
});

test('a genuine transaction for something else is a definite no', () => {
  failsWith('invalid', () => verify(jws({productId: 'alchemons_gold_cache'})));
  failsWith('invalid', () => verify(jws({bundleId: 'com.someone.else'})));
  failsWith('invalid', () => verify(jws(), {transactionId: '2000000999999999'}));
  failsWith('invalid', () => verify(jws({revocationDate: 1791800000000})));
});

test('anything not provably Apple\'s is retried, never dropped', () => {
  const genuine = jws();
  const [header, , signature] = genuine.split('.');
  const forgedBody = b64({transactionId: '1', bundleId: BUNDLE, productId: PRODUCT});
  failsWith('internal', () => verify(`${header}.${forgedBody}.${signature}`));
  failsWith('internal', () => verify(jws({}, {leaf: 'plain', chain: [der('plain'), der('wwdr'), der('root')]})));
  failsWith('internal', () => verify(jws(), {roots: [pem('stranger.pem')]}));
  failsWith('internal', () => verify(jws({}, {chain: [der('leaf'), der('wwdr'), der('stranger')]})));
  failsWith('internal', () => verify('MIIT0QYJKoZIhvcNAQcCoIITwjCCE74CAQEx'));
});

test('production trusts only Apple\'s root, not a look-alike chain', () => {
  failsWith('internal', () => verify(jws(), {roots: undefined}));
});
