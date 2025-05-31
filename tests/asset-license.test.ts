// tests/asset-license.test.ts
import { Cl, createStacksPrivateKey } from '@stacks/transactions';
import { describe, it, expect } from 'vitest';

describe('Marketplace Contract', () => {
  // Setup accounts
  const accounts = simnet.getAccounts();
  const wallet1 = accounts.get('wallet_1')!;
  const wallet2 = accounts.get('wallet_2')!;
  const contractName = 'asset-license';


  it('ensures simnet is well initialized', () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it('should allow creator to register a sale asset', () => {
    const { result } = simnet.callPublicFn(
      contractName,
      'register-sale-asset',
      [
        Cl.stringUtf8('Painting'),
        Cl.stringUtf8('https://example.com/painting.jpg'),
        Cl.uint(1000000), // 1 STX (in microSTX)
        Cl.uint(2), // Quantity
      ],
      wallet1
    );
    expect(result).toBeOk(Cl.uint(0));

    const { result: asset } = simnet.callReadOnlyFn(
      contractName,
      'get-sale-asset',
      [Cl.uint(0)],
      wallet1
    );
    expect(asset).toBeOk(
      Cl.tuple({
        owner: Cl.principal(wallet1),
        name: Cl.stringUtf8('Painting'),
        metadata: Cl.stringUtf8('https://example.com/painting.jpg'),
        price: Cl.uint(1000000),
        disabled: Cl.bool(false),
        quantity: Cl.uint(2),
      })
    );
  });

  it('should allow creator to register a license asset', () => {
    const { result } = simnet.callPublicFn(
      contractName,
      'register-license-asset',
      [
        Cl.stringUtf8('Music'),
        Cl.stringUtf8('https://example.com/music.mp3'),
        Cl.uint(500000), // 0.5 STX
        Cl.uint(100), // Duration
      ],
      wallet1
    );
    expect(result).toBeOk(Cl.uint(0));

    const { result: asset } = simnet.callReadOnlyFn(
      contractName,
      'get-license-asset',
      [Cl.uint(0)],
      wallet1
    );
    expect(asset).toBeOk(
      Cl.tuple({
        owner: Cl.principal(wallet1),
        name: Cl.stringUtf8('Music'),
        metadata: Cl.stringUtf8('https://example.com/music.mp3'),
        price: Cl.uint(500000),
        duration: Cl.uint(100),
        disabled: Cl.bool(false),
      })
    );
  });

  it('should allow buyer to purchase a sale asset', () => {
    // Setup: Register sale asset
    simnet.callPublicFn(
      contractName,
      'register-sale-asset',
      [
        Cl.stringUtf8('Painting'),
        Cl.stringUtf8('https://example.com/painting.jpg'),
        Cl.uint(1000000), // 1 STX
        Cl.uint(2),
      ],
      wallet1
    );

    // Debug: Verify asset exists
    const { result: assetBefore } = simnet.callReadOnlyFn(
      contractName,
      'get-sale-asset',
      [Cl.uint(0)],
      wallet2
    );
    expect(assetBefore).toBeOk(
      Cl.tuple({
        owner: Cl.principal(wallet1),
        name: Cl.stringUtf8('Painting'),
        metadata: Cl.stringUtf8('https://example.com/painting.jpg'),
        price: Cl.uint(1000000),
        disabled: Cl.bool(false),
        quantity: Cl.uint(2),
      })
    );

    // Fund wallet2 with STX
    // simnet.transferStx(10000000, wallet2, deployer); // 10 STX

    // Verify STX balance
    // const wallet2Balance = simnet.getStxBalance(wallet2);
    // expect(wallet2Balance).toBeGreaterThanOrEqual(1000000);

    // Buy asset
    const { result } = simnet.callPublicFn(
      contractName,
      'buy-sale-asset',
      [Cl.uint(0)],
      wallet2
    );
    expect(result).toBeOk(Cl.bool(true));

    // Verify updated asset
    const { result: asset } = simnet.callReadOnlyFn(
      contractName,
      'get-sale-asset',
      [Cl.uint(0)],
      wallet2
    );
    expect(asset).toBeOk(
      Cl.tuple({
        owner: Cl.principal(wallet2),
        name: Cl.stringUtf8('Painting'),
        metadata: Cl.stringUtf8('https://example.com/painting.jpg'),
        price: Cl.uint(1000000),
        disabled: Cl.bool(false),
        quantity: Cl.uint(1),
      })
    );
  });

  it('should fail to purchase when quantity is 0', () => {
    // Setup: Register sale asset with 1 quantity
    simnet.callPublicFn(
      contractName,
      'register-sale-asset',
      [
        Cl.stringUtf8('Painting'),
        Cl.stringUtf8('https://example.com/painting.jpg'),
        Cl.uint(1000000),
        Cl.uint(1),
      ],
      wallet1
    );

    // Buy once to reduce quantity to 0
    // simnet.transferStx(10000000, wallet2, deployer);
    simnet.callPublicFn(contractName, 'buy-sale-asset', [Cl.uint(0)], wallet2);

    // Try to buy again (should fail)
    const { result } = simnet.callPublicFn(
      contractName,
      'buy-sale-asset',
      [Cl.uint(0)],
      wallet2
    );
    expect(result).toBeErr(Cl.uint(112)); // ERR_NO_QUANTITY
  });

  it('should allow licensee to request a license', () => {
    // Setup: Register license asset
    simnet.callPublicFn(
      contractName,
      'register-license-asset',
      [
        Cl.stringUtf8('Music'),
        Cl.stringUtf8('https://example.com/music.mp3'),
        Cl.uint(500000),
        Cl.uint(100),
      ],
      wallet1
    );

    // Fund wallet2
    // simnet.transferStx(10000000, wallet2, deployer);

    // Get block height before request
    const blockHeightBefore = simnet.blockHeight;

    // Request license
    const { result } = simnet.callPublicFn(
      contractName,
      'request-license',
      [Cl.uint(0)],
      wallet2
    );
    expect(result).toBeOk(Cl.uint(0));

    // Verify request
    const { result: request } = simnet.callReadOnlyFn(
      contractName,
      'get-license-request',
      [Cl.uint(0)],
      wallet2
    );
    expect(request).toBeOk(
      Cl.tuple({
        'asset-id': Cl.uint(0),
        requester: Cl.principal(wallet2),
        approved: Cl.bool(false),
        timestamp: Cl.uint(blockHeightBefore + 1), // Adjust based on block height
      })
    );
  });


 
});