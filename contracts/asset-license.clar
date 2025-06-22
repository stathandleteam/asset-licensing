;; ---------------------- Constants ----------------------
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_INVALID_SIGNATURE u101)
(define-constant ERR_ASSET_NOT_FOUND u102)
(define-constant ERR_ASSET_ALREADY_EXISTS u103)
(define-constant ERR_INVALID_PRICE u104)
(define-constant ERR_PAYMENT_FAILED u105)
(define-constant ERR_LICENSE_NOT_FOUND u107)
(define-constant ERR_LICENSE_REVOKED u108)
(define-constant ERR_NOT_ADMIN u109)
(define-constant ERR_REQUEST_NOT_FOUND u110)
(define-constant ERR_ASSET_DISABLED u111)
(define-constant ERR_NO_QUANTITY u112)

;; (define-constant platform-address (as-contract 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT))
(define-constant platform-fee-rate u10) ;; 10% fee
;; (define-constant sbtc-token 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token)
(define-constant platform-address (as-contract 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)) ;; Devnet deployer
;; (define-constant platform-fee-rate u10) ;; 10% fee
;; (define-constant sbtc-token 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sbtc) ;; Devnet sBTC;; ---------------------- Data Storage ----------------------

(define-data-var sale-asset-counter uint u0)
(define-data-var license-asset-counter uint u0)
(define-data-var request-counter uint u0)

(define-data-var license-counter uint u0)(define-map sale-assets 
  { id: uint } 
  { 
    owner: principal, 
    name: (string-utf8 50),
    metadata: (string-utf8 256), 
    price: uint, 
    disabled: bool,
    quantity: uint               ;; Number of available instances
  }
)

(define-map license-assets 
  { id: uint } 
  { 
    owner: principal, 
    name: (string-utf8 50),
    metadata: (string-utf8 256), 
    price: uint, 
    duration: uint,              ;; License duration in blocks
    disabled: bool
  }
)

(define-map licenses 
  { license-id: uint } 
  { 
    asset-id: uint,
    licensee: principal,
    valid-until: uint 
  }
)

(define-map license-requests
  { request-id: uint }
  { asset-id: uint, requester: principal, approved: bool, timestamp: uint }
);; ---------------------- Helper Functions ----------------------




(define-private (get-next-sale-asset-id)
  (let ((current-id (var-get sale-asset-counter)))
    (var-set sale-asset-counter (+ current-id u1))
    current-id))
    
(define-private (get-next-license-asset-id)
  (let ((current-id (var-get license-asset-counter)))
    (var-set license-asset-counter (+ current-id u1))
    current-id))
    
(define-private (get-next-request-id)
  (let ((current-id (var-get request-counter)))
    (var-set request-counter (+ current-id u1))
    current-id))
    
(define-private (get-next-license-id)
  (let ((current-id (var-get license-counter)))
    (var-set license-counter (+ current-id u1))
    current-id))
    
(define-private (is-platform-admin (caller principal))
  (is-eq caller platform-address));; ---------------------- Sale Asset Management ----------------------

(define-read-only (get-sale-asset (asset-id uint))
  (match (map-get? sale-assets { id: asset-id })
    some-data (ok some-data)
    (err ERR_ASSET_NOT_FOUND)))
    

(define-public (register-sale-asset (name (string-utf8 50)) (metadata (string-utf8 256)) (price uint) (quantity uint))
  (let ((asset-id (get-next-sale-asset-id)))
    (asserts! (> price u0) (err ERR_INVALID_PRICE))
    (asserts! (> quantity u0) (err ERR_NO_QUANTITY))
    (asserts! (is-none (map-get? sale-assets { id: asset-id })) (err ERR_ASSET_ALREADY_EXISTS))
    (map-insert sale-assets { id: asset-id } 
      { owner: tx-sender, name: name, metadata: metadata, price: price, disabled: false, quantity: quantity })
    (ok asset-id)))
    
