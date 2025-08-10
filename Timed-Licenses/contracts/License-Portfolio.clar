;; Digital Licensing Authority Smart Contract
;; A comprehensive blockchain-based system for creating, managing, and transferring
;; time-bound digital licenses with granular access controls, ownership verification,
;; and administrative oversight for decentralized license management

;; CONTRACT STATE VARIABLES

(define-data-var contract-administrator principal tx-sender)
(define-data-var license-counter uint u0)
(define-data-var system-paused bool false)
(define-data-var portfolio-filter-temp uint u0)

;; DATA STORAGE STRUCTURES

;; Core license registry containing all license metadata and ownership information
(define-map digital-license-registry
  uint
  {
    license-holder: principal,
    issue-timestamp: uint,
    expiration-timestamp: uint,
    transfer-allowed: bool,
    license-status: bool,
    metadata-reference: (string-ascii 256)
  }
)

;; User license portfolio mapping (capped at 20 licenses per holder)
(define-map license-holder-portfolios 
  principal 
  (list 20 uint)
)

;; ERROR CODE DEFINITIONS

(define-constant ERR-INSUFFICIENT-PERMISSIONS u100)
(define-constant ERR-INVALID-LICENSE-IDENTIFIER u101)
(define-constant ERR-LICENSE-TIME-EXPIRED u102)
(define-constant ERR-TRANSFER-RESTRICTIONS-ACTIVE u103)
(define-constant ERR-SYSTEM-MAINTENANCE-MODE u104)
(define-constant ERR-REDUNDANT-OWNERSHIP-REQUEST u105)
(define-constant ERR-INVALID-TIME-DURATION u106)
(define-constant ERR-PORTFOLIO-CAPACITY-EXCEEDED u107)
(define-constant ERR-DUPLICATE-LICENSE-ENTRY u108)
(define-constant ERR-INVALID-WALLET-ADDRESS u109)
(define-constant ERR-MISSING-METADATA-REFERENCE u110)

;; SYSTEM CONFIGURATION CONSTANTS

