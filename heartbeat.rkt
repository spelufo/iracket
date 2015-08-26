#lang racket

(require racket/place
         net/zmq)

(provide heartbeat)

(define (heartbeat hb-addr hb-ctxt)
  (define p
    (place ch
      (define c (place-channel-get ch))
      (define addr (place-channel-get ch))
      (call-with-socket c 'REP
        (lambda (s)
          (socket-bind! s addr)
          (printf "Bound heartbeat on: ~a\n" addr)
          (place-channel-put ch 'DONE)
          
          (let loop ([msg (socket-recv! s)])
            ; (printf "heartbeat!\n")
            (socket-send! s msg)
            (loop (socket-recv! s)))))))
  
  (place-channel-put p hb-ctxt)
  (place-channel-put p hb-addr)
  (place-channel-get p))
