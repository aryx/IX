; The queens, by lists: a board is the rows of the queens placed so
; far, the last column's first. (docs/plans/plan_scheme.md, stage 2:
; the file that mini-9pi's session runs; five queens there and not
; eight, whose 92 boards are 3.4 million steps of the machine: ten
; minutes under mini-qemu.)
(define (safe? row dist placed)
  (or (null? placed)
      (and (not (= (car placed) row))
           (not (= (abs (- (car placed) row)) dist))
           (safe? row (+ dist 1) (cdr placed)))))

; the boards of k more columns over each board of boards, n rows
(define (extend n boards)
  (define (rows row board acc)
    (if (> row n)
        acc
        (rows (+ row 1) board
              (if (safe? row 1 board) (cons (cons row board) acc) acc))))
  (define (all boards acc)
    (if (null? boards) acc (all (cdr boards) (rows 1 (car boards) acc))))
  (all boards '()))

(define (queens n)
  (define (go k boards) (if (= k 0) boards (go (- k 1) (extend n boards))))
  (go n '(())))

(define (first-of l) (if (null? (cdr l)) (car l) (first-of (cdr l))))

(display "the five queens: ")
(length (queens 5))
(first-of (queens 5))
