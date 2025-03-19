#### **Test Case 1: Register an Asset **

;; **Success Case:** Owner registers an asset
>> ::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
tx-sender switched to ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

>> (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.asset-license register-asset u1000)
(ok u1) ;; Updated: First ID is now u1

;; **Verify asset details**
>> (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.asset-license get-asset u1)
(ok (tuple (owner ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (price u1000) (duration none) (licensed false)))

;; **Failure Case:** User tries to register an asset with price 0
>> ::set_tx_sender ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
tx-sender switched to ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG

>> (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.asset-license register-asset u0)
(err u104) ;; ERR_INVALID_PRICE# asset-licensing