(define-public (buy-sale-asset (asset-id uint))
  (let 
    (
      (asset-data (unwrap! (map-get? sale-assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND)))
      (seller (get owner asset-data))
      (price (get price asset-data))
      (platform-cut (/ (* price platform-fee-rate) u100))
      (seller-cut (- price platform-cut))
      (quantity (get quantity asset-data))
    )
    (asserts! (is-eq (get owner asset-data) seller) (err ERR_NOT_AUTHORIZED)) ;; Seller still owns it
    (asserts! (> quantity u0) (err ERR_NO_QUANTITY))
    (asserts! (> price u0) (err ERR_INVALID_PRICE))
    (asserts! (not (get disabled asset-data)) (err ERR_ASSET_DISABLED))

;; (try! (contract-call? sbtc-token transfer seller-cut tx-sender seller none))
;; (try! (contract-call? sbtc-token transfer platform-cut tx-sender platform-address none))
(try! (stx-transfer? seller-cut tx-sender seller))
(try! (stx-transfer? platform-cut tx-sender platform-address))

(map-set sale-assets { id: asset-id } 
  (merge asset-data { owner: tx-sender, quantity: (- quantity u1) }))
(ok true)))

(define-public (disable-sale-asset (asset-id uint))
(begin 
  (asserts! (is-platform-admin tx-sender) (err ERR_NOT_ADMIN))
  (match (map-get? sale-assets { id: asset-id })
    some-data
    (begin
      (map-set sale-assets { id: asset-id } 
        (merge some-data { disabled: true }))
      (ok "Sale asset disabled"))
    (err ERR_ASSET_NOT_FOUND)))
)

(define-public (enable-sale-asset (asset-id uint))
  (begin
  (asserts! (is-platform-admin tx-sender) (err ERR_NOT_ADMIN))
  (match (map-get? sale-assets { id: asset-id })
    some-data
    (begin
      (map-set sale-assets { id: asset-id } 
        (merge some-data { disabled: false }))
      (ok "Sale asset re-enabled"))
    (err ERR_ASSET_NOT_FOUND)))
)

;; ---------------------- License Asset Management ----------------------
(define-read-only (get-license-asset (asset-id uint))
  (match (map-get? license-assets { id: asset-id })
    some-data (ok some-data)
    (err ERR_ASSET_NOT_FOUND)))
    
(define-public (register-license-asset (name (string-utf8 50)) (metadata (string-utf8 256)) (price uint) (duration uint))
  (let ((asset-id (get-next-license-asset-id)))
    (asserts! (> price u0) (err ERR_INVALID_PRICE))
    (asserts! (> duration u0) (err ERR_INVALID_PRICE))
    (asserts! (is-none (map-get? license-assets { id: asset-id })) (err ERR_ASSET_ALREADY_EXISTS))
    (map-insert license-assets { id: asset-id } 
      { owner: tx-sender, name: name, metadata: metadata, price: price, duration: duration, disabled: false })
    (ok asset-id)))
    
(define-read-only (get-license-request (request-id uint))
  (match (map-get? license-requests { request-id: request-id })
    some-data (ok some-data)
    (err ERR_REQUEST_NOT_FOUND)))

(define-public (request-license (asset-id uint))
  (let ((asset-data (unwrap! (map-get? license-assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND))))
    (asserts! (not (get disabled asset-data)) (err ERR_ASSET_DISABLED))
    (let ((request-id (get-next-request-id))
          (price (get price asset-data)))
    ;;   (try! (contract-call? sbtc-token transfer price tx-sender (as-contract tx-sender) none))
        (try! (stx-transfer? price tx-sender platform-address))

  (map-insert license-requests { request-id: request-id } 
    { asset-id: asset-id, requester: tx-sender, approved: false, timestamp: stacks-block-height })
  (ok request-id))))

