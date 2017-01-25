#lang racket/base

(define STX? #f)

(define (remix-f f)
  (parameterize ([read-square-bracket-as-paren #f]
                 [read-curly-brace-as-paren #f]
                 [read-square-bracket-with-tag #t]
                 [read-curly-brace-with-tag #t]
                 [read-accept-dot #f]
                 [read-accept-infix-dot #f]
                 [read-cdot #t])
    (f)))

(define (remix-read) (remix-f read))
(define (remix-read-syntax) (remix-f read-syntax))

(module+ test
  (require rackunit
           racket/port)
  (define-syntax-rule (testit* t ...)
    (begin (testit . t) ...))
  (define-syntax-rule (testit str d)
    (testit-f str 'd #'d))

  (define (testit-f str qd stx)
    (check-equal? (with-input-from-string str remix-read) qd)
    (when STX?
      (check-equal? (with-input-from-string str remix-read-syntax) stx)))

  (check-false (read-square-bracket-with-tag))
  (check-false (read-curly-brace-with-tag))
  (check-false (read-cdot))

  (define-syntax-rule (test-only-with-tag* t ...)
    (begin (test-only-with-tag . t) ...))
  (define-syntax-rule (test-only-with-tag str d)
    (check-equal?
     (with-input-from-string str
       (λ ()
         (parameterize ([read-square-bracket-with-tag #t]
                        [read-curly-brace-with-tag #t])
           (read))))
     d))
  (test-only-with-tag*
   ["#(1 2)" (vector 1 2)]
   ["#[1 2]" (vector 1 2)]
   ["#{1 2}" (vector 1 2)]

   ["#hash((1 . 2))" (hash 1 2)]
   ["#hash[(1 . 2)]" (hash 1 2)]
   ["#hash[[1 . 2]]" (hash 1 2)]
   ["#hash([1 . 2])" (hash 1 2)]
   ["#hash{(1 . 2)}" (hash 1 2)]
   ["#hash{{1 . 2}}" (hash 1 2)]
   ["#hash({1 . 2})" (hash 1 2)])

  (define-syntax-rule (testerrors s ...)
    (begin
      (let ([x s])
        (check-exn exn:fail:read?
                   (λ () (with-input-from-string x remix-read)))
        (check-exn exn:fail:read?
                   (λ () (with-input-from-string x remix-read-syntax))))
      ...))

  (testerrors
   "x.")

  (testit*
   ["(1 2 3)" (1 2 3)]
   ["[1 2 3]" (#%brackets 1 2 3)]
   ["{1 2 3}" (#%braces 1 2 3)]
   ["|a.b|" a.b]
   ["a.b" (#%dot a b)]
   ["a .b" (#%dot a b)]
   ["a. b" (#%dot a b)]
   ["a . b" (#%dot a b)]
   ["1.a" (#%dot 1 a)]
   ["#i1.2 .a" (#%dot 1.2 a)]
   ["1 .2.a" (#%dot (#%dot 1 2) a)]
   ["a.#i1.2" (#%dot a 1.2)]
   ;; ((sprite.bbox).ul).x
   ["a.b.c" (#%dot (#%dot a b) c)]
   ["a.(b c)" (#%dot a (b c))]
   ["(a b).c" (#%dot (a b) c)]
   ["(a b).(c d)" (#%dot (a b) (c d))]
   ["(a b).[3]" (#%dot (a b) (#%brackets 3))]
   ["({1})" ((#%braces 1))]
   ["remix/stx.0" (#%dot remix/stx 0)]
   ["(require remix/stx.0)" (require (#%dot remix/stx 0))]

   ))