(define-constant maximum-licenses-per-holder u20)
(define-constant minimum-license-validity-period u1)
(define-constant system-null-address 'SP000000000000000000002Q6VF78)

;; PUBLIC READ-ONLY QUERY FUNCTIONS

(define-read-only (retrieve-license-details (license-identifier uint))
  (map-get? digital-license-registry license-identifier)
)

(define-read-only (get-holder-license-collection (wallet-address principal))
  (default-to (list) (map-get? license-holder-portfolios wallet-address))
)

(define-read-only (verify-license-validity (license-identifier uint))
  (match (map-get? digital-license-registry license-identifier)
    license-data (let ((current-block-time (default-to u0 (get-block-info? time u0))))
                   (and 
                     (get license-status license-data) 
                     (< current-block-time (get expiration-timestamp license-data))
                   ))
    false
  )
)

(define-read-only (get-total-issued-licenses)
  (var-get license-counter)
)

(define-read-only (verify-administrative-privileges)
  (is-eq tx-sender (var-get contract-administrator))
)

(define-read-only (check-system-operational-status)
  (var-get system-paused)
)

;; PRIVATE VALIDATION UTILITY FUNCTIONS

(define-private (validate-wallet-address (wallet-address principal))
  (and 
    (not (is-eq wallet-address system-null-address))
    true
  )
)

(define-private (validate-metadata-content (metadata-reference (string-ascii 256)))
  (> (len metadata-reference) u0)
)

(define-private (validate-duration-period (duration-in-blocks uint))
  (>= duration-in-blocks minimum-license-validity-period)
)

;; PRIVATE PORTFOLIO MANAGEMENT FUNCTIONS

(define-private (append-license-to-portfolio (wallet-address principal) (license-identifier uint))
  (begin
    (asserts! (validate-wallet-address wallet-address) (err ERR-INVALID-WALLET-ADDRESS))
    
    (let (
      (existing-license-collection (default-to (list) (map-get? license-holder-portfolios wallet-address)))
      (license-already-exists (is-some (index-of existing-license-collection license-identifier)))
    )
      (if license-already-exists
        (err ERR-DUPLICATE-LICENSE-ENTRY)
        (if (>= (len existing-license-collection) (- maximum-licenses-per-holder u1))
          (err ERR-PORTFOLIO-CAPACITY-EXCEEDED)
          (begin
            (map-set license-holder-portfolios wallet-address 
              (unwrap! (as-max-len? (concat existing-license-collection (list license-identifier)) u20) 
                      (err ERR-PORTFOLIO-CAPACITY-EXCEEDED)))
            (ok true)
          )
        )
      )
    )
  )
)

(define-private (license-filter-predicate (license-identifier uint))
  (not (is-eq license-identifier (var-get portfolio-filter-temp)))
)

(define-private (remove-license-from-portfolio (wallet-address principal) (license-identifier uint))
  (begin
    (asserts! (validate-wallet-address wallet-address) (err ERR-INVALID-WALLET-ADDRESS))
    
    (let ((existing-license-collection (default-to (list) (map-get? license-holder-portfolios wallet-address))))
      (var-set portfolio-filter-temp license-identifier)
      (map-set license-holder-portfolios wallet-address 
        (filter license-filter-predicate existing-license-collection)
      )
    )
    (ok true)
  )
)

;; PRIMARY LICENSE MANAGEMENT FUNCTIONS

(define-public (issue-new-digital-license 
                (license-recipient principal) 
                (validity-duration-blocks uint) 
                (enable-transfers bool)
                (metadata-reference (string-ascii 256)))
  (begin
    ;; System and permission validations
    (asserts! (not (var-get system-paused)) (err ERR-SYSTEM-MAINTENANCE-MODE))
    (asserts! (verify-administrative-privileges) (err ERR-INSUFFICIENT-PERMISSIONS))
    (asserts! (validate-duration-period validity-duration-blocks) (err ERR-INVALID-TIME-DURATION))
    (asserts! (validate-wallet-address license-recipient) (err ERR-INVALID-WALLET-ADDRESS))
    (asserts! (validate-metadata-content metadata-reference) (err ERR-MISSING-METADATA-REFERENCE))
    
    (let ((new-license-identifier (+ (var-get license-counter) u1))
          (current-block-timestamp (default-to u0 (get-block-info? time u0)))
          (calculated-expiration (+ current-block-timestamp validity-duration-blocks)))
      
      ;; Update license counter
      (var-set license-counter new-license-identifier)
      
      ;; Register new license in system
      (map-set digital-license-registry new-license-identifier
        {
          license-holder: license-recipient,
          issue-timestamp: current-block-timestamp,
          expiration-timestamp: calculated-expiration,
          transfer-allowed: enable-transfers,
          license-status: true,
          metadata-reference: metadata-reference
        }
      )
      
      ;; Add to recipient's license portfolio
      (let ((portfolio-update-result (append-license-to-portfolio license-recipient new-license-identifier)))
        (match portfolio-update-result
          success-indicator (ok new-license-identifier)
          error-code (begin
            ;; Rollback operations on portfolio failure
            (map-delete digital-license-registry new-license-identifier)
            (var-set license-counter (- new-license-identifier u1))
            (err error-code)
          )
        )
      )
    )
  )
)

(define-public (execute-license-transfer (license-identifier uint) (recipient-wallet principal))
  (begin
    ;; Validate recipient address
    (asserts! (validate-wallet-address recipient-wallet) (err ERR-INVALID-WALLET-ADDRESS))
    
    ;; Retrieve license information
    (let ((license-data-optional (map-get? digital-license-registry license-identifier)))
      (asserts! (is-some license-data-optional) (err ERR-INVALID-LICENSE-IDENTIFIER))
      
      (let ((license-information (unwrap-panic license-data-optional)))
        ;; Verify transfer prerequisites
        (asserts! (not (var-get system-paused)) (err ERR-SYSTEM-MAINTENANCE-MODE))
        (asserts! (is-eq tx-sender (get license-holder license-information)) (err ERR-INSUFFICIENT-PERMISSIONS))
        (asserts! (get transfer-allowed license-information) (err ERR-TRANSFER-RESTRICTIONS-ACTIVE))
        (asserts! (get license-status license-information) (err ERR-INVALID-LICENSE-IDENTIFIER))
        
        ;; Verify license hasn't expired
        (let ((current-block-timestamp (default-to u0 (get-block-info? time u0))))
          (asserts! (< current-block-timestamp (get expiration-timestamp license-information)) (err ERR-LICENSE-TIME-EXPIRED))
        )
        
        ;; Prevent self-transfer operations
        (asserts! (not (is-eq tx-sender recipient-wallet)) (err ERR-REDUNDANT-OWNERSHIP-REQUEST))
        
        ;; Execute ownership transfer
        (let ((recipient-portfolio-update (append-license-to-portfolio recipient-wallet license-identifier)))
          (asserts! (is-ok recipient-portfolio-update) (err (unwrap-err-panic recipient-portfolio-update)))
          
          ;; Remove from current holder's portfolio
          (unwrap-panic (remove-license-from-portfolio tx-sender license-identifier))
          
          ;; Update license ownership record
          (map-set digital-license-registry license-identifier
            (merge license-information { license-holder: recipient-wallet })
          )
          
          (ok true)
        )
      )
    )
  )
)

(define-public (extend-license-validity (license-identifier uint) (extension-blocks uint))
  (begin
    (asserts! (validate-duration-period extension-blocks) (err ERR-INVALID-TIME-DURATION))
    
    (let ((license-data-optional (map-get? digital-license-registry license-identifier)))
      (asserts! (is-some license-data-optional) (err ERR-INVALID-LICENSE-IDENTIFIER))
      
      (let ((license-information (unwrap-panic license-data-optional)))
        (asserts! (not (var-get system-paused)) (err ERR-SYSTEM-MAINTENANCE-MODE))
        (asserts! (or (verify-administrative-privileges) 
                     (is-eq tx-sender (get license-holder license-information))) (err ERR-INSUFFICIENT-PERMISSIONS))
        
        ;; Update license with extended validity period
        (map-set digital-license-registry license-identifier
          (merge license-information 
            { 
              expiration-timestamp: (+ (get expiration-timestamp license-information) extension-blocks),
              license-status: true
            }
          )
        )
        
        (ok true)
      )
    )
  )
)

(define-public (revoke-digital-license (license-identifier uint))
  (begin
    (let ((license-data-optional (map-get? digital-license-registry license-identifier)))
      (asserts! (is-some license-data-optional) (err ERR-INVALID-LICENSE-IDENTIFIER))
      
      (let ((license-information (unwrap-panic license-data-optional)))
        (asserts! (not (var-get system-paused)) (err ERR-SYSTEM-MAINTENANCE-MODE))
        (asserts! (verify-administrative-privileges) (err ERR-INSUFFICIENT-PERMISSIONS))
        
        ;; Deactivate license immediately
        (map-set digital-license-registry license-identifier
          (merge license-information { license-status: false })
        )
        
        (ok true)
      )
    )
  )
)

;; SYSTEM ADMINISTRATION FUNCTIONS

(define-public (transfer-administrative-control (new-administrator principal))
  (begin
    (asserts! (verify-administrative-privileges) (err ERR-INSUFFICIENT-PERMISSIONS))
    (asserts! (validate-wallet-address new-administrator) (err ERR-INVALID-WALLET-ADDRESS))
    (var-set contract-administrator new-administrator)
    (ok true)
  )
)

(define-public (toggle-system-operations (pause-system bool))
  (begin
    (asserts! (verify-administrative-privileges) (err ERR-INSUFFICIENT-PERMISSIONS))
    (var-set system-paused pause-system)
    (ok true)
  )
)