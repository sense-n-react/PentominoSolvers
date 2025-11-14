#!/usr/bin/env bash
# Pentomino Puzzle Solver with Bash
# Verified on bash 5.2+

PIECE_DOC=$(cat <<EOF
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

WIDTH=6
HEIGHT=10
solutions=0
debug_flg=0
declare -A PIECES  BOARD

# === Board initialization ===
init_BOARD() {
  for ((y=0; y<HEIGHT; y++)); do
    for ((x=0; x<WIDTH; x++)); do
      BOARD["$x,$y"]="."
    done
  done
  if ((WIDTH==8 && HEIGHT==8)); then
     BOARD["3,3"]="@"
     BOARD["3,4"]="@"
     BOARD["4,3"]="@"
     BOARD["4,4"]="@"
  fi
}

# generate figs for each orientation
generate_figs() {
  local base_str=$1
  local -a figs=()
  read -r -a base_pts <<< "$base_str"

  for r_f in {0..7}; do
    local -a pts=("${base_pts[@]}")   # 2,2 2,3 3,1 3,2 4,2

    for ((i=0; i<r_f % 4; i++)); do     # rotation
      for n in "${!pts[@]}"; do
        local pair="${pts[$n]}"
        local x=${pair%,*}    y=${pair#*,}
        pts[$n]="$((-y)),$x"
      done
    done

    if ((r_f >= 4)); then               # flip
      for n in "${!pts[@]}"; do
        local pair="${pts[$n]}"
        local x=${pair%,*}    y=${pair#*,}
        pts[$n]="$((-x)),$y"
      done
    fi

    # sort                 -> 3,1 2,2 3,2 4,2 2,3
    IFS=$'\n' read -r -d '' -a pts < <(
      for q in "${pts[@]}"; do echo "$q"; done | sort -t, -k2,2n -k1,1n
    )

    # normalize            -> 0,0 -1,1 0,1 1,1 -1,2
    repr=""
    local x0="${pts[0]%,*}" y0="${pts[0]#*,}"
    for i in "${!pts[@]}"; do
      x=("${pts[$i]%,*}")
      y=("${pts[$i]#*,}")
      repr+="$((x - x0)),$((y - y0)) "
    done

    # uniq
    [[ ! "${figs[*]}" == *"$repr"* ]]  && figs+=("$repr")
  done
  (IFS='|'; echo "${figs[*]}")
}

# === Precompute pieces ===
init_PIECES() {
  local -A BASE_PIECES
  # Base piece
  while read -r line; do
    # 各文字を走査
    for ((i=0; i<${#line}; i++)); do
      c="${line:$i:1}"
      # アルファベットならその座標を登録
      if [[ $c =~ [A-Z] ]]; then
        BASE_PIECES["$c"]+="$((i/2)),$y "
      fi
    done
    ((y++))
  done <<< "$PIECE_DOC"

  # generate figs of each orientation
  # PIECES[id]
  #
  for id in "${!BASE_PIECES[@]}"; do
    PIECES["$id"]=$(generate_figs "${BASE_PIECES[$id]}")
  done

  # slice figs to reduce symmetries
  PIECES[F]=$(echo "${PIECES[F]}" | cut -d '|' -f 1-2)
  ((WIDTH == 8)) && PIECES[I]=$(echo "${PIECES[I]}" | cut -d '|' -f 1)

  # genrate absolute figs for each (x,y) cord.
  # PIECES[id,x,y]
  #
  for id in "${!BASE_PIECES[@]}"; do
    IFS='|' read -r -a figs <<< "${PIECES["$id"]}"
    if (( ${debug_flg}==1 )); then
      echo "$id: (${#figs[@]})  $(IFS='|'; echo "${figs[*]}")"
    fi
    for ((ay=0; ay<HEIGHT; ay++)); do
      for ((ax=0; ax<WIDTH; ax++)); do
        abs_figs=()
        for fig in "${figs[@]}"; do
          abs_fig=""
          placeable=0
          for p in $fig; do
            dx=${p%,*} dy=${p#*,}
            x=$((ax+dx)) y=$((ay+dy))
            ((x<0||x>=WIDTH||y<0||y>=HEIGHT)) && { placeable=1; break; }
            abs_fig+="$x,$y "
          done
          ((placeable==0)) && { abs_figs+=("$abs_fig"); abs_fig=""; }
        done # fig
        PIECES["$id,$ax,$ay"]=$(IFS='|'; echo "${abs_figs[*]}")
      done  # x
    done  # y
  done # id
}

# === Placement and search ===
check() {
  for p in $1; do
    [[ ${BOARD["$p"]} == "." ]] || return 1
  done
  return 0
}

place() {
  for p in $1; do
    BOARD["$p"]="$2"
  done
}

fs_x=0  fs_y=0  # use global vars for return value
find_space() {
  fs_x=$1 fs_y=$2
  while true; do
    [[ ${BOARD["$fs_x,$fs_y"]} == "." ]] && break
    ((fs_x+=1))
    [[ $fs_x == $WIDTH  ]] && { fs_x=0;  ((fs_y+=1)); }
    [[ $fs_y == $HEIGHT ]] && { fs_x=-1; fs_y=-1; break; }
  done
}

elems_str=("    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---"
           "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   " )
IFS=',' read -a elems0 <<< "${elems_str[0]}"
IFS=',' read -a elems1 <<< "${elems_str[1]}"

render() {
  local x y
  for ((y=0; y<=$HEIGHT; y++)); do
    local line1="" line2=""
    for ((x=0; x<=$WIDTH; x++)); do
      local c00=${BOARD["$x,$y"]:-a}
      local c01=${BOARD["$x,$((y-1))"]:-a}
      local c11=${BOARD["$((x-1)),$((y-1))"]:-a}
      local c10=${BOARD["$((x-1)),$y"]:-a}
      local code=0
      [[ "$c00" != "$c01" ]] && ((code+=1))
      [[ "$c01" != "$c11" ]] && ((code+=2))
      [[ "$c11" != "$c10" ]] && ((code+=4))
      [[ "$c10" != "$c00" ]] && ((code+=8))
      line1+=${elems0[$code]}
      line2+=${elems1[$code]}
    done
    echo "$line1"
    echo "$line2"
  done
}

solve() {
  local x=$1  y=$2 pieces=("${@:3}")
  local i fig

  if ((${#pieces[@]}==0)); then
    ((solutions+=1))
    ((solutions > 1)) && echo -en "\033[$((HEIGHT*2+3))A"
    render
    echo "$solutions"
    return
  fi

  find_space $x $y
  x=$fs_x
  y=$fs_y
  ((x<0)) && return

  for ((i=0; i<${#pieces[@]}; i++)); do
    local id=${pieces[$i]}
    local rest=("${pieces[@]:0:$i}" "${pieces[@]:$((i+1))}")
    local -a figs figs_tmp
    IFS='|' read -r -a figs <<< "${PIECES["$id,$x,$y"]}"

    for fig in "${figs[@]}"; do
      if check "$fig"; then
        place "$fig" $id             # place
        solve $x $y "${rest[@]}"     # call recursively
        place "$fig" .               # unplace
      fi
    done
  done
}

# === main ===
while [ $# -gt 0 ]; do
  case $1 in
    -d | --debug)
      debug_flg=1
      ;;
    *)
      size="$1"
      if [[ "$size" =~ [0-9]+x[0-9]+ ]]; then
        w=${1%x*}  h=${1#*x}
        WIDTH=$w   HEIGHT=h
      fi
      ;;
  esac
  shift
done

init_BOARD
init_PIECES
solve 0 0   F I L N P T U V W X Y Z