(define-public (debug-claim-license (request-id uint) (sig (buff 65)) (pubkey (buff 33)))
  (let (
    (request-data (unwrap! (map-get? license-requests { request-id: request-id }) (err ERR_REQUEST_NOT_FOUND)))
    (message (concat (unwrap-panic (to-consensus-buff? request-id))
                     (unwrap-panic (to-consensus-buff? (get requester request-data)))))
    (message-hash (sha256 message))
  )
  (ok (some {
    message: (some message),
    message-hash: (some message-hash),
    pubkey: (some pubkey),
    sig: (some sig)
  }))))

(define-public (claim-license (request-id uint) (sig (buff 65)) (pubkey (buff 33)))
  (let (
    (request-data (unwrap! (map-get? license-requests { request-id: request-id }) (err ERR_REQUEST_NOT_FOUND)))
    (asset-id (get asset-id request-data))
    (asset-data (unwrap! (map-get? license-assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND)))
    (message (concat (unwrap-panic (to-consensus-buff? request-id))
                     (unwrap-panic (to-consensus-buff? (get requester request-data)))))
    (message-hash (sha256 message))
    (is-valid (secp256k1-verify message-hash sig pubkey))
    (price (get price asset-data))
    (platform-cut (/ (* price platform-fee-rate) u100))
    (owner-cut (- price platform-cut))
    (owner (get owner asset-data))
    (licensee (get requester request-data))
    (license-id (get-next-license-id))
  )
  (asserts! is-valid (err ERR_INVALID_SIGNATURE))
  (asserts! (< (- stacks-block-height (get timestamp request-data)) u144) (err ERR_REQUEST_NOT_FOUND))
   ;;   (try! (as-contract (contract-call? sbtc-token transfer owner-cut tx-sender owner none)))
    (try! (stx-transfer? owner-cut tx-sender owner));;   (try! (as-contract (contract-call? sbtc-token transfer platform-cut tx-sender platform-address none)))
    (try! (stx-transfer? platform-cut tx-sender platform-address))  (map-set licenses { license-id: license-id }
    { asset-id: asset-id, licensee: licensee, valid-until: (+ stacks-block-height (get duration asset-data)) })
  (map-delete license-requests { request-id: request-id })
  (ok license-id)))
  
(define-public (revoke-license (license-id uint))
  (let 
    (
      (license-data (unwrap! (map-get? licenses { license-id: license-id }) (err ERR_LICENSE_NOT_FOUND)))
      (asset-id (get asset-id license-data))
      (asset-data (unwrap! (map-get? license-assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND)))
      (licensee (get licensee license-data))
    )
    (asserts! (or (is-eq tx-sender (get owner asset-data)) (is-eq tx-sender licensee)) (err ERR_NOT_AUTHORIZED))
    (map-delete licenses { license-id: license-id })
    (ok true)))
    
(define-public (disable-license-asset (asset-id uint))
  (begin 
  (asserts! (is-platform-admin tx-sender) (err ERR_NOT_ADMIN))
  (match (map-get? license-assets { id: asset-id })
    some-data
    (begin
      (map-set license-assets { id: asset-id } 
        (merge some-data { disabled: true }))
      (ok "License asset disabled"))
    (err ERR_ASSET_NOT_FOUND)))
)

(define-public (enable-license-asset (asset-id uint))
  (begin
  (asserts! (is-platform-admin tx-sender) (err ERR_NOT_ADMIN))
  (match (map-get? license-assets { id: asset-id })
    some-data
    (begin
      (map-set license-assets { id: asset-id } 
        (merge some-data { disabled: false }))
      (ok "License asset re-enabled"))
    (err ERR_ASSET_NOT_FOUND)))
)

;; ---------------------- License Utilities ----------------------
(define-read-only (is-licensed (license-id uint))
  (match (map-get? licenses { license-id: license-id })
    some-data (>= (get valid-until some-data) stacks-block-height)
    false))
    
