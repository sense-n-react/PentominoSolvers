;;-*- coding:utf-8 -*-

;;
;; Pentomino Puzzle Solver with LISP
;;

;; global vars
(defvar *debug-flg* nil)

(defvar *pieces* (make-hash-table))
(defvar *next* (make-hash-table))
(defvar *solutions* 0)
(defvar *unused* nil)
(defvar *elems* '())
(defvar *width* 6)
(defvar *height* 10)
(defvar *cells* '())
(defconstant +space+ "." "SPACE")

(defvar piece-def "
+-------+-------+-------+-------+-------+-------+
|       |   I   |  L    |  N    |       |       |
|   F F |   I   |  L    |  N    |  P P  | T T T |
| F F   |   I   |  L    |  N N  |  P P  |   T   |
|   F   |   I   |  L L  |    N  |  P    |   T   |
|       |   I   |       |       |       |       |
+-------+-------+-------+-------+-------+-------+
|       | V     | W     |   X   |    Y  | Z Z   |
| U   U | V     | W W   | X X X |  Y Y  |   Z   |
| U U U | V V V |   W W |   X   |    Y  |   Z Z |
|       |       |       |       |    Y  |       |
+-------+-------+-------+-------+-------+-------+")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun join-string-list (string-list sep)
  (reduce (lambda (a b) (format nil "~a~a~a" a sep b)) string-list))

(defun split-by (string sep)
  (loop for i = 0 then (1+ j)
        as j = (position sep string :start i)
        collect (subseq string i j)
        while j))

(defun to-int (string)
  (handler-case
      (parse-integer string)
    (error () 0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun piece-def (id)
  (let ((x 0) (y 0) (def '()))
    (loop for ch across piece-def
          do (progn
               (when (find id (list ch))
                 (push (list (floor x 2) y) def))
               (when (char= ch #\newline)
                 (incf y)
                 (setq x 0))
               (incf x)))
    def))


(defun fig-to-str (fig)
  (concatenate 'string "[ "
               (reduce (lambda (a b)
                         (format nil "~a (~d,~d)" a (first b) (second b)))
                       fig
                       :initial-value "")
               " ]"))

(defun new-piece (id)
  (let ((def (piece-def id))
        (figs '()))
    (dotimes (r-f 8)    ; rotate & flip
      (let ((fig '()))
        (dolist (pt def)
          (let ((pt (copy-list pt)))                          ; copy
            (dotimes (r (mod r-f 4))                          ; rotate
              (setq pt (list (- (second pt)) (first pt))))
            (when (>= r-f 4)  ; flip
              (setq pt (list (- (first pt) ) (second pt))))
            (push pt fig)))
        (setq fig (sort fig #'< :key                          ; sort
                        #'(lambda (xy) (+ (first xy) (* 100 (second xy))))))
        (let* ((ox (first  (first fig)))                      ; normalize
               (oy (second (first fig)))
               (norm-fig (mapcar (lambda (p)
                                   (list (- (first p) ox) (- (second p) oy)))
                                 fig)))
          (unless (member norm-fig figs :test #'equal)        ; uniq
            (push norm-fig figs)))))
    (setq figs (nreverse figs))
    (when *debug-flg*  ; debug print
      (format t "~a: (~d)~%" id (length figs))
      (dolist (fig figs)
        (format t "~t~a~%" (fig-to-str fig))))
    figs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun new-board (w h)
  (let* ((elems
          '("    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---"
            "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   ")))
    (setq *elems* (mapcar (lambda (row) (split-by row #\,)) elems))
    (setq *width* w *height* h)
    (setq *cells* (make-array (list h w) :initial-element +space+))
    (when (= (* w h) 64 )              ;; 8x8 or 4x16
      (let ((cx (/ w 2 ))
            (cy (/ h 2 )))
        (setf (aref *cells* (1- cy) (1- cx)) #\@)
        (setf (aref *cells*     cy  (1- cx)) #\@)
        (setf (aref *cells* (1- cy)     cx ) #\@)
        (setf (aref *cells*     cy      cx ) #\@)))))


(defun at (x y)
  (if (and (>= x 0) (< x *width*) (>= y 0) (< y *height*))
      (aref *cells* y x)
      "?"))


(defun check (x y fig)
    (dolist (pt fig t)
      (unless (string= (at (+ (first pt) x) (+ (second pt) y)) +space+)
        (return nil))))


(defun place (x y fig id)
  (dolist (pt fig)
    (setf (aref *cells* (+ (second pt) y) (+ (first pt) x)) id)))


(defun find-space (x y)
    (loop while (not (string= (aref *cells* y x) +space+))
          do (progn
               (setq x (mod (1+ x) *width*))
               (when (= x 0)
                 (incf y))))
    (list x y))


(defun render ()
  (let ((lines '())
        (cmp (lambda (x y u v n) (if (string/= (at x y) (at u v)) n 0 ))))
    (dotimes (y (1+ *height*))
      (dotimes (d 2)
        (let ((line '()))
          (dotimes (x (1+ *width*))
            (let ((code (+ (funcall cmp  x      y       x     (1- y)  1 )
                           (funcall cmp  x     (1- y)  (1- x) (1- y)  2 )
                           (funcall cmp (1- x) (1- y)  (1- x)  y      4 )
                           (funcall cmp (1- x)  y       x      y      8 ))))
              (push (nth code (nth d *elems*)) line)))
          (push (join-string-list (nreverse line) "") lines))))
    (join-string-list (nreverse lines) #\newline )))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun solve ( x y )
  (if (gethash *unused* *next*)
      (let* ((xy (find-space x y))
             (x (first xy))
             (y (second xy))
             (prev *unused*))
        (loop for pc = (gethash prev *next*) then (gethash prev *next*)
              while (not (string= pc nil))
              do (progn
                   (setf (gethash prev *next*) (gethash pc *next*))
                   (dolist (fig (gethash pc *pieces*))
                     (when (check x y fig)
                       (place x y fig pc)
                       (solve x y)
                       (place x y fig +space+)))
                   (setq prev (setf (gethash prev *next*) pc)))))
      (progn
        (setq *solutions* (1+ *solutions*))
        (let* ((lines (+ 2 (* 2 *height* )))
               #+CLISP (lines (1+ lines))
               (curs-up (if (> *solutions* 1 )
                           (format nil "~c[~dA" #\Esc lines)
                           "")))
          (format t "~a~a~d~%" curs-up (render) *solutions*)))))


 (defun command-line ()
  (or
   #+CLISP *args*
   #+SBCL *posix-argv*
   #+LISPWORKS system:*line-arguments-list*
   #+CMU extensions:*command-line-words*
   nil))

(defun main ()
  (let ((width   6 )
        (height 10 ))
    (loop for arg in (command-line) do
          (when (string= arg "--debug")
            (setq *debug-flg* t))
          (let ((sz (mapcar #'to-int (split-by arg #\x))))
            (when (= (length sz) 2)
              (let ((w (first sz))
                    (h (second sz))
                    (w-x-h (* (first sz) (second sz) )))
                (when (and (>= w 3) (>= h 3) (or (= w-x-h 60) (= w-x-h 64)))
                  (setf width (first sz)
                        height (second sz)))))))
    ;; initialize Board
    (new-board width height )
    ;; initialize Piece, Unused
    (let ((pc nil)
          (ids (reverse (coerce "FILNPTUVWXYZ" 'list))))
      (dolist (id ids)
        (setf (gethash id *pieces*) (new-piece id))
        (setf (gethash id *next*) pc)
        (setq pc id))
      (setq *unused* #\!))                        ;; head node
      (setf (gethash *unused* *next*) #\F)

    ;; limit the symmetry of 'F'
    (setf (gethash #\F *pieces*)
          (subseq (gethash #\F *pieces*) 0 (if (= width height) 1 2)))
    ;; run !!
    (solve 0 0)))

(main)
