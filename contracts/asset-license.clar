;; ---------------------- Constants ----------------------
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_INVALID_SIGNATURE u101)
(define-constant ERR_ASSET_NOT_FOUND u102)
(define-constant ERR_ASSET_ALREADY_EXISTS u103)   ;; Asset ID already exists
(define-constant ERR_INVALID_PRICE u104)
(define-constant ERR_PAYMENT_FAILED u105)
(define-constant ERR_LICENSE_ALREADY_EXISTS u106)
(define-constant ERR_LICENSE_NOT_FOUND u107)
(define-constant ERR_LICENSE_REVOKED u108)
(define-constant ERR_NOT_ADMIN u109)              ;; Caller is not the platform admin
(define-constant ERR_REQUEST_NOT_FOUND u110)
(define-constant ERR_ASSET_DISABLED u111)         ;; Asset is disabled

(define-constant platform-address (as-contract 'SP1KK2VMSSTSK1BY64SG2WFFFTMAGCY15FYTA90BS))
(define-constant platform-fee-rate u10) ;; 10% fee

(define-constant sbtc-token 'SP1KK2VMSSTSK1BY64SG2WFFFTMAGCY15FYTA90BS.sbtc-token)

;; ---------------------- Data Storage ----------------------
(define-data-var asset-counter uint u0)
(define-data-var request-counter uint u0)

(define-map assets 
  { id: uint } 
  { 
    owner: principal, 
    name: (string-utf8 50),
    metadata: (string-utf8 256), 
    status: (optional uint),     ;; `none` (not listed), `some u1` (for sale), `some u2` (for license)
    price: uint, 
    duration: (optional uint), 
    licensed: bool,
    disabled: bool 
  }
)

(define-map licenses 
  { asset-id: uint, licensee: principal } 
  { valid-until: uint }
)

(define-map license-requests
  { request-id: uint }
  { asset-id: uint, requester: principal, approved: bool }
)

;; ---------------------- Helper Functions ----------------------
(define-private (get-next-asset-id)
  (let ((current-id (var-get asset-counter)))
    (var-set asset-counter (+ current-id u1))
    current-id))


(define-private (get-next-request-id)
  (let ((current-id (var-get request-counter)))
    (var-set request-counter (+ current-id u1))
    current-id))

(define-private (is-platform-admin (caller principal))
  (is-eq caller platform-address))

;; ---------------------- Asset Management ----------------------
(define-read-only (get-asset (asset-id uint))
  (match (map-get? assets { id: asset-id })
    some-data (ok some-data)
    (err ERR_ASSET_NOT_FOUND)
  )
)

;; Register a new asset (Anyone can register an asset)
(define-public (register-asset (name (string-utf8 50)) (metadata (string-utf8 256)) (price uint))
  (let ((asset-id (get-next-asset-id)))
    (if (> price u0)
        (begin
          (map-insert assets { id: asset-id } 
            { owner: tx-sender, name: name, metadata: metadata, price: price, duration: none, licensed: false, disabled: false, status: none })
          (ok asset-id)
        )
        (err ERR_INVALID_PRICE)
    )
  )
)

(define-public (list-asset-for-sale (asset-id uint) (price uint))

 (let ((asset-data (unwrap! (map-get? assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND))))
    (asserts! (is-eq tx-sender (get owner asset-data)) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (get disabled asset-data)) (err ERR_ASSET_DISABLED))
    (asserts! (not (get licensed asset-data)) (err ERR_LICENSE_ALREADY_EXISTS)) ;; Ensure asset is NOT licensed
                (map-set assets { id: asset-id } 
                  (merge asset-data { price: price, status: (some u1), duration: none })) ;; Set status to `for sale`
                (ok true)
              )
)

(define-public (buy-asset (asset-id uint) (new-owner principal))
  (let 
    (
      (asset-data (unwrap! (map-get? assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND)))
      (seller (get owner asset-data))
      (price (get price asset-data))
      (platform-cut (/ (* price platform-fee-rate) u100))
      (seller-cut (- price platform-cut))
    )
    (asserts! (> price u0) (err ERR_INVALID_PRICE))
    (asserts! (is-eq tx-sender new-owner) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (get disabled asset-data)) (err ERR_ASSET_DISABLED))

    ;; Process payments directly
    (try!  (contract-call? sbtc-token transfer seller-cut tx-sender seller none)) ;; Payment to seller
    (try!  (contract-call? sbtc-token transfer platform-cut tx-sender platform-address none)) ;; Platform fee

    ;; (try! (stx-transfer? seller-cut tx-sender seller)) ;; Payment to seller
    ;; (try! (stx-transfer? platform-cut tx-sender platform-address)) ;; Platform fee

    ;; Transfer asset ownership
    (map-set assets { id: asset-id } 
      (merge asset-data { owner: new-owner }))

    (ok true)
  )
)

;; Disable an asset (Admin only)
(define-public (disable-asset (asset-id uint))
  (if (is-platform-admin tx-sender)
      (match (map-get? assets { id: asset-id })
        some-data
        (begin
          (map-set assets { id: asset-id } 
            (merge some-data { disabled: true }))
          (ok "Asset disabled")
        )
        (err ERR_ASSET_NOT_FOUND)
      )
      (err ERR_NOT_ADMIN)
  )
)

;; Enable an asset (Admin only)
(define-public (enable-asset (asset-id uint))
  (if (is-platform-admin tx-sender)
      (match (map-get? assets { id: asset-id })
        some-data
        (begin
          (map-set assets { id: asset-id } 
            (merge some-data { disabled: false }))
          (ok "Asset re-enabled")
        )
        (err ERR_ASSET_NOT_FOUND)
      )
      (err ERR_NOT_ADMIN)
  )
)


;; ---------------------- Licensing ----------------------

;; List asset for licensing (Only asset owner)
(define-public (list-asset-for-license (asset-id uint) (price uint) (duration uint))
 (let ((asset-data (unwrap! (map-get? assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND))))
    (asserts! (is-eq tx-sender (get owner asset-data)) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (get disabled asset-data)) (err ERR_ASSET_DISABLED))
    (asserts! (not (get licensed asset-data)) (err ERR_LICENSE_ALREADY_EXISTS)) ;; Ensure asset is NOT licensed
    (asserts! (> duration u0) (err ERR_INVALID_PRICE))
    (map-set assets { id: asset-id } 
      (merge asset-data { price: price, status: (some u2), duration: (some duration), licensed: false }))
    (ok true)
  )
)

  (define-public (request-license (asset-id uint))
    (let ((asset-data (unwrap! (map-get? assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND))))
      (if (get disabled asset-data)
          (err ERR_ASSET_DISABLED)
          (let ((request-id (get-next-request-id))
                (price (get price asset-data)))
            (begin
              (try! (contract-call? sbtc-token transfer price tx-sender (as-contract tx-sender) none)) ;; Escrow in contract
              ;; (try! (stx-transfer? price tx-sender (as-contract tx-sender))) ;; Lock escrow in contract
              (map-insert license-requests { request-id: request-id } 
                { asset-id: asset-id, requester: tx-sender, approved: false })
              (ok request-id)
            )
          )
      )
    )
  )

