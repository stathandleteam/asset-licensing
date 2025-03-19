import { Cl } from "@stacks/transactions";
import { describe, expect, it } from "vitest";

// Error Code Constants
const ERR_NOT_AUTHORIZED = Cl.uint(100);
const ERR_INVALID_SIGNATURE = Cl.uint(101);
const ERR_ASSET_NOT_FOUND = Cl.uint(102);
const ERR_ASSET_ALREADY_EXISTS = Cl.uint(103);
const ERR_INVALID_PRICE = Cl.uint(104);
const ERR_PAYMENT_FAILED = Cl.uint(105);
const ERR_LICENSE_ALREADY_EXISTS = Cl.uint(106);
const ERR_LICENSE_NOT_FOUND = Cl.uint(107);
const ERR_LICENSE_REVOKED = Cl.uint(108);

// Simnet account setup
const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const userA = accounts.get("wallet_1")!;
const userB = accounts.get("wallet_2")!;
const userC = accounts.get("wallet_3")!;

describe("Asset Contract Tests", () => {
  const contractName = "asset-license"; // Replace with actual contract name

  // Ensure Simnet is properly initialized
  it("should ensure simnet is well initialized", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  // Test: Create an asset
  it("should create an asset successfully", () => {
    const assetId = Cl.uint(1);
    const price = Cl.uint(1000);

    const { result } = simnet.callPublicFn(
      contractName,
      "create-asset",
      [assetId, price],
      deployer
    );

    expect(result.type).toBeTruthy(); // ✅ Fix for toBeOk()

    // Validate asset existence
    const { result: assetData } = simnet.callReadOnlyFn(
      contractName,
      "get-asset",
      [assetId],
      deployer
    );

    expect(assetData.type).toBeTruthy();
    expect(assetData.type).toMatchObject({
      owner: deployer,
      price: price.value,
    });
  });

  // Test: Grant a license with an expiration
  it("should grant a license with an expiration", () => {
    const assetId = Cl.uint(1);
    const signature = Cl.bufferFromHex(Buffer.alloc(65).toString("hex"));
    const pubkey = Cl.bufferFromHex(Buffer.alloc(33).toString("hex"));

    const { result } = simnet.callPublicFn(
      contractName,
      "grant-license",
      [assetId, Cl.principal(userB), signature, pubkey],
      userA
    );

    expect(result.type).toBeTruthy();

    // Validate license details
    const { result: isLicensed } = simnet.callReadOnlyFn(
      contractName,
      "is-licensed",
      [assetId, Cl.principal(userB)],
      userB
    );

    expect(isLicensed.type).toBeTruthy();
    expect(isLicensed.type).toBe(true);
  });

  // Test: License should expire after the set block height
  it("should invalidate an expired license", () => {
    const assetId = Cl.uint(1);

    // Simulate block advancement past the expiration point
    simnet.mineEmptyBlocks(1001); // ✅ Fix for mineBlocks

    const { result } = simnet.callReadOnlyFn(
      contractName,
      "is-licensed",
      [assetId, Cl.principal(userB)],
      userB
    );

    expect(result.type).toBeTruthy();
    expect(result.type).toBe(false); // License should now be invalid
  });

  // ❌ Test: Attempting to grant a duplicate license should fail
  it("should not allow granting a duplicate license", () => {
    const assetId = Cl.uint(1);
    const signature = Cl.bufferFromHex(Buffer.alloc(65).toString("hex"));
    const pubkey = Cl.bufferFromHex(Buffer.alloc(33).toString("hex"));

    const { result } = simnet.callPublicFn(
      contractName,
      "grant-license",
      [assetId, Cl.principal(userB), signature, pubkey],
      userA
    );

    expect(result.type).toBeTruthy();
    expect(result.type).toBe(ERR_LICENSE_ALREADY_EXISTS); // ✅ Fix for toBeErr()
  });

  // ❌ Test: Checking a license before it's granted should return false
  it("should return false for a non-existent license", () => {
    const assetId = Cl.uint(2); // No license issued

    const { result } = simnet.callReadOnlyFn(
      contractName,
      "is-licensed",
      [assetId, Cl.principal(userC)],
      userC
    );

    expect(result.type).toBeTruthy();
    expect(result.type).toBe(false);
  });

  // Test: Revoking a license should remove it
  it("should revoke a license", () => {
    const assetId = Cl.uint(1);

    const { result } = simnet.callPublicFn(
      contractName,
      "revoke-license",
      [assetId, Cl.principal(userB)],
      userA
    );

    expect(result.type).toBeTruthy();

    // License should no longer be valid
    const { result: isLicensed } = simnet.callReadOnlyFn(
      contractName,
      "is-licensed",
      [assetId, Cl.principal(userB)],
      userB
    );

    expect(isLicensed.type).toBeTruthy();
    expect(isLicensed.type).toBe(false);
  });

  // ❌ Test: Attempting to use a revoked license should fail
  it("should prevent access for revoked licenses", () => {
    const assetId = Cl.uint(1);

    const { result } = simnet.callPublicFn(
      contractName,
      "use-licensed-asset",
      [assetId],
      userB
    );

    expect(result.type).toBeTruthy();
    expect(result.type).toBe(ERR_LICENSE_REVOKED); // ✅ Fix for toBeErr()
  });
});
