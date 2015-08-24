#!/bin/env racket
#lang racket

(require net/zmq)
(require json)

; https://jupyter-client.readthedocs.org/en/latest/messaging.html
; Four sockets:
;   - shell: requests from multiple clients for code execution, object info, etc.
;            communication is a sequence of request/reply actions.
;   - iopub: broadcast channel where kernel publishes side effects.
;   - stdin: allows the kernel to request input when raw_input() is called.
;   - control: identical to the shell, but on separate socket for important messages.

; Messages:
;   - header:
;      - msg_id: uuid
;      - username: str
;      - session: uuid
;      - msg_type: str
;      - version: '5.0'
;   - parent_header
;   - metadata
;   - content


(define connection-file (vector-ref (current-command-line-arguments) 0))
(define connection-file-port (open-input-file connection-file))
(match-define (hash-table ('transport conn-transport)
                          ('signature_scheme conn-signature-scheme)
                          ('hb_port conn-hb-port)
                          ('stdin_port conn-stdin-port)
                          ('shell_port conn-shell-port)
                          ('control_port conn-control-port)
                          ('key conn-key)
                          ('iopub_port conn-iopub-port)
                          ('ip conn-ip))
  (read-json connection-file-port))


(define (heartbeat addr)
  (define c (context 1))
  (define s (socket c 'REP))
  (socket-bind! s addr)
  (printf "Heartbeat on ~a\n" addr)
  (let loop ([msg (socket-recv! s)])
    (displayln msg)
    (socket-send! s msg)
    (loop (socket-recv! s))))

(define (make-addr transport ip port)
  (string-append transport "://" ip ":" (number->string port)))

(define hb-thread
  (thread (lambda () (heartbeat (make-addr conn-transport conn-ip conn-hb-port)))))

(printf "hello\n")

(thread-wait hb-thread)