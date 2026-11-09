;;-*- coding:utf-8 -*-

;;
;; Pentomino Puzzle Solver with Clojure
;;
(ns solver
  (:require [clojure.string :as str]))

(def pieces-doc
  ["+-------+-------+-------+-------+-------+-------+"
   "|       |   I   |  L    |  N    |       |       |"
   "|   F F |   I   |  L    |  N    |  P P  | T T T |"
   "| F F   |   I   |  L    |  N N  |  P P  |   T   |"
   "|   F   |   I   |  L L  |    N  |  P    |   T   |"
   "|       |   I   |       |       |       |       |"
   "+-------+-------+-------+-------+-------+-------+"
   "|       | V     | W     |   X   |    Y  | Z Z   |"
   "| U   U | V     | W W   | X X X |  Y Y  |   Z   |"
   "| U U U | V V V |   W W |   X   |    Y  |   Z Z |"
   "|       |       |       |       |    Y  |       |"
   "+-------+-------+-------+-------+-------+-------+" ])

;;
;; Pieces
;;
(def pieces-def
  (let [cells (for [[y line] (map-indexed vector pieces-doc)
                    [x c] (map-indexed vector line)
                    :when (<= (int \A) (int c) (int \Z))]
                {:id (str c) :coord [(quot x 2) y]})]
    (->> (group-by :id cells)
         (reduce-kv (fn [m id cell-maps]
                      (assoc m id (mapv :coord cell-maps))) {}))))


(defn generate-figs [org-fig]
  (distinct                          ; uniq
   (for [f [1 -1]
         r (range 4)]
     (let [fig
           (->> org-fig
                                     ; rotate
                (map (fn [pt] (nth (iterate (fn [[x y]] [(- y) x]) pt) r )))
                (map (fn [[x y]] [(* x f) y]))               ; flip
                (sort-by (juxt second first)))               ; sort
           ox (first  (first fig) )
           oy (second (first fig) )
           ]
       (map (fn [[x y]] [(- x ox) (- y oy)]) fig )))))       ; normalize


;;
;; Board
;;
(defn create-board [w h]
  (let [board (vec (repeat h (vec (repeat w nil))))]
    (if (= (* w h) 64)  ;; 8x8 or 4x16
      (let [cx (dec (quot w 2)) cy (dec (quot h 2))]
        (-> board
            (assoc-in [     cy  cx] "@") (assoc-in [     cy  (inc cx)] "@")
            (assoc-in [(inc cy) cx] "@") (assoc-in [(inc cy) (inc cx)] "@")))
      board)))


(defn find-space [board w h]
  (first (for [y (range h) x (range w) :when (nil? (get-in board [y x]))] [x y])))


(defn can-place? [board w h fig ox oy]
  (every? (fn [[fx fy]]
            (let [nx (+ ox fx) ny (+ oy fy)]
              (and (< -1 nx w) (< -1 ny h) (nil? (get-in board [ny nx])))))
          fig))


(defn place [board fig ox oy id]
  (reduce (fn [b [fx fy]] (assoc-in b [(+ oy fy) (+ ox fx)] id)) board fig))

;;         2
;; (-1,-1) | (0,-1)
;;   ---4--+--1----
;; (-1, 0) | (0, 0)
;;         8
(def elems
  (mapv #(str/split % #",")
        ;; 0      3     5    6    7     9    10   11   12   13   14   15
        ["    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---"
         "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "]))

(defn render [board w h]
  (let [ at (fn [x y] (if (and (>= x 0) (< x w) (>= y 0) (< y h))
                        (get-in board [y x])
                        :out))]
    (->> (for [y (range (inc h))]
           (let [ codes (for [x (range (inc w))]
                          (let [ids (mapv (fn [[u v]] (at (- x u) (- y v)))
                                          [[0 0] [0 1] [1 1] [1 0]])]
                            (+ (if (= (ids 0) (ids 1)) 0 1 )
                               (if (= (ids 1) (ids 2)) 0 2 )
                               (if (= (ids 2) (ids 3)) 0 4 )
                               (if (= (ids 3) (ids 0)) 0 8 ))))]
             (map (fn [elem] (apply str (map #(nth elem %) codes))) elems)))
         flatten
         (str/join "\n"))))

;;
;; Solver
;;
(def solutions (atom 0))

(defn solve [board w h piece-figs unused]
  (if (empty? unused)
    (let [sol-count (swap! solutions inc)
          up-lines (+ (*  h 2) 2)
          cursor-up (if (> sol-count 1) (format "\033[%dA" up-lines) "")]
      (print (format "%s%s%d\n" cursor-up (render board w h) sol-count))
      (flush))
    (if-let [[sx sy] (find-space board w h)]
      (doseq [id unused
              fig (get piece-figs id)]
        (when (can-place? board w h fig sx sy)
          (solve (place board fig sx sy id) w h piece-figs (disj unused id)))))))


(defn -main [& args]
  (let [debug? (some #{"--debug"} args)
        ;; WxH
        size-arg (some #(re-find #"(\d+)x(\d+)" %) args)
        [w h] (if size-arg
                (let [sw (read-string (nth size-arg 1))
                      sh (read-string (nth size-arg 2))]
                  (if (contains? #{60 64} (* sw sh)) [sw sh] [6 10]))
                [6 10])
        ;; generate Figs
        all-figs (into {} (for [[id fig] pieces-def] [id (generate-figs fig)]))
        ;; limit symetries of 'F'
        limit (if (= w h) 1 2)
        piece-figs (update all-figs "F" #(take limit %))
        board (create-board w h)]

    (when debug?
      (doseq [[id figs] all-figs]
        (println (format "%s: (%d)" id (count figs)))
        (doseq [f figs] (println "   " f))))

    (solve board w h piece-figs (set (keys pieces-def)))))

(apply -main *command-line-args*)