(define-public (use-licensed-asset (license-id uint))
(begin 
  (asserts! (is-licensed license-id) (err ERR_LICENSE_REVOKED))
  (ok true)  ))




;; ----------------------Quick Test Functions ----------------------

(define-constant ERR_CONSENSUS_BUFF (err u1))
(define-constant STRUCTURED_DATA_HEADER 0x534950303138) ;; SIP018 prefix
(define-constant DOMAIN_HASH (sha256 (unwrap-panic (to-consensus-buff? {
  name: "BlockAssets",
  version: "1.0.0",
  ;; chain-id: chain-id
    chain-id: u2147483648

}))))

(define-constant structured-data-header (concat STRUCTURED_DATA_HEADER DOMAIN_HASH))


(define-read-only (make-message-hash (message (string-ascii 100)))
  (let (
      (data-hash (sha256 (unwrap! (to-consensus-buff? message) ERR_CONSENSUS_BUFF))))
          (ok (sha256 (concat structured-data-header data-hash)))))

    (define-read-only (make-claim-hash (request-id uint) (requester principal))
  (let (
      (data (tuple (request-id request-id) (requester requester)))
      (data-hash (sha256 (unwrap! (to-consensus-buff? data) ERR_CONSENSUS_BUFF))
      
      ))
          (ok (sha256 (concat structured-data-header data-hash)))))

(define-private (verify-hash-signature
    (hash (buff 32))
    (signature (buff 65))
    )
    
  (match (secp256k1-recover? hash signature)
    recovered-key (ok recovered-key)
    err-val (err ERR_INVALID_SIGNATURE)))
  
  (define-public (verify-frontend-message
    (message (string-ascii 100))
    (signature (buff 65))
  )
  (let (
      (message-hash (unwrap! (make-message-hash message) (err ERR_INVALID_SIGNATURE)))
      (verify-result (verify-hash-signature message-hash signature))
    )
    
    (match verify-result
      result (ok true)
      err-val (err err-val)
    )
  )
)


;; #[allow(unchecked_data)]
(define-read-only (recover-public-key
  (message-hash  (buff 32))  
  (signature (buff 65)))
       (ok (unwrap-panic (verify-hash-signature message-hash signature)))
    )


(define-read-only (verify-signature (hash (buff 32)) (signature (buff 65)) (signer principal))
	(is-eq (principal-of? (unwrap! (secp256k1-recover? hash signature) false)) (ok signer))
)

(define-public (test-claim-signature
  (request-id uint)
  (signature (buff 65))
  (signer principal)
  )
  (let (
      (request-data (map-get? license-requests { request-id: request-id })))
    (match request-data
      data (let (
          (message-hash-result (make-claim-hash request-id (get requester data))))
          
        (match message-hash-result
          message-hash (let (
            
              (verify-result (verify-hash-signature message-hash signature)))
              ;;  (match verify-result
              ;;   result (ok true)
              ;;   err-val (err err-val)
              ;; )
              
              
            (match verify-result
              recovered-key (ok (is-eq (principal-of? recovered-key) (ok signer)))
              err-val (err err-val))
            )

          err-val (err err-val)))
      (err ERR_REQUEST_NOT_FOUND))))

(define-public (test-claim-signature-debug
  (request-id uint)
  (signature (buff 65))
  (signer principal))
  (let (
      (request-data (map-get? license-requests { request-id: request-id })))
    (match request-data
      data (let (
          (message-hash-result (make-claim-hash request-id (get requester data))))
        (match message-hash-result
          message-hash (let (
              (verify-result (verify-hash-signature message-hash signature)))
            (match verify-result
              recovered-key (match (principal-of? recovered-key)
                              recovered-principal (ok recovered-principal)
                              none (err u100)) ;; Custom error for none
              err-val (err err-val)))
          err-val (err err-val)))
      (err ERR_REQUEST_NOT_FOUND))))