(define-public (claim-license (request-id uint) (sig (buff 65)) (pubkey (buff 33)))
  (let ((request-data (unwrap! (map-get? license-requests { request-id: request-id }) (err ERR_REQUEST_NOT_FOUND)))
        (asset-data (unwrap! (map-get? assets { id: (get asset-id request-data) }) (err ERR_ASSET_NOT_FOUND)))
        (message (concat (unwrap-panic (to-consensus-buff? request-id))
                         (unwrap-panic (to-consensus-buff? (get requester request-data)))))
        (message-hash (sha256 message))
        (is-valid (secp256k1-verify message-hash sig pubkey))
        (price (get price asset-data))
        (platform-cut (/ (* price platform-fee-rate) u100))
        (owner-cut (- price platform-cut))
    )
    
    (if is-valid
        (let (
              (payment-1 (as-contract (contract-call? sbtc-token transfer owner-cut tx-sender (get owner asset-data) none)))
              (payment-2 (as-contract (contract-call? sbtc-token transfer platform-cut tx-sender platform-address none)))

              ;; (payment-1 (as-contract (stx-transfer? owner-cut tx-sender (get owner asset-data))))
              ;; (payment-2 (as-contract (stx-transfer? platform-cut tx-sender platform-address)))
              
              )
          (if (and (is-ok payment-1) (is-ok payment-2))
              (begin
                (map-set licenses { asset-id: (get asset-id request-data), licensee: (get requester request-data) }
                  { valid-until: (+ stacks-block-height (unwrap! (get duration asset-data) (err ERR_INVALID_PRICE))) })
                (map-delete license-requests { request-id: request-id }) ;; Remove request
                (ok "License granted")
              )
              (err ERR_PAYMENT_FAILED)
          )
        )
        (err ERR_INVALID_SIGNATURE)
    )
  )
)


(define-public (revoke-license (asset-id uint) (licensee principal))
  (let 
    (
      (asset-data (unwrap! (map-get? assets { id: asset-id }) (err ERR_ASSET_NOT_FOUND)))
      (license-data (map-get? licenses { asset-id: asset-id, licensee: licensee }))
    )
    (asserts! (or (is-eq tx-sender (get owner asset-data)) (is-eq tx-sender licensee)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-some license-data) (err ERR_LICENSE_NOT_FOUND))
    (map-delete licenses { asset-id: asset-id, licensee: licensee })
    (map-set assets { id: asset-id } 
      (merge asset-data { licensed: false }))
    (ok true)
  )
)

(define-read-only (is-licensed (asset-id uint) (licensee principal))
  (match (map-get? licenses { asset-id: asset-id, licensee: licensee })
    some-data (>= (get valid-until some-data) stacks-block-height)
    false
  )
)

(define-public (use-licensed-asset (asset-id uint))
  (if (is-licensed asset-id tx-sender)
      (ok true)
      (err ERR_LICENSE_REVOKED)
  )
)