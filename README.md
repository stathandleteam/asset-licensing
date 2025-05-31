# LicenStack

LicenStack is a decentralized marketplace for managing digital assets on the Stacks blockchain. Creators can register, sell, and license assets securely using Clarity smart contracts, with metadata and license requests stored off-chain in PostgreSQL.

## Overview

LicenStack enables on-chain asset management and transactions, integrated with a Next.js backend for a user-friendly API. It supports direct asset sales, licensing with escrow, and secure payment distribution.

## Features

- **Asset Sales**: Register and sell assets with STX payments (90% to seller, 10% platform fee).
- **Licensing**: Request, approve, and claim licenses with duration-based access.
- **Admin Controls**: Enable/disable assets via platform admin.
- **Signature Verification**: Uses SIP-018 for secure license claims.
- **On-Chain Security**: Validates ownership and licenses on Stacks blockchain.
- **Off-Chain Storage**: Stores metadata and requests in PostgreSQL.

## Tech Stack

- **Smart Contract**: Clarity (Stacks blockchain)
- **Token**: STX (sBTC support commented for testnet)
- **Backend**: Next.js (TypeScript), PostgreSQL
- **Blockchain**: Stacks Testnet (Devnet for development)
- **Deployment**: Vercel
- **Testing**: Clarinet SDK, Vitest

## Contract Details

- **Maps**:
  - `sale-assets`: Stores sale assets (owner, name, metadata, price, quantity, disabled).
  - `license-assets`: Stores license assets (owner, name, metadata, price, duration, disabled).
  - `licenses`: Tracks licenses (asset ID, licensee, validity period).
  - `license-requests`: Manages requests (asset ID, requester, approval, timestamp).
- **Payments**: 10% platform fee to `platform-address`.
- **Security**: `secp256k1-recover?` for signature verification; SIP-018 for structured data.
- **Errors**: Includes `ERR_NOT_AUTHORIZED`, `ERR_INVALID_SIGNATURE`, etc.

## Key Functions

- **Sale Assets**:
  - `register-sale-asset`: Create sale asset with quantity.
  - `buy-sale-asset`: Purchase asset, split payment.
  - `disable-sale-asset` / `enable-sale-asset`: Admin toggle.
- **License Assets**:
  - `register-license-asset`: Create license asset with duration.
  - `request-license`: Submit license request with STX escrow.
  - `claim-license`: Finalize license with signature.
  - `revoke-license`: Revoke by owner/licensee.
  - `disable-license-asset` / `enable-license-asset`: Admin toggle.
- **Utilities**:
  - `is-licensed`: Verify license validity.
  - `verify-frontend-message`: Validate SIP-018 signatures.
  - `test-claim-signature`: Test license signatures.

## SIP-018: Structured Data Signatures

SIP-018 is a Stacks Improvement Proposal defining a standard for signing structured data (e.g., JSON-like tuples) with secp256k1 keys. In LicenStack, it’s used to sign license claim messages (e.g., `{ request-id, requester }`) with a domain hash (`BlockAssets`, `1.0.0`, chain ID) and prefix (`0x534950303138`). This ensures secure, verifiable off-chain messages for on-chain validation.

## Stacks Blockchain Security

Stacks leverages Bitcoin’s security through Proof of Transfer (PoX), anchoring transactions to Bitcoin’s blockchain. LicenStack benefits from:
- **Immutability**: Clarity contracts ensure tamper-proof logic.
- **Signature Verification**: `secp256k1-recover?` validates signatures.
- **Transparency**: All transactions are recorded on Stacks.
- **Decentralization**: No single point of failure, secured by Stacks miners.

## Testing

- **Environment**: Clarinet simnet (Devnet accounts: `wallet_1`, `wallet_2`).
- **Tests**: In `tests/asset-license.test.ts`, covering asset registration, sales, licensing, and errors.


## License
MIT

# asset-licensing
