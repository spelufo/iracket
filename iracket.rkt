#!/bin/env racket
#lang racket

(require json
         net/zmq
         libuuid
         ffi/unsafe
         racket/date
         racket/place
         grommet/crypto/hmac
         "heartbeat.rkt")

(define connection-file (vector-ref (current-command-line-arguments) 0))
(define connection-file-port (open-input-file connection-file))
(match-define (hash-table ('transport transport)
                          ('signature_scheme signature-scheme)
                          ('hb_port heartbeat-port)
                          ('stdin_port stdin-port)
                          ('shell_port shell-port)
                          ('control_port control-port)
                          ('key key)
                          ('iopub_port iopub-port)
                          ('ip ip))
  (read-json connection-file-port))

(define (addr port)
  (string-append transport "://" ip ":" (number->string port)))

(printf "KEY: ~a\n" key)

(define zmq-context (context 1))

(define shell-socket (socket zmq-context 'ROUTER))
(socket-bind! shell-socket (addr shell-port))
(printf "Bound shell socket on: ~a\n" (addr shell-port))

; (define control-socket (socket zmq-context 'ROUTER))
; (socket-bind! control-socket (addr control-port))
; (printf "Bound control socket on: ~a\n" (addr control-port))

; (define stdin-socket (socket zmq-context 'ROUTER))
; (socket-bind! stdin-socket (addr stdin-port))
; (printf "Bound stdin socket on: ~a\n" (addr stdin-port))

(define iopub-socket (socket zmq-context 'PUB))
(socket-bind! iopub-socket (addr iopub-port))
(printf "Bound iopub socket on: ~a\n" iopub-port)

(define DELIM #"<IDS|MSG>")
(define kernel-session (uuid-generate))
(define kernel-user "kernel")
(define protocol-version "5.0")

(define (make-header msg-type)
  `#hasheq(
     (date . ,(parameterize ([date-display-format 'iso-8601]) (date->string (current-date))))
     (msg_id . ,(uuid-generate))
     (username . ,kernel-user)
     (session . ,kernel-session)
     (msg_type . ,msg-type)
     (version . ,protocol-version)))

(define (send-multipart sock parts)
  (printf "Sending parts: ~a\n" parts)
  (let loop ([p parts])
    (define more? (empty? (cddr p)))
    (define m (make-msg-with-data (car p)))
    (socket-send-msg! m sock (if more? 'SNDMORE empty))
    (msg-close! m)
    (free m)
    (when more? (loop (cdr p)))))

; (define (send-multipart sock parts)
  

(define (send sock msg-type [content #hasheq()] [parent #hasheq()] [metadata #hasheq()] [identities empty])
  (define header (make-header msg-type))
  (define msg-parts (map jsexpr->bytes (list header parent metadata content)))
  ; (define signature (hmac-sha256 key (apply bytes-append msg-parts)))
  (define signature #"")
  (send-multipart sock (append identities (list DELIM signature) msg-parts)))

(define (recv sock)
  (define identities
    (let loop ([id (socket-recv! sock)])
      (if (equal? id DELIM)
          empty
          (cons id (loop (socket-recv! sock))))))
  (let ([signature (socket-recv! sock)]
        [header    (bytes->jsexpr (socket-recv! sock))]
        [parent    (bytes->jsexpr (socket-recv! sock))]
        [metadata  (bytes->jsexpr (socket-recv! sock))]
        [content   (bytes->jsexpr (socket-recv! sock))])
    ;; TODO: (verify-signature ... )
    (printf "Recieved:\n\t~s\n\t~s\n\t~s\n\t~s\n\t~s\n" identities header parent metadata content)
    (values identities header parent metadata content)))


(define (handle-msg ids header parent metadata content)
  (define handler
    (case (hash-ref header 'msg_type)
      [("kernel_info_request") (lambda (ids header parent meta content)
                                 (printf "kernel info req\n")
                                 (define c
                                   `#hasheq(
                                     (protocol_version . ,protocol-version)
                                     (ipython_version . "4.0.0")
                                     (language_version . "6.2.1")
                                     (language . "racket")
                                     (implementation . "racket")
                                     (implementation_version . "0.1")
                                     (language_info . #hasheq(
                                         (name . "racket")
                                         (version . "1.0")
                                         (mimetype . "text/x-racket")
                                         (file_extension . ".rkt")
                                         (pygments_lexer . "racket")
                                         (codemirror_mode . "scheme")
                                         (nbconvert_exporter . "")))
                                     (banner . "Welcome to iracket")))
                                 (send shell-socket "kernel_info_reply" c header #hasheq() ids))]
                    

      [("execute_request") (lambda (ids header parent meta content)
                             (printf "exec req\n")
                             
                             (send iopub-socket "status" `#hasheq((execution_state . "busy")) header)
                             
                             (send iopub-socket "execute_input" `#hasheq((code . ,(hash-ref content 'code))
                                                                         (execution_count . 1)) header)
                             
                             (send iopub-socket "execute_result" #hasheq((metadata . #hasheq())
                                                                         (data . #hasheq((text/plain . "42!!!")))
                                                                         (execution_count . 1)) header)
                             
                             (send iopub-socket "status" #hasheq((execution_state . "idle")) header)
                             
                             (send shell-socket "execute_reply" #hasheq((status . "OK") (execution_count . 1)) header #hasheq() ids))]
      
      [("history_request") (lambda (ids header parent meta content)
                             (printf "history req\n"))]
      
      [("comm_open") (lambda (ids header parent meta content)
                       (send shell-socket "comm_close" `#hasheq((comm_id . ,(hash-ref content 'comm_id))
                                                                (data . #hasheq())) header #hasheq() ids))]

      [("shutdown_request") (lambda (ids header parent meta content) (exit))]

      [else (lambda (i h p m c) (printf "Unkown request type: ~a.\n" (hash-ref header 'msg_type)))]))
  
  (handler ids header parent metadata content))


(heartbeat (addr heartbeat-port) zmq-context)

(let recv-loop ()
  (call-with-values
    (lambda () (recv shell-socket))
    handle-msg)
  (recv-loop))