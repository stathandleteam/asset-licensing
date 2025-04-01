LicenStack is a decentralized platform for licensing and selling digital assets on the Stacks blockchain. It enables creators to mint, list, and transfer digital assets, while ensuring fair compensation through smart contract-enforced payments.

## Overview
This project allows users to manage digital assets securely on-chain while storing metadata and license requests off-chain in PostgreSQL. The Clarity smart contract handles asset registration, sales, licensing, and payments, while the Next.js backend provides a user-friendly API.

## Features
- **Asset Registration**: Create assets with name, metadata, price, and status (for sale, for license, or unlisted).
- **Direct Buying**: Purchase assets with sBTC, splitting payments between seller and platform.
- **Licensing**: Request licenses with escrow payments, claim them with owner signatures, and use or revoke them on-chain.
- **Admin Controls**: Platform admin can enable/disable assets.
- **On-Chain Verification**: Validate ownership and licenses using Stacks blockchain.
- **Off-Chain Storage**: Metadata and license requests stored in PostgreSQL.

## Tech Stack
- **Smart Contract**: Clarity (Stacks blockchain)
- **Token**: sBTC (via `SP1KK2VMSSTSK1BY64SG2WFFFTMAGCY15FYTA90BS.sbtc-token`)
- **Backend**: Next.js (TypeScript), PostgreSQL
- **Blockchain**: Stacks Testnet
- **Deployment**: Vercel

## Contract Details
- **Assets**: Stored with owner, name, metadata, status, price, duration, licensed, and disabled flags.
- **Licenses**: Managed via requests and claims with sBTC payments.
- **Payments**: 10% platform fee on sales and licenses.

## License
MIT
