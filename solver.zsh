#!/usr/bin/env zsh
# -*- coding:utf-8 -*-

# Pentomino Puzzle Solver with zsh
# Required: zsh 5.8+

typeset -A PIECE_DEF
typeset -A PIECES
typeset -A BOARD


# --- read piece definition ----------------------------

input=$(cat <<'EOF'
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
+-------+-------+-------+-------+-------+-------+
EOF
)

x=0  y=0
for ((i=1; i<=${#input}; i++)); do
  id=${input[i]}   # 1-character substring
  [[ "$id" =~ '[A-Z]' ]] && PIECE_DEF[$id]+="$((x/2)),$y "
  ((x++))
  [[ "$id" == $'\n' ]] && { x=0; ((y++)); }
done

WIDTH=6
HEIGHT=10
solutions=0
debug_flg=0

# -------------------------------------------------------------------
# Initialize BOARD
# -------------------------------------------------------------------
init_BOARD() {
  local x y
  for y in {1..$HEIGHT}; do
    for x in {1..$WIDTH}; do
      BOARD["$x,$y"]="."
    done
  done

  if ((WIDTH*HEIGHT==64)); then
    BOARD["$((WIDTH/2  )),$((HEIGHT/2  ))"]="@"
    BOARD["$((WIDTH/2  )),$((HEIGHT/2+1))"]="@"
    BOARD["$((WIDTH/2+1)),$((HEIGHT/2  ))"]="@"
    BOARD["$((WIDTH/2+1)),$((HEIGHT/2+1))"]="@"
  fi
}

# -------------------------------------------------------------------
# Generate orientation figs
# -------------------------------------------------------------------
generate_figs() {

  local base_str="$1"
  local -a base_pts=(${=base_str})

  local -a figs=()
  local r_f i n pair x y repr x0 y0

  for r_f in {0..7}; do
    local -a pts=("${base_pts[@]}")

    # rotation
    local rot=$(( r_f % 4 ))
    for ((i=0; i<rot; i++)); do
      for n in {1..${#pts[@]}}; do
        pair=${pts[$n]}
        x=${pair%,*}    y=${pair#*,}
        pts[$n]="$((-y)),$x"
      done
    done

    # flip
    if ((r_f >= 4)); then
      for n in {1..${#pts[@]}}; do
        pair=${pts[$n]}
        x=${pair%,*}    y=${pair#*,}
        pts[$n]="$((-x)),$y"
      done
    fi

    # sort
    read -A pts <<< \
         "$(echo "${pts[@]}" | xargs -n1 | sort -t, -k2,2n -k1,1n | xargs)"

    # normalize
    pair=${pts[1]}
    x0=${pair%,*}
    y0=${pair#*,}
    repr=""
    for n in {1..${#pts[@]}}; do
      pair=${pts[$n]}
      x=${pair%,*}     y=${pair#*,}
      repr+="$((x-x0)),$((y-y0)) "
    done

    # uniq
    [[ "${figs[*]}" != *"$repr"* ]] && figs+=("$repr")
  done

  echo "${(j:|:)figs}"
}

# -------------------------------------------------------------------
# Precompute all pieces
# -------------------------------------------------------------------
init_PIECES() {
  local id fig_str x y

  # Generate orientations
  for id in ${(k)PIECE_DEF[@]}; do
    PIECES[$id]=$(generate_figs "${PIECE_DEF[$id]}")
  done

  # slice figs to reduce symmetries
  if ((WIDTH==HEIGHT)); then
    PIECES[F]=$(echo "${PIECES[F]}" | cut -d '|' -f 1)
  else
    PIECES[F]=$(echo "${PIECES[F]}" | cut -d '|' -f 1-2)
  fi

  # Generate absolute figs
  for id in ${(k)PIECE_DEF[@]}; do
    local -a figs_arr abs_figs

    figs_arr=("${(s:|:)PIECES[$id]}")

    if ((debug_flg==1)); then
      echo "$id: (${#figs_arr})  ${PIECES[$id]}"
    fi

    for y in {1..$HEIGHT}; do
      for x in {1..$WIDTH}; do
        abs_figs=()
        for fig_str in "${figs_arr[@]}"; do
          local abs_fig=""  n=0
          for p in ${(s: :)fig_str}; do
            local dx=${p%,*}   dy=${p#*,}
            local ax=$((x+dx)) ay=$((y+dy))
            (( ax < 1 || ax > WIDTH || ay < 1 || ay > HEIGHT )) && break
            abs_fig+="$ax,$ay "
            ((n++))
          done
          ((n==5)) && abs_figs+=("$abs_fig")
        done
        PIECES["$id,$x,$y"]="${(j:|:)abs_figs}"
      done
    done
  done
}

# -------------------------------------------------------------------
check() {
  for p in ${=1}; do
    [[ ${BOARD["$p"]} == "." ]] || return 1
  done
  return 0
}

place() {
  for p in ${=1}; do
    BOARD["$p"]="$2"
  done
}

# -------------------------------------------------------------------
fs_x=0   fs_y=0
find_space() {
  fs_x=$1  fs_y=$2
  while true; do
    [[ ${BOARD["$fs_x,$fs_y"]} == "." ]] && break
    ((fs_x++))
    ((fs_x > WIDTH))  && { fs_x=1; ((fs_y++)); }
    ((fs_y > HEIGHT)) && { fs_x=0; fs_y=0; break; }
  done
}

# -------------------------------------------------------------------
# Rendering setup
ELEMS_STR=(
  "    ,/,/,+---,/,----,+   ,+---,/,+---,|   ,+---,+   ,+---,+   ,+---,+---"
  "    ,/,/,    ,/,    ,    ,    ,/,|   ,|   ,|   ,|   ,|   ,|   ,|   ,|   "
)
ELEMS1=("${(s:,:)ELEMS_STR[1]}")
ELEMS2=("${(s:,:)ELEMS_STR[2]}")

render() {
  local x y
  for y in {1..$((HEIGHT+1))}; do
    local line1="" line2=""
    for x in {1..$((WIDTH+1))}; do
      local c00=${BOARD["$((x-0)),$((y-0))"]:-@}
      local c01=${BOARD["$((x-0)),$((y-1))"]:-@}
      local c11=${BOARD["$((x-1)),$((y-1))"]:-@}
      local c10=${BOARD["$((x-1)),$((y-0))"]:-@}

      local code=1
      [[ "$c00" != "$c01" ]] && ((code+=1))
      [[ "$c01" != "$c11" ]] && ((code+=2))
      [[ "$c11" != "$c10" ]] && ((code+=4))
      [[ "$c10" != "$c00" ]] && ((code+=8))

      line1+="${ELEMS1[$code]}"
      line2+="${ELEMS2[$code]}"
    done
    echo "$line1"
    echo "$line2"
  done
}

# -------------------------------------------------------------------
solve() {
  local x=$1 y=$2
  shift 2
  local -a pieces=("$@")

  if ((#pieces==0)); then
    ((solutions++))
    ((solutions>1)) && echo -n "\033[$((HEIGHT*2+3))A"
    render
    echo "$solutions"
    return
  fi

  find_space $x $y
  x=$fs_x
  y=$fs_y
  ((x<1)) && return

  local i id fig
  local -a rest
  for i in {1..${#pieces}}; do
    id="${pieces[$i]}"
    rest=( $pieces[1,$((i-1))] $pieces[$((i+1)),-1] )

    local -a figs=("${(s:|:)PIECES["$id,$x,$y"]}")
    for fig in "${figs[@]}"; do
      [[ "$fig" == "" ]] && continue
      if check "$fig"; then
        place "$fig" "$id"
        solve $x $y "${rest[@]}"
        place "$fig" "."
      fi
    done
  done
}

# -------------------------------------------------------------------
# main args
while (( $# > 0 )); do
  case $1 in
    -d|--debug)
      debug_flg=1;;
    *)
      if [[ "$1" =~ '^[0-9]+x[0-9]+$' ]]; then
        WIDTH=${1%x*}
        HEIGHT=${1#*x}
      fi;;
  esac
  shift
done

init_BOARD
init_PIECES
solve 1 1  F I L N P T U V W X Y Z
