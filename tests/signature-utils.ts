import { Cl, stringAsciiCV, serializeCV, StacksPrivateKey, ClarityValue, uintCV } from '@stacks/transactions';
import { signWithKey } from '@stacks/transactions';

import { createHash } from 'crypto';
import { Buffer } from 'buffer';


const chainIds = {
  mainnet: 1,
  testnet: 2147483648,
};

const structuredDataPrefix = Buffer.from([0x53, 0x49, 0x50, 0x30, 0x31, 0x38]);
const domainHash = createHash('sha256').update(
  serializeCV(
    Cl.tuple({
      name: stringAsciiCV('BlockAssets'),
      version: stringAsciiCV('1.0.0'),
      'chain-id':uintCV(chainIds.testnet), // Change to mainnet if needed
    })
  )
).digest();


export function sha256(data: Buffer): Buffer {
  return createHash("sha256").update(data).digest();
}

export function generateSignature(data: ClarityValue, privateKey: StacksPrivateKey): Buffer {
  const messageHash = createHash('sha256').update(serializeCV(data)).digest();
  const finalHash = sha256(Buffer.concat([structuredDataPrefix, domainHash, messageHash]));
  
  const signature = signWithKey(privateKey, finalHash.toString('hex')).data;
  return Buffer.from(signature.slice(2) + signature.slice(0, 2), 'hex');
}

// Helper for string-based messages
export function generateMessageSignature(message: string, privateKey: StacksPrivateKey): Buffer {
  return generateSignature(stringAsciiCV(message), privateKey);
}

// Helper for claim-license messages
export function generateClaimSignature(requestId: bigint, requester: string, privateKey: StacksPrivateKey): Buffer {
  const data = Cl.tuple({
    'request-id': Cl.uint(requestId),
    requester: Cl.principal(requester),
  });
  return generateSignature(data, privateKey);
}

